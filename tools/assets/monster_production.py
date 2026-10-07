"""Receipt-safe, staged PixelLab production for an original eight-way monster.

Reference uses the same style endpoint as pixellab sprite --style-image.
Inspect its south-facing PNG before create --approve-reference. Status,
resume, collect and pack never POST; dry runs never load keys or write files.
"""
from __future__ import annotations

import argparse
import io
import json
import math
import re
import sys
import time
import zipfile
from pathlib import Path

from common import (ROOT, PipelineError, load_env, read_image, reference, secret,
                    sha256, validate_name, work_root, write_json)
from pixellab import decode_frames, encoded_image, poll_job, request
from sprites import sprite_bundle

NAME = 'brine-stalker-v1'
STYLE = ROOT / '.asset-work/characters/explorer-holding-v2/assembled/p1/0000.png'
DIRECTIONS = ['south', 'south-west', 'west', 'north-west',
              'north', 'north-east', 'east', 'south-east']
PROMPT = (
    'Original Relic Tide Brine Stalker, an amphibious drowned armored creature, '
    'upright biped with grounded compact proportions, head one quarter of body height. '
    'Hand-authored-looking adventure pixel sprite matching the supplied explorer material: '
    'clean native pixel clusters, thin warm dark outline, limestone-blue cool shadows '
    'and warm amber highlights. Moss-teal amphibian skin, blunt ridged head, readable '
    'small amber eyes, battered ochre brass shoulder and chest armor, dark cloth waist '
    'wrap, broad separate webbed feet and two readable clawed hands. Strong original '
    'silhouette, no borrowed game character, no gore, no weapon or held prop. '
    'High top-down view, standing relaxed facing south toward the camera, full body '
    'including both feet. Consistent anatomy and material, detailed but readable '
    'at native resolution. Transparent background, no ground shadow, no effects or text.'
)
ACTIONS = {
    'walk': (12, 12, True,
             'Seamless grounded walking loop in place, facing the supplied direction. '
             'Alternate separate webbed feet with heel contact, weight transfer and bent '
             'knees; opposite restrained claw-arm swing and slight armor weight shift. '
             'Keep the same armor, anatomy and pixel scale; no skating, turning or travel.'),
    'idle': (8, 6, True,
             'Seamless quiet standing idle, facing the supplied direction. Feet planted, '
             'subtle chest breathing and tiny armor settling, relaxed lowered claws. '
             'Keep the same silhouette, anatomy and colors; no foot sliding or turning.'),
    'attack': (8, 12, False,
               'Brief one-shot claw strike, facing the supplied direction. Start in planted '
               'standing idle, wind back one claw, swipe once forward with a clear weight '
               'shift, then recover to the same standing idle. Feet stay in place; no '
               'victim, projectile, effects, gore, turning or costume changes.'),
    'stun': (4, 8, False,
             'Brief one-shot stagger from standing idle, facing the supplied direction. '
             'Bend knees and pull shoulders back in a readable startled flinch, then '
             'remain braced in the final pose. Feet planted; no falling, disappearing, '
             'effects, turning or changes to armor and anatomy.'),
}
STAGES = ['reference', 'character', *ACTIONS,
          *(action + '-' + direction for action in ACTIONS for direction in DIRECTIONS)]
STATUSES = {'pending', 'queued', 'processing', 'running', 'completed',
            'failed', 'cancelled', 'canceled', 'submitting', 'rejected', 'unknown'}


def folder(name: str, *, create: bool = False) -> Path:
    validate_name(name)
    if not re.search(r'-v[1-9][0-9]*$', name):
        raise PipelineError('Use a versioned name ending in -v1, -v2, etc.')
    base = ROOT / '.asset-work'
    target = base / 'characters' / name
    if base.is_symlink() or target.is_symlink() or not target.resolve().is_relative_to(base.resolve()):
        raise PipelineError('Private work directory must stay inside this project.')
    if create:
        work_root()
        target.mkdir(parents=True, exist_ok=True)
    return target


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise PipelineError('Expected a private JSON object.')
    return value


def receipt(name: str, stage: str) -> Path:
    if stage not in STAGES:
        raise PipelineError('Unknown production stage.')
    return folder(name) / 'receipts' / (stage + '.json')


def spec(args, *, save: bool = False) -> dict:
    path = folder(args.name) / 'spec.json'
    previous = read_json(path) if path.exists() else {}
    prompt = (Path(args.prompt_file).read_text().strip() if args.prompt_file
              else previous.get('prompt', PROMPT))
    if not 1 <= len(prompt) <= 2000:
        raise PipelineError('Monster prompt needs 1-2000 characters.')
    style = Path(args.style_image or previous.get('style_image', str(STYLE)))
    style = (style if style.is_absolute() else ROOT / style).resolve()
    if not style.is_relative_to(ROOT.resolve()):
        raise PipelineError('Keep the reusable native style frame inside this project.')
    image = read_image(style)
    if max(image.size) > 256 or image.getchannel('A').getextrema()[0] == 255:
        raise PipelineError('Use a native transparent style frame, at most 256px.')
    result = {'name': args.name, 'prompt': prompt,
              'seed': args.seed if args.seed is not None else previous.get('seed', 20261010),
              'style_image': reference(style), 'style_sha256': sha256(style)}
    if previous and previous != result:
        raise PipelineError('This version already has a different spec; use a new versioned name.')
    if save and not path.exists():
        folder(args.name, create=True)
        write_json(path, result)
        (path.parent / 'source.prompt.txt').write_text(prompt + '\n')
    return result


def safe_status(value) -> str:
    return value if isinstance(value, str) and value in STATUSES else 'unknown'


def job_ids(data: dict) -> list[str]:
    response = data.get('response', {})
    values = response.get('background_job_ids') or [response.get('background_job_id')]
    result = []
    for value in values:
        if value is None:
            continue
        if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', value):
            raise PipelineError('Invalid private job receipt; inspect it before resuming.')
        result.append(value)
    return result


def submit(args, stage: str, endpoint: str, payload: dict, provenance: dict) -> None:
    path = receipt(args.name, stage)
    if path.exists():
        previous = read_json(path)
        if not (args.retry_rejected and previous.get('state') == 'rejected'
                and previous.get('rejected_status') == 429 and previous.get('payload') == payload):
            raise PipelineError('Stage already has a receipt; use status/resume. No duplicate POST.')
    secret('PIXELLAB_API_KEY')
    data = {'name': args.name, 'stage': stage, 'endpoint': endpoint, 'payload': payload,
            'provenance': provenance, 'state': 'submitting'}
    write_json(path, data)  # Preserve ambiguity before the paid POST.
    try:
        data['response'] = request('POST', endpoint, payload)
    except PipelineError as error:
        if str(error).startswith('PixelLab HTTP 429.'):
            data.update(state='rejected', rejected_status=429)
            write_json(path, data)
        raise
    write_json(path, data)  # Keep even an unfamiliar accepted response before validation.
    if endpoint == '/animate-character':
        returned = data['response'].get('directions', [])
        if not returned or not set(returned).issubset(payload['directions']):
            raise PipelineError('Unexpected accepted directions; inspect receipt, never resubmit.')
    jobs = job_ids(data)
    data['state'] = 'processing' if jobs or stage == 'character' else 'unknown'
    if not jobs and stage == 'reference':
        save_reference(args.name, data, data['response'])
        data['state'] = 'completed'
    write_json(path, data)
    print(json.dumps({'stage': stage, 'state': data['state'], 'jobs': len(jobs)}))


def animate(args, direction: str | None = None) -> None:
    if refresh(args.name, 'character')['state'] != 'completed':
        raise PipelineError('Wait for all eight character rotations before animating.')
    current = spec(args)
    count, _, _, prompt = ACTIONS[args.action]
    seed = current['seed'] + 1 + list(ACTIONS).index(args.action)
    stage = args.action
    payload = {'character_id': character_id(args.name), 'animation_name': args.action,
        'mode': 'v3', 'action_description': prompt,
        'directions': [direction] if direction else DIRECTIONS,
        'frame_count': count, 'keep_first_frame': False,
        'enhance_prompt': False, 'seed': seed}
    if direction:
        parent = read_json(receipt(args.name, args.action))
        if direction in parent['response'].get('directions', []):
            raise PipelineError('Direction was already accepted in the base action; resume, no duplicate.')
        group = parent['response'].get('animation_group_id')
        if not isinstance(group, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', group):
            raise PipelineError('Missing original animation group; inspect privately, no duplicate group.')
        payload['animation_group_id'] = group
        stage += '-' + direction
    submit(args, stage, '/animate-character', payload,
           {'action': args.action, 'direction': direction, 'prompt': prompt, 'seed': seed})


def complete_missing(args) -> None:
    # Real service responses may accept fewer directions than requested. Extend
    # that exact group, one missing direction at a time, never the finished ones.
    for action in ACTIONS:
        args.action = action
        parent_path = receipt(args.name, action)
        if not parent_path.exists():
            raise PipelineError('Create each base action before completing its directions.')
        accepted = read_json(parent_path)['response'].get('directions', [])
        for direction in DIRECTIONS:
            path = receipt(args.name, action + '-' + direction)
            if direction in accepted:
                continue
            if path.exists():
                previous = read_json(path)
                if not (args.retry_rejected and previous.get('state') == 'rejected'
                        and previous.get('rejected_status') == 429):
                    continue
            animate(args, direction)


def save_reference(name: str, data: dict, response: dict) -> None:
    frames = decode_frames(response)
    variant = data['provenance']['variant']
    if not 0 <= variant < len(frames):
        raise PipelineError('Reference variant is outside the returned candidate range.')
    image = frames[variant]
    if max(image.size) > 256 or image.getchannel('A').getextrema()[0] == 255:
        raise PipelineError('Reference needs transparency and a native canvas at most 256px.')
    root = folder(name, create=True)
    candidates = root / 'reference-candidates'
    candidates.mkdir(exist_ok=True)
    for index, frame in enumerate(frames):
        frame.save(candidates / ('%02d.png' % index))
    path = root / 'south-reference.png'
    if path.exists():
        if read_image(path).size != image.size or read_image(path).tobytes() != image.tobytes():
            raise PipelineError('A different south reference already exists; do not overwrite it.')
    else:
        image.save(path)
    write_json(root / 'reference.provenance.json', {
        **data['provenance'], 'reference_sha256': sha256(path),
        'canvas': list(image.size), 'returned_candidates': len(frames),
    })
    print('Inspect the south reference before create: ' + reference(path))


def character_id(name: str) -> str:
    path = receipt(name, 'character')
    if not path.exists():
        raise PipelineError('Create the reviewed monster first.')
    data = read_json(path)
    value = data.get('response', {}).get('character_id')
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', value):
        raise PipelineError('Character outcome is unknown; inspect its receipt, never resubmit.')
    source = folder(name) / 'south-reference.png'
    if not source.is_file() or sha256(source) != data['provenance']['reference_sha256']:
        raise PipelineError('Reviewed reference changed; use a new versioned name.')
    return value


def refresh(name: str, stage: str, wait: float = 0) -> dict:
    path = receipt(name, stage)
    data = read_json(path)
    jobs = job_ids(data)
    if data.get('state') in ('submitting', 'rejected', 'unknown') and not jobs:
        raise PipelineError('Unaccepted or ambiguous receipt; inspect privately. Resume never POSTs.')
    deadline = time.monotonic() + wait
    states = []
    completed_response = None
    for index, job in enumerate(jobs):
        value = request('GET', '/background-jobs/' + job)
        if value.get('status') not in ('completed', 'failed', 'cancelled', 'canceled') and wait:
            try:
                value = poll_job(job, max(0, deadline - time.monotonic()))
            except PipelineError as error:
                if 'still processing' not in str(error):
                    raise
        write_json(folder(name) / 'jobs' / ('%s-%02d.json' % (stage, index)), value)
        states.append(safe_status(value.get('status')))
        if value.get('status') == 'completed':
            completed_response = value
    if any(state in ('failed', 'cancelled', 'canceled') for state in states):
        raise PipelineError('Accepted job failed; keep receipts and inspect privately, no resubmission.')
    ready = not jobs or all(state == 'completed' for state in states)
    if stage == 'character':
        detail = request('GET', '/characters/' + character_id(name))
        write_json(folder(name) / 'character-detail.json', detail)
        rotations = set((detail.get('rotation_urls') or {}).keys())
        ready = ready and detail.get('status') == 'completed' and set(DIRECTIONS).issubset(rotations)
    if ready:
        if stage == 'reference':
            save_reference(name, data, completed_response or data['response'])
        data['state'] = 'completed'
        write_json(path, data)
    return {'stage': stage, 'state': safe_status(data.get('state')), 'jobs': states}


def collect(name: str) -> None:
    import requests
    value = character_id(name)
    stages = [stage for stage in STAGES[1:] if receipt(name, stage).exists()]
    for stage in stages:
        if refresh(name, stage)['state'] != 'completed':
            raise PipelineError('Character/actions still processing; resume before collecting.')
    try:
        response = requests.get('https://api.pixellab.ai/v2/characters/' + value + '/zip',
            headers={'Authorization': 'Bearer ' + secret('PIXELLAB_API_KEY')},
            timeout=(15, 120), allow_redirects=False)
    except requests.RequestException as exc:
        raise PipelineError('Character download failed; collect again without resubmitting.') from exc
    if response.status_code != 200 or len(response.content) > 128_000_000:
        raise PipelineError('Character export unavailable or too large; inspect privately.')
    root = folder(name, create=True)
    raw = response.content
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        entries = archive.infolist()
        if len(entries) > 4096 or sum(item.file_size for item in entries) > 128_000_000:
            raise PipelineError('Character export exceeds the source budget.')
        for entry in entries:
            path = Path(entry.filename)
            if (path.is_absolute() or '..' in path.parts or '\\' in entry.filename
                    or entry.file_size > 20_000_000 or (entry.external_attr >> 16) & 0o170000 == 0o120000):
                raise PipelineError('Unsafe character export path or entry.')
        archives = root / 'source-zips'
        archives.mkdir(exist_ok=True)
        import hashlib
        archive_path = archives / (hashlib.sha256(raw).hexdigest() + '.zip')
        if not archive_path.exists():
            archive_path.write_bytes(raw)
        (root / 'export.zip').write_bytes(raw)
        for entry in entries:
            if entry.is_dir() or Path(entry.filename).suffix not in ('.png', '.json'):
                continue
            output = root / 'export' / entry.filename
            if not output.resolve().is_relative_to((root / 'export').resolve()):
                raise PipelineError('Export target escapes its directory.')
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(archive.read(entry))
    write_json(root / 'export.provenance.json', {
        'provider': 'PixelLab managed v3', 'export_sha256': sha256(root / 'export.zip'),
        'actions': [stage for stage in stages if stage in ACTIONS],
    })
    print('Collected original ZIP and native frames for ' + name)


def png_entries(node, trail=()):
    if isinstance(node, dict):
        for key, child in node.items():
            yield from png_entries(child, trail + (str(key),))
    elif isinstance(node, list):
        for child in node:
            yield from png_entries(child, trail)
    elif isinstance(node, str) and node.endswith('.png'):
        yield trail, node


def packed_frames(name: str):
    from PIL import Image
    root = folder(name)
    export = root / 'export'
    metadata = read_json(export / 'metadata.json')
    collected = read_json(root / 'export.provenance.json')
    if sha256(root / 'export.zip') != collected['export_sha256']:
        raise PipelineError('Collected ZIP changed; collect the completed source again.')
    chosen = collected['actions']
    if not {'walk', 'idle'}.issubset(chosen) or any(action not in ACTIONS for action in chosen):
        raise PipelineError('Pack requires completed walk and idle; attack/stun are optional.')
    entries = []
    for state in metadata['states']:
        entries.extend(png_entries(state['frames'].get('animations', {})))
    frames, animations = [], []
    normalize = lambda text: re.sub('[^a-z0-9]', '', text.lower())
    for action in ACTIONS:
        if action not in chosen:
            continue
        count, fps, loop, _ = ACTIONS[action]
        for direction in DIRECTIONS:
            paths = []
            for trail, value in entries:
                keys = {normalize(key) for key in trail}
                if normalize(action) in keys and normalize(direction) in keys:
                    path = (export / value).resolve()
                    if not path.is_relative_to(export.resolve()):
                        raise PipelineError('Animation frame escapes its export.')
                    if path not in paths:
                        paths.append(path)
            if len(paths) != count:
                raise PipelineError('Export frame count differs from the action plan; inspect metadata.')
            start = len(frames)
            frames.extend(read_image(path) for path in paths)
            animations.append({'name': action + '_' + direction.replace('-', '_'),
                'fps': fps, 'loop': loop, 'frames': [(i, 1.0) for i in range(start, len(frames))]})
    canvas = (max(frame.width for frame in frames), max(frame.height for frame in frames))
    columns = min(len(frames), 4096 // (canvas[0] + 2))
    if not columns or max((canvas[0] + 2) * columns,
                         (canvas[1] + 2) * math.ceil(len(frames) / columns)) >= 4096:
        raise PipelineError('Native atlas would reach 4096px; split action bundles, never rescale pixels.')
    aligned = []
    for frame in frames:
        image = Image.new('RGBA', canvas)
        image.paste(frame, ((canvas[0] - frame.width) // 2, (canvas[1] - frame.height) // 2))
        aligned.append(image)
    return aligned, animations, collected


def pack(args) -> None:
    character_id(args.name)  # Verify that the reviewed source has not changed.
    frames, animations, collected = packed_frames(args.name)
    canvas = frames[0].size
    if args.foot_anchor is None or not all(0 <= v < canvas[i] for i, v in enumerate(args.foot_anchor)):
        raise PipelineError('Pack needs a reviewed --foot-anchor X Y inside the common native canvas.')
    root = folder(args.name)
    current_spec = read_json(root / 'spec.json')
    source = root / 'south-reference.png'
    idle = next(item for item in animations if item['name'] == 'idle_south')
    bbox = frames[idle['frames'][0][0]].getchannel('A').getbbox()
    if bbox is None:
        raise PipelineError('South reference is empty.')
    scale = args.display_height / (bbox[3] - bbox[1])
    target = sprite_bundle(args.name, frames, animations=animations, provenance={
        **{key: current_spec[key] for key in ('prompt', 'seed', 'style_image', 'style_sha256')},
        'provider': 'PixelLab style-v2 + character-v3 + animation-v3',
        'reference_sha256': sha256(source), 'export_sha256': collected['export_sha256'],
        'actions': {key: {'frames': value[0], 'fps': value[1], 'loop': value[2],
                         'prompt': value[3]} for key, value in ACTIONS.items() if key in collected['actions']},
        'authoring': 'Native returned pixels centered by transparent padding; no resampling or invented poses.',
    })
    with (target / 'frames.tres').open('a') as stream:
        stream.write('metadata/foot_anchor = Vector2(%s, %s)\nmetadata/display_scale = %s\n'
                     % (*args.foot_anchor, scale))
    manifest = read_json(target / 'manifest.json')
    manifest.update(foot_anchor=args.foot_anchor, display_height=args.display_height, display_scale=scale)
    write_json(target / 'manifest.json', manifest)
    (target / 'source.prompt.txt').write_text(current_spec['prompt'] + '\n')
    (target / 'origin.txt').write_text('Original Relic Tide monster; PixelLab native source preserved in private receipts and export ZIP.\n')
    print('Packed native monster resources: ' + reference(target))


def dry_run(args) -> None:
    current = spec(args) if args.mode in ('plan', 'reference', 'create', 'animate') else None
    actions = {key: {'frames': value[0], 'fps': value[1], 'loop': value[2]}
               for key, value in ACTIONS.items()}
    output = {'name': args.name, 'stage': args.mode, 'dry_run': True,
              'directions': DIRECTIONS, 'actions': actions,
              'required_actions': ['walk', 'idle'], 'optional_actions': ['attack', 'stun']}
    if current:
        output.update(prompt=current['prompt'], style_image=current['style_image'],
                      seed=current['seed'])
    output['reference'] = reference(folder(args.name) / 'south-reference.png')
    output['create_requires'] = 'Inspect south-reference.png, then pass --approve-reference.'
    output['pack_requires'] = 'Completed export, reviewed common-canvas foot anchor; atlas strictly below 4096.'
    if args.mode == 'pack' and (folder(args.name) / 'export/metadata.json').exists():
        frames, animations, _ = packed_frames(args.name)
        output.update(canvas=list(frames[0].size), frames=len(frames), tags=len(animations))
    print(json.dumps(output, indent=2))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['plan', 'balance', 'reference', 'create', 'complete',
                                       'animate', 'status', 'resume', 'collect', 'pack'])
    parser.add_argument('--name', default=NAME)
    parser.add_argument('--prompt-file')
    parser.add_argument('--style-image')
    parser.add_argument('--seed', type=int)
    parser.add_argument('--variant', type=int, default=0)
    parser.add_argument('--action', choices=list(ACTIONS))
    parser.add_argument('--direction', choices=DIRECTIONS)
    parser.add_argument('--stage', choices=['all', *STAGES], default='all')
    parser.add_argument('--wait', type=float, default=0, help='Read-only polling budget, 0-60 seconds')
    parser.add_argument('--approve-reference', action='store_true')
    parser.add_argument('--retry-rejected', action='store_true', help='Retry identical HTTP 429 rejection only')
    parser.add_argument('--foot-anchor', nargs=2, type=float)
    parser.add_argument('--display-height', type=float, default=52)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args(argv)
    try:
        folder(args.name)
        if (args.seed is not None and args.seed < 0) or args.variant < 0:
            raise PipelineError('Seed and variant must be nonnegative.')
        if not math.isfinite(args.wait) or not 0 <= args.wait <= 60:
            raise PipelineError('Wait must be finite and between 0 and 60 seconds.')
        if not math.isfinite(args.display_height) or args.display_height <= 0:
            raise PipelineError('Display height must be finite and positive.')
        if args.foot_anchor and not all(math.isfinite(v) for v in args.foot_anchor):
            raise PipelineError('Foot anchor must be finite.')
        if args.dry_run or args.mode == 'plan':
            dry_run(args)
            return 0
        load_env()
        if args.mode == 'balance':
            value = request('GET', '/balance')
            subscription = value.get('subscription') or {}
            credits = value.get('credits') or {}
            numeric = lambda value: value if isinstance(value, (int, float)) and math.isfinite(value) else None
            print(json.dumps({'usd_credits': numeric(credits.get('usd')),
                'generations_remaining': numeric(subscription.get('generations')),
                'generations_total': numeric(subscription.get('total'))}, indent=2))
        elif args.mode == 'reference':
            current = spec(args, save=True)
            image, size = encoded_image(ROOT / current['style_image'], 256)
            submit(args, 'reference', '/generate-with-style-v2', {
                'description': current['prompt'], 'no_background': True, 'seed': current['seed'],
                'style_images': [{'image': image, 'width': size[0], 'height': size[1]}],
            }, {**current, 'variant': args.variant})
        elif args.mode == 'create':
            if not args.approve_reference:
                raise PipelineError('Inspect the native south reference, then pass --approve-reference.')
            current = spec(args)
            source = folder(args.name) / 'south-reference.png'
            image, _ = encoded_image(source, 256)
            submit(args, 'character', '/create-character-v3', {
                'name': args.name, 'description': current['prompt'], 'reference_image': image,
                'view': 'high top-down', 'template_id': 'mannequin', 'no_background': True,
                'outline': 'dark colored thin outline', 'detail': 'high detail',
                'seed': current['seed'], 'enhance_prompt': False,
            }, {'reference_sha256': sha256(source), 'reviewed': True, 'seed': current['seed']})
        elif args.mode == 'animate':
            if args.action is None:
                raise PipelineError('Animate one reviewed action with --action walk/idle/attack/stun.')
            animate(args, args.direction)
        elif args.mode == 'complete':
            complete_missing(args)
        elif args.mode in ('status', 'resume'):
            for stage in STAGES:
                if (args.stage in ('all', stage)) and receipt(args.name, stage).exists():
                    if args.mode == 'resume':
                        print(json.dumps(refresh(args.name, stage, args.wait)))
                    else:
                        data = read_json(receipt(args.name, stage))
                        states = [safe_status(request('GET', '/background-jobs/' + job).get('status'))
                                  for job in job_ids(data)]
                        output = {'stage': stage, 'state': safe_status(data.get('state')), 'jobs': states}
                        if stage == 'character':
                            detail = request('GET', '/characters/' + character_id(args.name))
                            output.update(character_status=safe_status(detail.get('status')),
                                          rotations=len(detail.get('rotation_urls') or {}))
                        print(json.dumps(output))
        elif args.mode == 'collect':
            collect(args.name)
        else:
            pack(args)
        return 0
    except PipelineError as error:
        print('Monster pipeline: ' + str(error), file=sys.stderr)
    except (OSError, ValueError, KeyError, TypeError, AttributeError, ImportError, zipfile.BadZipFile) as error:
        print('Monster pipeline: ' + type(error).__name__ + '; inspect private inputs.', file=sys.stderr)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
