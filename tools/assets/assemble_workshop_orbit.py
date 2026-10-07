"""Pack the one approved DepthFlow render; no provider requests or new billing."""
from pathlib import Path
import json
from PIL import Image
from common import ROOT, run_local, sha256, work_root, write_json
from sprites import sprite_bundle

source = work_root() / 'previews/workshop-orbit-production-v1.mp4'
temp = work_root() / 'orbit-frames'
temp.mkdir(exist_ok=True)
# The returned motion repeats exactly every five seconds. Preserve one complete
# period, avoiding the discontinuity of looping the requested eight-second cut.
run_local(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(source),
           '-t', '5', '-vf', 'fps=12', str(temp / '%03d.png')])
frames = []
for path in sorted(temp.glob('*.png')):
    image = Image.open(path).convert('RGBA')
    padded = Image.new('RGBA', (402, 382))
    padded.paste(image, (1, 1))
    frames.append(padded)
assert len(frames) == 60
target = ROOT / 'assets/generated/sprites/workshop-orbit-v1'
if target.exists():
    prior = json.loads((target / 'manifest.json').read_text())
    if prior['provenance']['render_sha256'] != sha256(source):
        raise ValueError('Existing render differs; preserve it and use a new asset name.')
if not target.exists():
    target = sprite_bundle('workshop-orbit-v1', frames, animation='orbit', fps=12, filtering='linear',
        provenance={'provider': 'DepthFlow', 'source': 'assets/authored/workshop-reference-v1.png',
        'source_sha256': sha256(ROOT / 'assets/authored/workshop-reference-v1.png'),
        'render_sha256': sha256(source), 'request': 'tools/assets/examples/depthflow-orbit-production-v1.json',
        'billed_credits': 20, 'returned_duration': 8.066667, 'observed_loop_seconds': 5,
        'runtime_use': 'full lobby diorama; alpha-masked non-walkable Workshop faces in game'})
wall = Image.open(ROOT / 'assets/authored/ruin-wall-faces-v1.png').convert('RGBA')
mask = Image.new('RGBA', (402, 382))
mask.paste(wall.crop((630, 0, 1030, 380)), (1, 1))
mask.save(target / 'wall-mask.png')
# Replace the static version of these faces with the masked moving layer.
wall.paste((0, 0, 0, 0), (630, 0, 1030, 380))
wall.save(ROOT / 'assets/ruin-wall-faces-v1.png')
manifest = json.loads((target / 'manifest.json').read_text())
manifest['provenance'].update(wall_mask_sha256=sha256(target / 'wall-mask.png'),
    wall_master_sha256=sha256(ROOT / 'assets/authored/ruin-wall-faces-v1.png'),
    floor_exclusion='scripts/level_map.gd floors; alpha is zero on walkable floor')
write_json(target / 'manifest.json', manifest)
print('Packed 60-frame seamless Workshop Orbit; floor geometry remains static.')
