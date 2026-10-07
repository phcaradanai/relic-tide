"""Produce the approved eight-way explorer with PixelLab's managed v3 API.

Paid submissions are reserved before POST; status/collect never resubmit them.
Provider receipts and export metadata stay outside shipped game assets.
"""
from __future__ import annotations

import argparse
import io
import json
import re
import time
import zipfile
from pathlib import Path

from common import ROOT, PipelineError, load_env, sha256, work_root, write_json
from pixellab import request

NAME = 'explorer-eight-way-v1'
DIRECTIONS = ['south', 'south-west', 'west', 'north-west', 'north', 'north-east', 'east', 'south-east']
ACTIONS = {
    'walk': (12, 'Seamless grounded walking loop in place, facing the supplied direction throughout. A complete alternating left and right leg cycle: heel contact, weight down, passing foot, opposite heel contact. Clear separate boot placement, bent knees, small one-pixel body rise and fall, opposite arm swing, slight delayed scarf follow-through. Steady relaxed purposeful walking, constant costume and proportions. No traveling across the canvas, no turning, no skating, no running.'),
    'idle': (8, 'Seamless quiet standing idle loop in place facing the supplied direction. Feet planted, gentle breathing in shoulders and chest, tiny scarf settling motion, relaxed empty hands. No foot sliding, no jumping, no turning, no change of costume or proportions.'),
    'carry_walk': (12, 'Seamless slow walking loop in place facing the supplied direction. Both hands held together in front of the chest supporting a small heavy object, but do not draw the object; it is a separate game layer. Alternating planted boots, clear knee bend, careful shorter steps and slight weight shift. Arms remain supporting the same empty space. No turning, no costume changes, no skating.'),
    'carry_idle': (8, 'Seamless standing idle facing the supplied direction. Both hands held together just in front of the chest, supporting a small heavy object, but do not draw any object. Feet planted, slight breathing and weight of the arms. Constant costume and proportions. No turning, no foot sliding.'),
    'use': (8, 'Seamless operating a nearby valve wheel with both hands in front, facing the supplied direction. Feet firmly planted apart. Alternate reaching and pushing hands in a small circular hand-over-hand motion, slight torso lean, visible elbows. Draw only the character, no wheel or object. Constant anatomy, costume and orientation, no traveling or turning.'),
    'wade': (12, 'Seamless cautious wading walk in place facing the supplied direction. Lift alternating knees higher, plant each separate boot deliberately, arms slightly out for balance, slower grounded steps and subtle body weight shift. Draw no water and no effects, only the complete character. Constant proportions and costume, no turning or canvas drift.'),
    'down': (8, 'One-shot exhausted collapse facing the supplied direction. Begin standing, bend knees, sink into a crouch then slump onto the floor and remain lying exhausted in the final frame. Clear readable weight transfer and separate limbs. No disappearing, no effects, no text, constant costume and anatomy.'),
}


def folder() -> Path:
    result = work_root() / 'characters' / NAME
    result.mkdir(parents=True, exist_ok=True)
    return result


def receipt(kind: str) -> Path:
    return folder() / (kind + '.json')


def read(kind: str) -> dict:
    path = receipt(kind)
    if not path.exists():
        raise PipelineError(f'No {kind} receipt; submit that stage first.')
    return json.loads(path.read_text())


def character_id() -> str:
    value = read('character').get('response', {}).get('character_id', '')
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', value):
        raise PipelineError('Character submission outcome is unknown. Check the dashboard; do not resubmit.')
    return value


def submit(kind: str, endpoint: str, payload: dict) -> None:
    path = receipt(kind)
    if path.exists():
        previous = json.loads(path.read_text())
        # A documented HTTP 429 rejected the request before it was accepted.
        # Ambiguous submissions and accepted jobs must never be retried.
        if previous.get('state') != 'rate_limited' or previous.get('payload') != payload:
            raise PipelineError(f'{kind} already has a receipt. Use status/collect; no duplicate POST.')
    data = {'name': NAME, 'kind': kind, 'endpoint': endpoint, 'payload': payload, 'state': 'submitting'}
    write_json(path, data)
    try:
        data['response'] = request('POST', endpoint, payload)
    except PipelineError as error:
        if str(error).startswith('PixelLab HTTP 429.'):
            data.update(state='rate_limited', rejected_status=429)
            write_json(path, data)
        raise
    data['state'] = 'processing'
    write_json(path, data)
    response = data['response']
    print(json.dumps({'stage': kind, 'status': response.get('status'),
                      'job_count': len(response.get('background_job_ids', [])) or 1,
                      'usage': response.get('usage')}, indent=2))


def create() -> None:
    prompt = (ROOT / 'tools/assets/examples/explorer-eight-way.prompt.txt').read_text().strip()
    submit('character', '/create-character-v3', {'name': 'Relic Tide Explorer v1',
        'description': prompt, 'image_size': {'width': 64, 'height': 64},
        'view': 'high top-down', 'template_id': 'mannequin', 'no_background': True,
        'outline': 'dark colored thin outline', 'detail': 'high detail',
        'seed': 20261007, 'enhance_prompt': False})


def animate(action: str) -> None:
    count, prompt = ACTIONS[action]
    submit(action, '/animate-character', {'character_id': character_id(), 'animation_name': action,
        'mode': 'v3', 'action_description': prompt, 'directions': DIRECTIONS,
        'frame_count': count, 'keep_first_frame': False, 'enhance_prompt': False,
        'seed': 20261007 + list(ACTIONS).index(action)})


def status() -> None:
    detail = request('GET', '/characters/' + character_id())
    write_json(folder() / 'detail.json', detail)
    print(json.dumps({'character': detail.get('status'), 'size': detail.get('size'),
        'rotations': list((detail.get('rotation_urls') or {}).keys()),
        'animation_count': detail.get('animation_count')}, indent=2))
    for path in sorted(folder().glob('*.json')):
        if path.name == 'detail.json':
            continue
        data = json.loads(path.read_text())
        response = data.get('response', {})
        jobs = response.get('background_job_ids') or [response.get('background_job_id')]
        states = []
        for job in jobs:
            if not job:
                continue
            value = request('GET', '/background-jobs/' + job)
            # Raw results can contain images/URLs; keep them private and print only states.
            write_json(folder() / 'jobs' / (job + '.json'), value)
            states.append(value.get('status'))
        print(data.get('kind'), states)


def collect(destination: Path | None = None) -> None:
    import requests
    response = requests.get('https://api.pixellab.ai/v2/characters/' + character_id() + '/zip',
                            timeout=(15, 120), allow_redirects=False)
    if response.status_code != 200:
        raise PipelineError(f'Character export HTTP {response.status_code}; wait for pending jobs, then collect again.')
    raw = response.content
    destination = destination or folder()
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'export.zip').write_bytes(raw)
    target = destination / 'export'
    target.mkdir(exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        for entry in archive.infolist():
            path = Path(entry.filename)
            if path.is_absolute() or '..' in path.parts or entry.file_size > 20_000_000:
                raise PipelineError('Unsafe character export path/size.')
            if entry.is_dir() or path.suffix not in ('.png', '.json'):
                continue
            output = target / path
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(archive.read(entry))
    print(f'Collected character export: {len(list(target.rglob("*.png")))} PNG frames. SHA256 {sha256(destination / "export.zip")}')


def produce() -> None:
    """Resume accepted jobs, and retry only requests explicitly rejected with 429."""
    for action in ACTIONS:
        while not receipt(action).exists() or read(action).get('state') == 'rate_limited':
            try:
                animate(action)
            except PipelineError as error:
                if not str(error).startswith('PixelLab HTTP 429.'):
                    raise
                print(f'{action}: provider rate limit; waiting 60 seconds.', flush=True)
                time.sleep(60)
        data = read(action)
        jobs = data.get('response', {}).get('background_job_ids')
        if not jobs:
            raise PipelineError(f'{action}: outcome unknown; inspect receipt, never resubmit.')
        last_count = -1
        while True:
            completed = 0
            limited = False
            for job in jobs:
                try:
                    result = request('GET', '/background-jobs/' + job)
                except PipelineError as error:
                    if not str(error).startswith('PixelLab HTTP 429.'):
                        raise
                    limited = True
                    break
                if result.get('status') in ('failed', 'cancelled', 'canceled'):
                    raise PipelineError(f'{action}: accepted job failed; inspect the dashboard, no resubmission.')
                if result.get('status') == 'completed':
                    completed += 1
            if completed != last_count and not limited:
                print(f'{action}: {completed}/{len(jobs)} directions completed.', flush=True)
                last_count = completed
            if completed == len(jobs):
                data['state'] = 'completed'
                write_json(receipt(action), data)
                break
            time.sleep(30 if limited else 15)
    collect()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['create', 'animate', 'status', 'collect', 'produce'])
    parser.add_argument('--action', choices=list(ACTIONS))
    args = parser.parse_args()
    load_env()
    if args.mode == 'create': create()
    elif args.mode == 'animate':
        if not args.action: parser.error('animate requires --action')
        animate(args.action)
    elif args.mode == 'status': status()
    elif args.mode == 'produce': produce()
    else: collect()


if __name__ == '__main__':
    try: main()
    except PipelineError as error:
        raise SystemExit(str(error))
