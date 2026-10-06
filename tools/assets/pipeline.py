#!/usr/bin/env python3
"""Project-local, agent-callable asset commands; run --help for the contract."""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
import sys
from pathlib import Path

from common import (ROOT, PipelineError, aseprite_bin, godot_bin, load_env, run_local)


def positive(value):
    result = float(value)
    if not math.isfinite(result) or result <= 0:
        raise argparse.ArgumentTypeError('Must be positive.')
    return result


def nonnegative(value):
    result = float(value)
    if not math.isfinite(result) or result < 0:
        raise argparse.ArgumentTypeError('Must be a finite nonnegative number.')
    return result


def parser():
    command = argparse.ArgumentParser(description=__doc__)
    sub = command.add_subparsers(dest='command', required=True)
    sub.add_parser('init', help='Create private .env.assets from template, without replacing an existing file')
    sub.add_parser('doctor', help='Report tool/key readiness without printing keys or making paid calls')
    sub.add_parser('godot-import', help='Import resources using the installed Godot editor headlessly')

    pixel = sub.add_parser('pixellab', help='Paid sprite generation and resumable animation jobs')
    modes = pixel.add_subparsers(dest='mode', required=True)
    modes.add_parser('balance', help='Read API credit/subscription allowance without submitting a generation')
    sprite = modes.add_parser('sprite')
    sprite.add_argument('--prompt-file', required=True)
    sprite.add_argument('--width', type=int, default=128)
    sprite.add_argument('--height', type=int, default=128)
    sprite.add_argument('--direction', choices=['north', 'north-east', 'east', 'south-east', 'south',
                        'south-west', 'west', 'north-west'], default='south')
    sprite.add_argument('--style-image', help='Use official style endpoint at reference resolution (max 512px)')
    sprite.add_argument('--variant', type=int, default=0, help='Select one style-generated candidate; never animate unrelated candidates')
    animation = modes.add_parser('animation')
    animation.add_argument('--source', required=True)
    animation.add_argument('--action', required=True)
    animation.add_argument('--frames', type=int, default=8)
    for mode in [sprite, animation]:
        mode.add_argument('--name', required=True)
        mode.add_argument('--animation', default='idle' if mode is sprite else 'walk_south')
        mode.add_argument('--fps', type=positive, default=10)
        mode.add_argument('--seed', type=int, default=42)
        mode.add_argument('--filter', choices=['nearest', 'linear'], default='nearest')
        mode.add_argument('--wait', type=nonnegative, default=0, help='Seconds to poll after submission; default saves receipt and exits')
    poll = modes.add_parser('poll')
    poll.add_argument('--name', required=True)
    poll.add_argument('--wait', type=nonnegative, default=300)
    poll.add_argument('--job-id', help='Recover an ambiguous submission using the actual dashboard job id')
    poll.add_argument('--accept-returned-frames', action='store_true',
                      help='After review, keep every returned frame if its count differs; never guess or drop frames')

    imported = sub.add_parser('import-frames', help='Aligned transparent PNG frames -> SpriteFrames + node')
    imported.add_argument('--source', required=True, help='Directory with zero-padded PNG filenames')
    imported.add_argument('--name', required=True)
    imported.add_argument('--animation', default='idle')
    imported.add_argument('--fps', type=positive, default=10)
    imported.add_argument('--filter', choices=['nearest', 'linear'], default='linear')
    aseprite = sub.add_parser('aseprite', help='Export/import .aseprite with tags and exact frame durations')
    aseprite.add_argument('--source', required=True)
    aseprite.add_argument('--name', required=True)
    aseprite.add_argument('--filter', choices=['nearest', 'linear'], default='linear')

    depth = sub.add_parser('depth', help='Generate a local DA-V2 depth asset or import an existing map')
    depth_modes = depth.add_subparsers(dest='mode', required=True)
    generate = depth_modes.add_parser('generate')
    generate.add_argument('--input-size', type=int, default=518)
    generate.add_argument('--device', choices=['auto', 'cpu', 'mps', 'cuda'], default='auto')
    imported_depth = depth_modes.add_parser('import')
    imported_depth.add_argument('--depth-map', required=True)
    imported_depth.add_argument('--near-is-dark', action='store_true')
    for mode in [generate, imported_depth]:
        mode.add_argument('--name', required=True)
        mode.add_argument('--source', required=True)

    flow = sub.add_parser('depthflow', help='One cloud image render or optional local image+depth preview')
    flow_modes = flow.add_subparsers(dest='mode', required=True)
    prepare = flow_modes.add_parser('prepare', help='Copy a named depth asset to a neutral image/depth input bundle')
    local = flow_modes.add_parser('local', help='DepthFlow 1.0.1 Python preview; opt-in window, optional MP4')
    local.add_argument('--render', action='store_true')
    local.add_argument('--seconds', type=positive, default=5)
    local.add_argument('--fps', type=positive, default=30)
    local.add_argument('--amplitude', type=float, default=0.01)
    cloud = flow_modes.add_parser('cloud', help='Submit exactly one request to the dashboard-documented image upload API')
    cloud.add_argument('--source', required=True)
    cloud.add_argument('--payload-file', required=True)
    cloud.add_argument('--url-field', help='Optional confirmed result URL field (dot path), no assumed schema')
    collect = flow_modes.add_parser('collect', help='Download an HTTPS MP4 from a selected private response JSON field')
    collect.add_argument('--url-field', required=True)
    for mode in [prepare, local, cloud, collect]:
        mode.add_argument('--name', required=True)
    return command


def init():
    path = ROOT / '.env.assets'
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        print('.env.assets already exists; preserved.')
        return
    with os.fdopen(descriptor, 'w') as file:
        file.write((ROOT / '.env.assets.example').read_text())
    print('Created private .env.assets. Edit it locally to add API keys; do not paste them into chat.')


def doctor():
    from common import secret
    from depth import checkout, depth_python
    report = {'python': sys.version.split()[0], 'dependencies': {}, 'keys': {}, 'tools': {}}
    for name in ['PIL', 'requests']:
        report['dependencies'][name] = importlib.util.find_spec(name) is not None
    for name in ['PIXELLAB_API_KEY', 'DEPTHFLOW_API_KEY']:
        try:
            secret(name)
            report['keys'][name] = 'configured (not authenticated)'
        except PipelineError:
            report['keys'][name] = 'missing/placeholder'
    for name, lookup in [('godot', godot_bin), ('aseprite', aseprite_bin), ('depth_python', depth_python)]:
        try:
            report['tools'][name] = lookup()
        except PipelineError:
            report['tools'][name] = 'missing; configure executable in .env.assets'
    folder = checkout()
    report['tools']['depth_checkout'] = (folder / 'depth_anything_v2/dpt.py').is_file()
    report['tools']['vits_checkpoint'] = Path(os.environ.get('DEPTH_ANYTHING_CHECKPOINT',
        str(folder / 'checkpoints/depth_anything_v2_vits.pth'))).expanduser().is_file()
    report['depthflow_cloud'] = 'enabled by user (2026-10-07); fixed upload origin; account-entitlement MP4 verified; no watermark in sampled frames'
    report['depthflow_local'] = 'optional, not installed; native Godot depth preview is available'
    print(json.dumps(report, indent=2))


def main():
    args = parser().parse_args()
    try:
        load_env()
        output = None
        if args.command == 'init':
            init()
        elif args.command == 'doctor':
            doctor()
        elif args.command == 'godot-import':
            run_local([godot_bin(), '--headless', '--editor', '--path', str(ROOT), '--import'], godot_check=True)
        elif args.command == 'pixellab':
            from pixellab import request, resume, submit
            if args.mode == 'balance':
                balance = request('GET', '/balance')
                print(json.dumps({key: balance.get(key) for key in ['credits', 'subscription']}, indent=2))
            else:
                output = resume(args) if args.mode == 'poll' else submit(args)
        elif args.command == 'import-frames':
            from sprites import import_frames
            output = import_frames(args)
        elif args.command == 'aseprite':
            from sprites import aseprite_import
            output = aseprite_import(args)
        elif args.command == 'depth':
            from depth import generate, import_depth
            output = generate(args) if args.mode == 'generate' else import_depth(args)
        elif args.command == 'depthflow':
            from depth import cloud_collect, cloud_submit, local_preview, prepare
            output = {'cloud': cloud_submit, 'collect': cloud_collect,
                      'local': local_preview, 'prepare': prepare}[args.mode](args)
        if output:
            print(f'Ready: {output}')
        return 0
    except PipelineError as exc:
        print(f'Asset pipeline: {exc}', file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError, ImportError) as exc:
        # Do not expose env/payload values through tracebacks, including malformed private JSON.
        print(f'Asset pipeline: {type(exc).__name__}; check input files and install requirements.txt.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
