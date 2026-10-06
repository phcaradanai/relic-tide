"""Shared config and output ownership for offline asset production."""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class PipelineError(Exception):
    """An actionable error safe to display without response bodies or secrets."""


def load_env(root: Path = ROOT) -> None:
    """Read data, never execute a shell file; existing process variables win."""
    env = root / '.env.assets'
    if not env.exists():
        return
    for number, raw in enumerate(env.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        key, separator, value = line.partition('=')
        if not separator or not re.fullmatch(r'[A-Z][A-Z0-9_]*', key):
            raise PipelineError(f'Invalid .env.assets line {number}; use NAME=value.')
        value = value.strip()
        if value.startswith(('"', "'")):
            if len(value) < 2 or value[-1] != value[0]:
                raise PipelineError(f'Unclosed quote in .env.assets line {number}.')
            value = value[1:-1]
        # No interpolation, inline comments or execution, including $() and backticks.
        os.environ.setdefault(key, value)


def secret(name: str) -> str:
    value = os.environ.get(name, '').strip()
    if not value or value.lower().startswith(('your_', 'replace_', '<', 'paste_')):
        raise PipelineError(f'Set {name} privately in .env.assets or the process environment.')
    return value


def validate_name(value: str) -> str:
    if not re.fullmatch(r'[a-z][a-z0-9_-]{0,63}', value):
        raise PipelineError('Asset name must start with a-z and contain only a-z, 0-9, _ or - (max 64).')
    return value


def work_root(root: Path = ROOT) -> Path:
    work = root / '.asset-work'
    if work.is_symlink():
        raise PipelineError('Work directory must not be a symlink.')
    work.mkdir(exist_ok=True)
    (work / '.gdignore').touch()
    return work


def read_image(path: Path):
    from PIL import Image
    try:
        with Image.open(path) as source:
            source.load()
            return source.convert('RGBA')
    except (OSError, ValueError) as exc:
        raise PipelineError(f'Cannot read image: {path.name}') from exc


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def reference(path: Path, root: Path = ROOT) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.name  # Manifests do not publish machine-specific external paths.


def resource_path(path: Path, root: Path = ROOT) -> str:
    try:
        return 'res://' + path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError as exc:
        raise PipelineError('Runtime resources must be inside this project.') from exc


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


@contextmanager
def output_bundle(kind: str, name: str, root: Path = ROOT):
    """Publish only complete bundles. Existing assets are never overwritten."""
    validate_name(name)
    parent = root / 'assets' / 'generated' / kind
    if not parent.resolve().is_relative_to(root.resolve()):
        raise PipelineError('Generated output directory escapes the project.')
    parent.mkdir(parents=True, exist_ok=True)
    target = parent / name
    if target.exists() or target.is_symlink():
        raise PipelineError(f'Asset {name} already exists; choose a new versioned name.')
    # Block output escape through an existing symlink in the directory tree.
    if not parent.resolve().is_relative_to(root.resolve()):
        raise PipelineError('Generated output directory escapes the project.')
    stage = Path(tempfile.mkdtemp(prefix=f'{name}-', dir=work_root(root)))
    try:
        yield stage, target
        stage.rename(target)
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def executable(variable: str, candidates: list[Path | str]) -> str:
    configured = os.environ.get(variable)
    options = [configured] if configured else candidates
    for option in options:
        found = shutil.which(str(option))
        if found:
            return found
        path = Path(str(option)).expanduser()
        if path.is_file():
            return str(path.resolve())
    raise PipelineError(f'Set {variable} to the installed executable path in .env.assets.')


def godot_bin() -> str:
    home = Path.home()
    return executable('GODOT_BIN', ['godot', 'godot4', '/Applications/Godot.app/Contents/MacOS/Godot',
        home / 'Downloads/Godot.app/Contents/MacOS/Godot'])


def aseprite_bin() -> str:
    return executable('ASEPRITE_BIN', ['aseprite', '/Applications/Aseprite.app/Contents/MacOS/aseprite',
        Path.home() / 'Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite'])


def run_local(command: list[str], *, cwd: Path = ROOT, timeout: int = 600, godot_check: bool = False) -> None:
    # Keys are build-time inputs for HTTP only. Never pass them to third-party tools.
    environment = {k: v for k, v in os.environ.items() if not k.endswith(('API_KEY', 'TOKEN', 'SECRET'))}
    try:
        result = subprocess.run(command, cwd=cwd, env=environment, timeout=timeout, check=False, capture_output=godot_check, text=godot_check)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise PipelineError('Local tool could not finish; check its installation and timeout.') from exc
    if godot_check:
        print(result.stdout, end="")
        print(result.stderr, end="")
        if any(marker in result.stdout + result.stderr for marker in ("SCRIPT ERROR", "Parse Error", "ERROR:")):
            raise PipelineError("Godot reported import/script errors; inspect the diagnostics above.")
    if result.returncode:
        raise PipelineError(f'Local tool exited with code {result.returncode}.')
