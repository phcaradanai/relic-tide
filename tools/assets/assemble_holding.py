"""Assemble the reviewed integrated hand/prop poses without fixed prop overlays."""
from __future__ import annotations
import json
import math
import argparse
from pathlib import Path
from PIL import Image
from assemble_character import mute_backpack_glass, normalized, palette, png_entries
from character_production import DIRECTIONS
from holding_production import ACTIONS
from common import ROOT, PipelineError, aseprite_bin, run_local, sha256, write_json
from sprites import sprite_bundle

WORK = ROOT / '.asset-work/characters/explorer-holding-v2'
BASE_ACTIONS = {'walk': 12, 'idle': 8, 'use': 8, 'wade': 12, 'down': 8}


def exported_frames(export, action, direction, count):
    metadata = json.loads((export / 'metadata.json').read_text())
    paths = []
    for state in metadata['states']:
        for trail, value in png_entries(state['frames'].get('animations', {})):
            parts = {normalized(k) for k in trail}
            if normalized(action) in parts and normalized(direction) in parts:
                path = (export / value).resolve()
                if not path.is_relative_to(export.resolve()): raise PipelineError('Unsafe export path.')
                if path not in paths: paths.append(path)
    if len(paths) != count:
        raise PipelineError(f'{action} {direction}: expected {count} frames, found {len(paths)}.')
    return [Image.open(path).convert('RGBA') for path in paths]


def align(image, canvas):
    result = Image.new('RGBA', canvas)
    result.paste(image, ((canvas[0] - image.width) // 2, (canvas[1] - image.height) // 2))
    return mute_backpack_glass(result)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack-only',action='store_true',help='Pack runtime atlases; author the Aseprite master in a separate native invocation.')
    args=parser.parse_args()
    export = WORK / 'export'
    groups = {}
    for action, count in BASE_ACTIONS.items():
        for direction in DIRECTIONS:
            groups[action, direction] = exported_frames(export, action, direction, count)
    for action, (count, _) in ACTIONS.items():
        for direction in DIRECTIONS:
            groups[action, direction] = exported_frames(export, action, direction, count)
    # v3 adds transparent margins around interpolation frames. Remove only
    # padding, retaining every authored pixel in a common native-size canvas.
    extent=[44.0,44.0]
    for images in groups.values():
        for image in images:
            box=image.getbbox()
            if not box:raise PipelineError('Empty authored pose.')
            for axis in (0,1):
                extent[axis]=max(extent[axis],abs(box[axis]-image.size[axis]/2),abs(box[axis+2]-image.size[axis]/2))
    canvas=tuple(math.ceil(half*2/4)*4 for half in extent)
    if (canvas[1]+2)*math.ceil(1376/(4096//(canvas[0]+2)))>4096:
        raise PipelineError('Reviewed content exceeds the web atlas budget; split the bundle before publishing.')
    groups = {key: [align(im, canvas) for im in images] for key, images in groups.items()}
    rear_review=WORK/'rear-pickups/review.json'
    for key,paths in json.loads(rear_review.read_text()).items():
        action,direction=key.rsplit('_',1)
        if len(paths)!=16 or direction not in ('north','north-east','north-west'):
            raise PipelineError('Invalid reviewed rear pickup clip.')
        frames=[]
        for path in paths:
            candidate=(rear_review.parent/path).resolve()
            if not candidate.is_relative_to(rear_review.parent.resolve()):
                raise PipelineError('Unsafe rear pickup path.')
            frames.append(align(Image.open(candidate).convert('RGBA'),canvas))
        groups[action,direction]=frames
    # The provider may lift a boot or redraw the prop in its final generated
    # pose. Settle on the artist's exact planted, gripping target for the handoff.
    for action in ACTIONS:
        if not action.startswith('pickup_'):continue
        for direction in DIRECTIONS:
            target=Image.open(WORK/'pickup-inputs'/(action+'-'+direction+'-end.png')).convert('RGBA')
            groups[action,direction][-1]=align(target,canvas)
    # The accepted generated walk leads in with empty hands. An authored upper
    # pose keeps the real fingers and prop together; boots retain all gait poses.
    reviewed = json.loads((WORK / 'review.json').read_text())
    for kind in ('relic', 'lantern', 'dual'):
        for direction in DIRECTIONS:
            source = groups[kind + '_walk', direction]
            config = reviewed[kind][direction]
            pose = source[config['pose']]
            split = config.get('split',58) + (canvas[1]-88)//2
            upper = pose.crop((0, 0, canvas[0], split))
            # Native pixel repairs are authored PNGs, never procedural bodies.
            repair = config.get('repair')
            if repair:
                reference = align(Image.open(WORK / 'repairs' / repair).convert('RGBA'),canvas)
                upper = Image.new('RGBA',canvas)
                upper.paste(reference.crop((0,0,canvas[0],split)),(0,0))
                for x,y,w,h in config.get('extra',[]):
                    x += (canvas[0]-88)//2
                    y += (canvas[1]-88)//2
                    upper.paste(reference.crop((x,y,x+w,y+h)),(x,y))
            legs = groups['walk', direction]
            if kind == 'relic':
                legs = [align(im, canvas) for im in exported_frames(export, 'carry_walk', direction, 12)]
            walk = []
            for i in range(12):
                frame = Image.new('RGBA', canvas)
                frame.paste(legs[i].crop((0, split, canvas[0], canvas[1])), (0, split))
                bob = config.get('bob', [0,0,-1,-1,0,0,0,0,-1,-1,0,0])[i]
                frame.alpha_composite(upper, (0, bob))
                walk.append(frame)
            groups[kind + '_walk', direction] = walk
            lower = groups['idle', direction][0].crop((0, split, canvas[0], canvas[1]))
            idle = []
            for bob in (0,0,0,-1,-1,-1,0,0):
                frame = Image.new('RGBA', canvas)
                frame.paste(lower, (0, split))
                frame.alpha_composite(upper, (0, bob))
                idle.append(frame)
            groups[kind + '_idle', direction] = idle
    frames, animations = [], []
    for (action, direction), poses in groups.items():
        start = len(frames)
        frames.extend(poses)
        animations.append({'name': action + '_' + direction.replace('-', '_'),
            'fps': 18 if action.startswith('pickup_') else 6 if action.endswith('idle') else 12 if action.endswith('walk') or action == 'wade' else 8,
            'loop': not (action.startswith('pickup_') or action == 'down'),
            'frames': [(i, 1.0) for i in range(start,len(frames))]})
    feet = (canvas[0] / 2, canvas[1] / 2 + 30)
    staging = WORK / 'assembled'
    staging.mkdir(exist_ok=True)
    crew = []
    for player,hue in enumerate((0.47,0.035,0.115,0.75),1):
        colored = [palette(im,hue) for im in frames]
        source = staging / f'p{player}'
        source.mkdir(exist_ok=True)
        for i, im in enumerate(colored): im.save(source / f'{i:04d}.png')
        target = sprite_bundle(f'explorer-holding-p{player}-v2', colored, animations=animations,
            provenance={'provider':'PixelLab managed v3 + native Aseprite authoring',
                'export_sha256':sha256(WORK / 'export.zip'),
                'editable_source':'assets/authored/explorer-holding-v2.aseprite',
                'authoring':'Integrated real props and fingers; original gait, planted boots and authored rear kneeling poses; shared pixel bob; four cloth hues',
                'rear_review_sha256':sha256(rear_review),
                'review_sha256':sha256(WORK / 'review.json')})
        with (target / 'frames.tres').open('a') as stream:
            stream.write('metadata/foot_anchor = Vector2(%s, %s)\nmetadata/display_scale = %s\n' % (*feet,44/60))
        manifest = json.loads((target / 'manifest.json').read_text())
        manifest.update(foot_anchor=feet,display_height=44,display_scale=44/60)
        write_json(target / 'manifest.json',manifest)
        crew.append({'name':['P1 Mint','P2 Coral','P3 Amber','P4 Lavender'][player-1],'path':str(source)})
    write_json(staging / 'aseprite.json',{'canvas':canvas,'crew':crew,'animations':animations,'frames':len(frames)})
    if args.pack_only:
        print(f'Packed {len(frames)} frames × 4 palettes, {len(animations)} directional actions; Aseprite source ready to assemble.')
        return
    run_local([aseprite_bin(),'--batch','--script-param','root='+str(ROOT),
        '--script-param','manifest='+str(staging/'aseprite.json'),
        '--script-param','output='+str(ROOT/'assets/authored/explorer-holding-v2.aseprite'),
        '--script',str(ROOT/'tools/assets/examples/assemble-eight-way.lua')])
    print(f'Packed {len(frames)} frames × 4 palettes, {len(animations)} directional actions with integrated grips.')


if __name__ == '__main__':
    try: main()
    except PipelineError as error: raise SystemExit(str(error))
