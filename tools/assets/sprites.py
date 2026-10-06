"""Aligned raster frames -> a padded atlas and a native Godot SpriteFrames resource."""
from __future__ import annotations

import io
import json
import tempfile
from pathlib import Path

from common import (ROOT, PipelineError, aseprite_bin, output_bundle, read_image,
                    reference, resource_path, run_local, sha256, validate_name, work_root, write_json)


def sprite_bundle(name: str, frames: list, *, animation: str = 'idle', fps: float = 10,
                  filtering: str = 'nearest', provenance: dict | None = None,
                  animations: list[dict] | None = None, root: Path = ROOT) -> Path:
    from PIL import Image
    validate_name(animation)
    if not frames or fps <= 0:
        raise PipelineError('Supply at least one frame and a positive frame rate.')
    size = frames[0].size
    if any(frame.size != size for frame in frames):
        raise PipelineError('All frames must have the same canvas size; align them in Aseprite first.')
    if any(frame.getchannel('A').getextrema()[0] == 255 for frame in frames):
        raise PipelineError('Sprite frames must have transparency; remove backgrounds in Aseprite first.')
    animations = animations or [{'name': animation, 'fps': fps, 'loop': True,
                                'frames': [(i, 1.0) for i in range(len(frames))]}]
    with output_bundle('sprites', name, root) as (stage, target):
        # One transparent pixel between cells; no crop/resize/recolor or guessed foot anchor.
        sheet = Image.new('RGBA', ((size[0] + 2) * len(frames), size[1] + 2))
        for index, frame in enumerate(frames):
            sheet.paste(frame, ((size[0] + 2) * index + 1, 1))
        sheet.save(stage / 'atlas.png')
        texture_path = resource_path(target / 'atlas.png', root)
        lines = [f'[gd_resource type="SpriteFrames" load_steps={len(frames)+2} format=3]', '',
                 f'[ext_resource type="Texture2D" path="{texture_path}" id="1"]', '']
        for index in range(len(frames)):
            lines += [f'[sub_resource type="AtlasTexture" id="Frame_{index}"]',
                      'atlas = ExtResource("1")',
                      f'region = Rect2({(size[0]+2)*index+1}, 1, {size[0]}, {size[1]})', '']
        entries = []
        for item in animations:
            validate_name(item['name'])
            values = ', '.join('{"duration": %s, "texture": SubResource("Frame_%s")}' %
                               (duration, index) for index, duration in item['frames'])
            entries.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}' %
                           (values, str(item['loop']).lower(), item['name'], item['fps']))
        lines += ['[resource]', 'animations = [' + ',\n'.join(entries) + ']', '']
        (stage / 'frames.tres').write_text('\n'.join(lines))
        # A ready-to-instance node chooses filtering explicitly without affecting existing sprites.
        node_filter = 1 if filtering == 'nearest' else 2
        (stage / 'sprite.tscn').write_text(
            '[gd_scene load_steps=2 format=3]\n\n'
            f'[ext_resource type="SpriteFrames" path="{resource_path(target / "frames.tres", root)}" id="1"]\n\n'
            f'[node name="{name}" type="AnimatedSprite2D"]\n'
            f'texture_filter = {node_filter}\nsprite_frames = ExtResource("1")\n'
            f'animation = &"{animations[0]["name"]}"\n')
        write_json(stage / 'manifest.json', {'schema': 1, 'kind': 'sprite', 'name': name,
            'canvas': list(size), 'frame_count': len(frames), 'filter': filtering,
            'anchor': 'center; set AnimatedSprite2D.offset for authored feet position',
            'animations': animations, 'provenance': provenance or {}})
    return target


def import_frames(args) -> Path:
    paths = sorted(Path(args.source).glob('*.png'))
    if not paths:
        raise PipelineError('Source directory contains no PNG frames (use zero-padded filenames).')
    return sprite_bundle(args.name, [read_image(path) for path in paths], animation=args.animation,
                         fps=args.fps, filtering=args.filter,
                         provenance={'provider': 'local-import', 'sources': [
                             {'file': reference(path), 'sha256': sha256(path)} for path in paths]})


def aseprite_animations(metadata: dict) -> list[dict]:
    frames = metadata['frames']
    if not isinstance(frames, list) or not frames:
        raise PipelineError('Aseprite must export json-array with at least one frame.')
    tags = metadata.get('meta', {}).get('frameTags') or [
        {'name': 'idle', 'from': 0, 'to': len(frames)-1, 'direction': 'forward'}]
    result = []
    for tag in tags:
        start, end = tag['from'], tag['to']
        if start < 0 or end >= len(frames) or end < start:
            raise PipelineError('Invalid Aseprite tag frame range.')
        indices = list(range(start, end+1))
        direction = tag.get('direction', 'forward')
        if direction in ('reverse', 'pingpong_reverse'):
            indices.reverse()
        if direction in ('pingpong', 'pingpong_reverse'):
            indices += indices[-2:0:-1]
        if direction not in ('forward', 'reverse', 'pingpong', 'pingpong_reverse'):
            raise PipelineError('Unknown Aseprite tag direction.')
        durations = [(i, float(frames[i]['duration'])) for i in indices]
        if any(duration <= 0 for _, duration in durations):
            raise PipelineError('Aseprite frame durations must be positive.')
        # Godot durations are relative to speed; 1000fps preserves milliseconds exactly.
        result.append({'name': tag['name'], 'fps': 1000, 'loop': True, 'frames': durations})
    return result


def aseprite_import(args) -> Path:
    source = Path(args.source).resolve()
    if source.suffix.lower() not in ('.ase', '.aseprite') or not source.is_file():
        raise PipelineError('Supply an existing .ase or .aseprite source.')
    with tempfile.TemporaryDirectory(dir=work_root()) as directory:
        temp = Path(directory)
        run_local([aseprite_bin(), '--batch', str(source), '--sheet-type', 'horizontal',
                   '--sheet', str(temp / 'sheet.png'), '--data', str(temp / 'sheet.json'),
                   '--format', 'json-array', '--list-tags'])
        metadata = json.loads((temp / 'sheet.json').read_text())
        sheet = read_image(temp / 'sheet.png')
        frames = []
        for entry in metadata['frames']:
            if entry.get('trimmed') or entry.get('rotated'):
                raise PipelineError('Trimmed or rotated Aseprite output is unsupported; export full canvases.')
            rect = entry['frame']
            frames.append(sheet.crop((rect['x'], rect['y'], rect['x']+rect['w'], rect['y']+rect['h'])))
        return sprite_bundle(args.name, frames, filtering=args.filter,
            animations=aseprite_animations(metadata),
            provenance={'provider': 'aseprite', 'source': reference(source), 'sha256': sha256(source)})
