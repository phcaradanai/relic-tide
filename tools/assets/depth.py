"""Native grayscale depth assets and a separate DepthFlow preview boundary."""
from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlparse

from common import (ROOT, PipelineError, executable, output_bundle, read_image, reference,
                    resource_path, run_local, secret, sha256, validate_name, work_root, write_json)


# Authenticated /apis/api-keys Integration Quick Start, read 2026-10-06.
# The same-origin upload route answered 405/Allow: POST and rejected a keyless
# empty POST with 401. The separate /apis/documentation .ai route fails DNS.
# Keep this fixed to the verified provider origin; never accept an arbitrary
# env-supplied endpoint that could receive the user's secret.
VERIFIED_DEPTHFLOW_API_ENDPOINT = 'https://www.depthflow.io/api/ai/depthflow/generate-3d'
# User resumed DepthFlow on 2026-10-07 after funding watermark-free access.
# Keep a fixed verified origin; disabling it still stops before keys/network.
DEPTHFLOW_API_ENDPOINT: str | None = VERIFIED_DEPTHFLOW_API_ENDPOINT


def checkout() -> Path:
    return Path(os.environ.get('DEPTH_ANYTHING_DIR', '/Users/Projects/Depth-Anything-V2')).expanduser().resolve()


def depth_python() -> str:
    folder = checkout()
    return executable('DEPTH_ANYTHING_PYTHON', [folder / 'venv/bin/python',
        folder / '.venv/bin/python', folder / 'venv/Scripts/python.exe', folder / '.venv/Scripts/python.exe'])


def depth_bundle(name: str, source: Path, depth_path: Path, provenance: dict, root: Path = ROOT) -> Path:
    from PIL import Image, ImageChops
    art = read_image(source)
    depth = read_image(depth_path)
    if art.size != depth.size:
        raise PipelineError('Depth and source art must have identical dimensions; do not stretch depth to fit.')
    r, g, b, a = depth.split()
    if ImageChops.difference(r, g).getbbox() or ImageChops.difference(r, b).getbbox():
        raise PipelineError('Depth must be grayscale, not a color visualization or side-by-side comparison.')
    if a.getextrema() != (255, 255):
        raise PipelineError('Depth maps must be opaque grayscale.')
    if r.getextrema()[0] == r.getextrema()[1]:
        raise PipelineError('Depth map is flat; it would not prove depth motion.')
    with output_bundle('depth', name, root) as (stage, target):
        art.save(stage / 'image.png')
        r.save(stage / 'depth.png')
        (stage / 'art.tres').write_text(
            '[gd_resource type="Resource" script_class="DepthArt" load_steps=4 format=3]\n\n'
            '[ext_resource type="Script" path="res://scripts/assets/depth_art.gd" id="1"]\n'
            f'[ext_resource type="Texture2D" path="{resource_path(target / "image.png", root)}" id="2"]\n'
            f'[ext_resource type="Texture2D" path="{resource_path(target / "depth.png", root)}" id="3"]\n\n'
            '[resource]\nscript = ExtResource("1")\nimage = ExtResource("2")\n'
            'depth = ExtResource("3")\nnear_is_white = true\n')
        write_json(stage / 'manifest.json', {'schema': 1, 'kind': 'depth', 'name': name,
            'size': list(art.size), 'encoding': 'normalized-relative-inverse-depth-u8',
            'near_is_white': True, 'source': reference(source, root), 'source_sha256': sha256(source),
            'depth_sha256': sha256(stage / 'depth.png'), 'provenance': provenance})
    return target


def generate(args) -> Path:
    folder = checkout()
    checkpoint = Path(os.environ.get('DEPTH_ANYTHING_CHECKPOINT',
        str(folder / 'checkpoints/depth_anything_v2_vits.pth'))).expanduser().resolve()
    if not (folder / 'depth_anything_v2/dpt.py').is_file() or not checkpoint.is_file():
        raise PipelineError('Check DEPTH_ANYTHING_DIR and the vits checkpoint path; no model is downloaded automatically.')
    if args.input_size < 28:
        raise PipelineError('Depth input size must be at least 28.')
    source = Path(args.source).resolve()
    read_image(source)  # Fail before starting the expensive model.
    if (ROOT / 'assets/generated/depth' / validate_name(args.name)).exists():
        raise PipelineError('Depth asset name exists; choose a new versioned name.')
    with tempfile.TemporaryDirectory(dir=work_root()) as directory:
        target = Path(directory) / 'depth.png'
        run_local([depth_python(), str(Path(__file__).with_name('depth_worker.py')),
            '--checkout', str(folder), '--checkpoint', str(checkpoint), '--source', str(source),
            '--output', str(target), '--input-size', str(args.input_size), '--device', args.device])
        return depth_bundle(args.name, source, target, {'provider': 'depth-anything-v2-local',
            'encoder': 'vits', 'input_size': args.input_size, 'device_requested': args.device,
            'checkpoint_sha256': sha256(checkpoint)})


def import_depth(args) -> Path:
    from PIL import ImageOps
    source, depth_path = Path(args.source), Path(args.depth_map)
    if not args.near_is_dark:
        return depth_bundle(args.name, source, depth_path, {'provider': 'local-depth-import'})
    with tempfile.TemporaryDirectory(dir=work_root()) as directory:
        converted = Path(directory) / 'depth.png'
        original = read_image(depth_path)
        # Validate channels before conversion rather than silently accepting color depth.
        from PIL import ImageChops
        r, g, b, alpha = original.split()
        if alpha.getextrema() != (255, 255):
            raise PipelineError('Depth maps must be opaque grayscale.')
        if ImageChops.difference(r, g).getbbox() or ImageChops.difference(r, b).getbbox():
            raise PipelineError('Imported depth must be grayscale.')
        ImageOps.invert(original.convert('RGB')).save(converted)
        return depth_bundle(args.name, source, converted, {'provider': 'local-depth-import', 'inverted': True})


def asset_pair(name: str) -> tuple[Path, Path]:
    folder = ROOT / 'assets/generated/depth' / validate_name(name)
    image, depth = folder / 'image.png', folder / 'depth.png'
    if not image.is_file() or not depth.is_file():
        raise PipelineError('Generate or import this depth asset first.')
    return image, depth


def prepare(args) -> Path:
    image, depth = asset_pair(args.name)
    folder = work_root() / 'depthflow' / args.name
    folder.mkdir(parents=True, exist_ok=True)
    shutil.copy2(image, folder / 'image.png')
    shutil.copy2(depth, folder / 'depth.png')
    write_json(folder / 'inputs.json', {'image': 'image.png', 'depth': 'depth.png', 'near_is_white': True,
                                     'source_manifest': reference(image.parent / 'manifest.json')})
    return folder


def local_preview(args) -> Path | None:
    if not 0 <= args.amplitude <= 0.05:
        raise PipelineError('Use a gentle local preview amplitude between 0 and 0.05.')
    image, depth = asset_pair(args.name)
    interpreter = executable('DEPTHFLOW_PYTHON', [ROOT / '.venv-depthflow/bin/python',
        ROOT / '.venv-depthflow/Scripts/python.exe'])
    output = None
    if args.render:
        output = work_root() / 'previews' / (args.name + '.mp4')
        output.parent.mkdir(parents=True, exist_ok=True)
        if output.exists():
            raise PipelineError('Preview already exists; move it before rendering again.')
    command = [interpreter, str(Path(__file__).with_name('depthflow_worker.py')),
        '--image', str(image), '--depth', str(depth), '--seconds', str(args.seconds),
        '--fps', str(args.fps), '--amplitude', str(args.amplitude)]
    if output:
        command += ['--output', str(output)]
    run_local(command, timeout=600 if output else 86400)
    return output


def cloud_receipt(name: str) -> Path:
    return work_root() / 'depthflow' / (validate_name(name) + '.json')


def save_video(content: bytes, name: str) -> Path:
    if len(content) < 12 or content[4:8] != b'ftyp':
        raise PipelineError('Response is not an MP4 container; inspect the private response contract.')
    output = work_root() / 'previews' / (validate_name(name) + '.mp4')
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise PipelineError('Preview exists; choose a new versioned name.')
    temporary = output.with_suffix('.mp4.tmp')
    temporary.write_bytes(content)
    temporary.replace(output)
    return output


def redact(value, key: str):
    if isinstance(value, dict):
        return {k: redact(v, key) for k, v in value.items()}
    if isinstance(value, list):
        return [redact(v, key) for v in value]
    if isinstance(value, str):
        return value.replace(key, '[REDACTED]')
    return value


def cloud_submit(args) -> Path:
    """One upload to the dashboard-documented route; no automatic paid retry."""
    endpoint = DEPTHFLOW_API_ENDPOINT
    if endpoint is None:
        raise PipelineError('DepthFlow cloud is disabled by project choice. Use local Depth-Anything assets; re-enable only after a new decision to use this provider.')
    import requests
    source = Path(args.source).resolve()
    image = read_image(source)
    payload = json.loads(Path(args.payload_file).read_text())
    if not isinstance(payload, dict):
        raise PipelineError('DepthFlow payload must be a JSON object.')
    key = secret('DEPTHFLOW_API_KEY')
    receipt = cloud_receipt(args.name)
    if receipt.exists() or (work_root() / 'previews' / (args.name + '.mp4')).exists():
        raise PipelineError('DepthFlow name already submitted. Inspect its receipt; do not submit again.')
    # The endpoint must come from verified provider documentation, never a guessed origin.
    submission = {'state': 'submitting', 'endpoint': endpoint,
                  'source': reference(source), 'source_sha256': sha256(source), 'payload': payload}
    write_json(receipt, submission)
    import io
    encoded = io.BytesIO()
    image.save(encoded, format='PNG')
    try:
        response = requests.post(endpoint, headers={'X-API-Key': key, 'Accept': 'application/json'},
            files={'file': ('source.png', encoded.getvalue(), 'image/png')},
            data={'payload': json.dumps(payload)}, timeout=(15, 300), allow_redirects=False)
    except requests.RequestException as exc:
        raise PipelineError('DepthFlow connection failed. Check the dashboard before retrying; submission may have succeeded.') from exc
    if response.status_code not in (200, 201, 202):
        raise PipelineError(f'DepthFlow HTTP {response.status_code}; inspect account/API docs. Response body is suppressed.')
    if response.headers.get('Content-Type', '').split(';')[0] in ('video/mp4', 'application/octet-stream'):
        output = save_video(response.content, args.name)
        write_json(receipt, {**submission, 'state': 'downloaded', 'file': reference(output)})
        return output
    try:
        value = response.json()
    except ValueError as exc:
        raise PipelineError('DepthFlow returned neither an MP4 nor JSON; check the provider contract.') from exc
    write_json(receipt, {**submission, 'state': 'response-saved', 'response': redact(value, key)})
    # A result URL field is selected explicitly by the caller after inspecting real JSON.
    if args.url_field:
        return cloud_collect(args)
    return receipt


def cloud_collect(args) -> Path:
    import requests
    receipt = cloud_receipt(args.name)
    if not receipt.exists():
        raise PipelineError('No private DepthFlow receipt for this name.')
    data = json.loads(receipt.read_text())
    value = data.get('response')
    try:
        for field in args.url_field.split('.'):
            value = value[int(field)] if isinstance(value, list) else value[field]
    except (KeyError, TypeError, ValueError, IndexError) as exc:
        raise PipelineError('URL field is missing; inspect the private receipt and use its actual JSON field path.') from exc
    if not isinstance(value, str):
        raise PipelineError('The chosen result field must contain a URL string.')
    parsed = urlparse(value)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
        raise PipelineError('Result URL must be HTTPS without embedded user credentials.')
    try:
        # Provider API key is never forwarded to signed result/CDN URLs.
        response = requests.get(value, timeout=(15, 300), allow_redirects=False)
    except requests.RequestException as exc:
        raise PipelineError('DepthFlow video download failed; result URL may have expired.') from exc
    if response.status_code != 200:
        raise PipelineError(f'DepthFlow video download HTTP {response.status_code}; no redirects followed.')
    output = save_video(response.content, args.name)
    data['state'] = 'downloaded'
    write_json(receipt, data)
    return output
