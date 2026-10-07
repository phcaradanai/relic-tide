"""Pack reviewed PixelLab export frames and four editable crew palettes."""
from __future__ import annotations
import colorsys
import json
from pathlib import Path
from PIL import Image
from character_production import ACTIONS, DIRECTIONS, folder
from common import ROOT, PipelineError, aseprite_bin, run_local, sha256, write_json
from sprites import sprite_bundle


def png_entries(node, trail=()):
    if isinstance(node, dict):
        for key, value in node.items():
            yield from png_entries(value, trail + (str(key),))
    elif isinstance(node, list):
        for value in node:
            yield from png_entries(value, trail)
    elif isinstance(node, str) and node.endswith('.png'):
        yield trail, node


def normalized(value):
    return str(value).lower().replace('-', '_')


def palette(image, hue):
    output = image.copy()
    pixels = output.load()
    for y in range(output.height):
        for x in range(output.width):
            r, g, b, alpha = pixels[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            # Keep skin, leather, hair, metal and boot shading intact.
            if alpha and 0.43 <= h <= 0.63 and s > 0.28 and v > 0.10:
                rgb = colorsys.hsv_to_rgb(hue, s, v)
                pixels[x, y] = (*[round(c * 255) for c in rgb], alpha)
    return output


def mute_backpack_glass(image):
    """Author the baked shoulder accessory as dull gear, not a free held light."""
    image = image.copy()
    pixels = image.load()
    bright = {(x, y) for y in range(image.height) for x in range(image.width)
              if pixels[x, y][3] and pixels[x, y][0] > 200 and pixels[x, y][1] > 180 and pixels[x, y][2] > 75}
    while bright:
        component, queue = set(), [bright.pop()]
        while queue:
            x, y = queue.pop()
            component.add((x, y))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    other = (x + dx, y + dy)
                    if other in bright:
                        bright.remove(other)
                        queue.append(other)
        if len(component) < 3: continue  # Preserve single metal and collar glints.
        if sum(pixels[x, y][0] for x, y in component) > 1.15 * sum(pixels[x, y][1] for x, y in component):
            continue  # Warm skin and leather highlights keep their original color.
        for x, y in component:
            pixels[x, y] = (139, 151, 128, pixels[x, y][3])
    return image


def author_carry(aligned, animations):
    """Keep the generated planted-leg cycle and a consistent supporting torso.

    v3 produced a stand-to-carry lead-in, and its carry-idle ignored the hands.
    Use actual carrying raster parts to correct these two poses in Aseprite.
    """
    lookup = {a['name']: a for a in animations}
    for direction in DIRECTIONS:
        suffix = direction.replace('-', '_')
        walk = lookup['carry_walk_' + suffix]['frames']
        idle = lookup['carry_idle_' + suffix]['frames']
        originals = [aligned[index].copy() for index, _ in walk]
        pose = originals[5]
        split = round(pose.height / 2 + 14)
        upper = pose.crop((0, 0, pose.width, split + 3))
        for number, (index, _) in enumerate(walk):
            frame = Image.new('RGBA', pose.size)
            frame.paste(originals[number].crop((0, split, pose.width, pose.height)), (0, split))
            bob = max(-1, min(1, originals[number].getbbox()[1] - pose.getbbox()[1]))
            frame.paste(upper, (0, bob), upper)
            aligned[index] = frame
        lower = originals[0].crop((0, split, pose.width, pose.height))
        for number, (index, _) in enumerate(idle):
            frame = Image.new('RGBA', pose.size)
            frame.paste(lower, (0, split))
            bob = (0, 0, 0, -1, -1, -1, 0, 0)[number]
            frame.paste(upper, (0, bob), upper)
            aligned[index] = frame


def main():
    export = folder() / 'export'
    metadata = json.loads((export / 'metadata.json').read_text())
    entries = []
    for state in metadata['states']:
        entries.extend(png_entries(state['frames'].get('animations', {})))
    source_frames, animations = [], []
    for action, (count, _) in ACTIONS.items():
        for direction in DIRECTIONS:
            paths = []
            for trail, path in entries:
                parts = {normalized(k) for k in trail}
                if normalized(action) in parts and normalized(direction) in parts:
                    candidate = (export / path).resolve()
                    if not candidate.is_relative_to(export.resolve()):
                        raise PipelineError('Export frame escapes the private directory.')
                    if candidate not in paths: paths.append(candidate)
            if len(paths) != count:
                raise PipelineError(f'{action} {direction}: expected {count} exported animation frames, found {len(paths)}. Inspect metadata before packing.')
            start = len(source_frames)
            source_frames.extend(Image.open(path).convert('RGBA') for path in paths)
            animations.append({'name': action + '_' + direction.replace('-', '_'),
                'fps': 6 if action in ('idle', 'carry_idle') else (12 if 'walk' in action or action == 'wade' else 8),
                'loop': action != 'down', 'frames': [(i, 1.0) for i in range(start, len(source_frames))]})
    canvas = (max(im.width for im in source_frames), max(im.height for im in source_frames))
    aligned = []
    for image in source_frames:
        padded = Image.new('RGBA', canvas)
        padded.paste(image, ((canvas[0] - image.width) // 2, (canvas[1] - image.height) // 2))
        aligned.append(mute_backpack_glass(padded))
    author_carry(aligned, animations)
    feet = (canvas[0] / 2, canvas[1] / 2 + 30)
    staging = folder() / 'assembled'
    staging.mkdir(exist_ok=True)
    crew = []
    for player, hue in enumerate((0.47, 0.035, 0.115, 0.75), 1):
        frames = [palette(image, hue) for image in aligned]
        source_dir = staging / ('p%d' % player)
        source_dir.mkdir(exist_ok=True)
        for i, frame in enumerate(frames): frame.save(source_dir / ('%04d.png' % i))
        name = 'explorer-eight-way-p%d-v1' % player
        target = sprite_bundle(name, frames, animations=animations,
            provenance={'provider': 'PixelLab character-v3 + animation-v3',
                'prompt': 'tools/assets/examples/explorer-eight-way.prompt.txt',
                'prompt_sha256': sha256(ROOT / 'tools/assets/examples/explorer-eight-way.prompt.txt'),
                'export_sha256': sha256(folder() / 'export.zip'),
                'palette': ['mint', 'coral', 'amber', 'lavender'][player - 1],
                'authoring': 'native pixels padded; cloth hue variants; bright backpack glass muted; supporting torso and planted legs composited from actual carry-walk poses; no resampling',
                'reference_handling': 'ZIP preserves all original rotation references and explicit animation frames; runtime uses ZIP animation metadata',
                'editable_source': 'assets/authored/explorer-eight-way-v1.aseprite'})
        resource = target / 'frames.tres'
        with resource.open('a') as stream:
            stream.write('metadata/foot_anchor = Vector2(%s, %s)\nmetadata/display_scale = %s\n' % (*feet, 44 / 60))
        manifest = json.loads((target / 'manifest.json').read_text())
        manifest.update(foot_anchor=feet, display_height=44, display_scale=44 / 60)
        write_json(target / 'manifest.json', manifest)
        crew.append({'name': ['P1 Mint', 'P2 Coral', 'P3 Amber', 'P4 Lavender'][player - 1],
            'path': str(source_dir)})
    write_json(staging / 'aseprite.json', {'canvas': canvas, 'crew': crew, 'animations': animations,
        'frames': len(aligned)})
    run_local([aseprite_bin(), '--batch', '--script-param', 'root=' + str(ROOT),
        '--script', str(ROOT / 'tools/assets/examples/assemble-eight-way.lua')])
    print('Packed %d authored frames × 4 crew palettes, %d directional actions each.' % (len(aligned), len(animations)))


if __name__ == '__main__': main()
