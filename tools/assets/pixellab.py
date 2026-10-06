"""PixelLab public v2 endpoints, secret-safe errors and resumable jobs."""
from __future__ import annotations

import base64
import io
import json
import re
import time
from pathlib import Path

from common import (PipelineError, ROOT, read_image, reference, secret, sha256,
                    validate_name, work_root, write_json)
from sprites import sprite_bundle

API = 'https://api.pixellab.ai/v2'


def request(method: str, endpoint: str, payload=None) -> dict:
    import requests
    key = secret('PIXELLAB_API_KEY')
    try:
        response = requests.request(method, API + endpoint, json=payload,
            headers={'Authorization': f'Bearer {key}'}, timeout=(15, 300), allow_redirects=False)
    except requests.RequestException as exc:
        # Never echo exception URLs, headers, request data or server responses.
        raise PipelineError('PixelLab connection failed. A submitted job may exist; check the dashboard before retrying.') from exc
    if response.status_code not in (200, 201, 202):
        hints = {401: 'Check PIXELLAB_API_KEY.', 402: 'Check paid API credits.',
                 429: 'Rate limited; retry later.', 529: 'Rate limited; retry later.'}
        raise PipelineError(f'PixelLab HTTP {response.status_code}. ' + hints.get(response.status_code, 'Check the endpoint inputs.'))
    try:
        value = response.json()
    except ValueError as exc:
        raise PipelineError('PixelLab returned invalid JSON.') from exc
    if not isinstance(value, dict):
        raise PipelineError('PixelLab response must be an object.')
    return value


def encoded_image(path: Path, max_side: int) -> tuple[dict, tuple[int, int]]:
    image = read_image(path)
    if max(image.size) > max_side:
        raise PipelineError(f'Reference must be at native resolution, at most {max_side}px; prepare it in Aseprite.')
    buffer = io.BytesIO()
    image.save(buffer, format='PNG')
    return {'type': 'base64', 'format': 'png', 'base64': base64.b64encode(buffer.getvalue()).decode()}, image.size


def decode_frames(response: dict) -> list:
    from PIL import Image
    value = response.get('last_response') or response
    images = value.get('images')
    if images is None:
        images = [value['image']] if 'image' in value else []
    if not isinstance(images, list) or not images:
        raise PipelineError('PixelLab completed without inline image/images; check the current API schema.')
    result = []
    try:
        for entry in images:
            encoded = entry['base64'] if isinstance(entry, dict) else entry
            if encoded.startswith('data:'):
                encoded = encoded.split(',', 1)[1]
            raw = base64.b64decode(encoded, validate=True)
            with Image.open(io.BytesIO(raw)) as frame:
                frame.load()
                result.append(frame.convert('RGBA'))
    except (KeyError, TypeError, ValueError, OSError) as exc:
        raise PipelineError('PixelLab returned an invalid inline image.') from exc
    return result


def poll_job(job_id: str, wait: float, *, fetch=request, clock=time.monotonic, sleep=time.sleep) -> dict:
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', job_id):
        raise PipelineError('Invalid PixelLab job id.')
    deadline = clock() + wait
    while True:
        value = fetch('GET', '/background-jobs/' + job_id)
        status = value.get('status')
        if status == 'completed':
            return value
        if status in ('failed', 'cancelled', 'canceled'):
            raise PipelineError('PixelLab job failed; inspect it privately in the dashboard.')
        if clock() >= deadline:
            raise PipelineError('PixelLab job still processing. Resume with pixellab poll --name; do not submit again.')
        sleep(min(5, max(0, deadline-clock())))


def receipt_path(name: str) -> Path:
    validate_name(name)
    return work_root() / 'jobs' / (name + '.json')


def finish(receipt: dict, response: dict, *, accept_returned_frames: bool = False) -> Path:
    frames = decode_frames(response)
    if receipt.get('kind') == 'sprite':
        variant = receipt.get('variant', 0)
        if not 0 <= variant < len(frames):
            raise PipelineError('Requested variant is outside the returned candidate range.')
        frames = [frames[variant]]
    expected = receipt.get('expected_frames')
    if expected is not None and len(frames) != expected and not accept_returned_frames:
        raise PipelineError('PixelLab frame count differs from the requested count; keep the receipt and inspect results.')
    provenance = {**receipt['provenance'], 'job_id': receipt.get('job_id'),
                  'usage': response.get('usage') or (response.get('last_response') or {}).get('usage')}
    if expected is not None:
        provenance.update(requested_frame_count=expected, returned_frame_count=len(frames),
                          reviewed_frame_count_override=expected != len(frames))
    return sprite_bundle(receipt['name'], frames, animation=receipt['animation'],
        fps=receipt['fps'], filtering=receipt['filter'], provenance=provenance)


def submit(args) -> Path | None:
    validate_name(args.name)
    validate_name(args.animation)
    if args.seed < 0 or args.wait < 0:
        raise PipelineError('Seed and wait must be nonnegative.')
    if args.fps <= 0:
        raise PipelineError('Frame rate must be positive.')
    receipt_file = receipt_path(args.name)
    if receipt_file.exists() or (ROOT / 'assets/generated/sprites' / args.name).exists():
        raise PipelineError('This asset name already has a receipt or output. Poll it or use a new versioned name.')
    provenance = {'provider': 'pixellab', 'seed': args.seed}
    if args.mode == 'animation':
        if args.frames not in range(4, 17, 2) or not args.action.strip() or len(args.action) > 1000:
            raise PipelineError('Animation needs a 1–1000 character action and an even frame count from 4–16.')
        path = Path(args.source)
        encoded, size = encoded_image(path, 256)
        if size[0] * size[1] * args.frames > 524288:
            raise PipelineError('Animation exceeds the 524288 pixel budget.')
        endpoint = '/animate-with-text-v3'
        payload = {'first_frame': encoded, 'action': args.action, 'frame_count': args.frames,
                   'no_background': True, 'seed': args.seed, 'enhance_prompt': False}
        provenance.update(source=reference(path), source_sha256=sha256(path), prompt=args.action)
    else:
        description = Path(args.prompt_file).read_text().strip()
        if not description or len(description) > 2000:
            raise PipelineError('Prompt file must contain 1–2000 characters.')
        payload = {'description': description, 'no_background': True, 'seed': args.seed}
        provenance['prompt'] = description
        if args.style_image:
            path = Path(args.style_image)
            encoded, size = encoded_image(path, 512)
            payload['style_images'] = [{'image': encoded, 'width': size[0], 'height': size[1]}]
            endpoint = '/generate-with-style-v2'
            provenance.update(style_source=reference(path), style_sha256=sha256(path))
        else:
            width, height = args.width, args.height
            if (min(width, height) < 16 or max(width, height) > 768 or width % 4 or height % 4
                    or width*height > 512*512 or (min(width, height) < 32 and width != height)):
                raise PipelineError('Pixen dimensions must match its documented size and pixel budget limits.')
            endpoint = '/create-image-pixen'
            payload.update(image_size={'width': width, 'height': height}, view='high top-down',
                           direction=args.direction, enhance_prompt=False)
    secret('PIXELLAB_API_KEY')  # Validate before reserving the name.
    receipt = {'name': args.name, 'endpoint': endpoint, 'animation': args.animation,
        'fps': args.fps, 'filter': args.filter, 'provenance': provenance,
        'expected_frames': args.frames if args.mode == 'animation' else None,
        'state': 'submitting', 'kind': args.mode, 'variant': getattr(args, 'variant', 0)}
    # A marker survives ambiguous network failure. Never automatically retry a paid POST.
    write_json(receipt_file, receipt)
    response = request('POST', endpoint, payload)
    if response.get('background_job_id'):
        receipt.update(job_id=response['background_job_id'], state='processing')
        write_json(receipt_file, receipt)
        print(f'Job receipt saved for {args.name}. Resume: pixellab poll --name {args.name}')
        if args.wait == 0:
            return None
        response = poll_job(receipt['job_id'], args.wait)
    output = finish(receipt, response)
    receipt['state'] = 'imported'
    write_json(receipt_file, receipt)
    return output


def resume(args) -> Path:
    if args.wait < 0:
        raise PipelineError('Wait must be nonnegative.')
    path = receipt_path(args.name)
    if not path.exists():
        raise PipelineError('No receipt for this name.')
    receipt = json.loads(path.read_text())
    job_id = args.job_id or receipt.get('job_id')
    if not job_id:
        raise PipelineError('Submission outcome is unknown. Check the dashboard, then poll with --job-id; do not submit again.')
    if receipt.get('state') == 'imported':
        raise PipelineError('This job was already imported; use its existing resource.')
    response = poll_job(job_id, args.wait)
    receipt['job_id'] = job_id
    result = finish(receipt, response, accept_returned_frames=getattr(args, 'accept_returned_frames', False))
    receipt['state'] = 'imported'
    write_json(path, receipt)
    return result
