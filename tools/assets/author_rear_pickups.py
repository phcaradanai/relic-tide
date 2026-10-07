"""Curate real PixelLab knee/lean poses for the three occluded rear views.

The rear v3 takes barely bent. These native raster frames use the explorer's
authored crouching poses, with the actual prop behind the torso and under its
fingers. No body scaling, drawn body, runtime prop overlay or paid request.
"""
from PIL import Image, ImageOps
from assemble_holding import WORK, align, exported_frames
from author_holding_refs import paint_grip
from common import ROOT, write_json

ACTIONS = {
    'pickup_relic': ('empty', 'relic'),
    'pickup_lantern': ('empty', 'lantern'),
    'pickup_relic_light': ('lantern', 'dual'),
    'pickup_lantern_relic': ('relic', 'dual'),
}


def gripping_pose(body, direction, depth, kind, props):
    # Positions follow the real hand pixels in each crouched source pose.
    if direction == 'north':
        left = (30, 50) if depth < 4 else (43, 64)
        right = (58, 50) if depth < 4 else (58, 62)
    else:
        right = {1: (56, 54), 2: (57, 57), 3: (60, 61), 4: (63, 64)}[depth]
        left = (36, right[1] - 3)
        if direction == 'north-west':
            left, right = (87-right[0], right[1]), (87-left[0], left[1])
    result = body.copy()
    for name, hand in [('relic', left), ('lantern', right)]:
        if name not in kind and kind != 'dual': continue
        prop = props[name]
        origin = (hand[0]-prop.width//2, hand[1]-prop.height if name == 'relic' else hand[1]-1)
        fingers = [(hand[0]-3,hand[1]-4,hand[0]+3,hand[1]+2)]
        result = paint_grip(result, prop, origin, fingers, True)
    return result


def main():
    target = WORK/'rear-pickups'
    target.mkdir(exist_ok=True)
    props = {name: Image.open(ROOT/'assets'/(name+'-grip-v2.png')).convert('RGBA') for name in ('relic','lantern')}
    review = {}
    # Knees change silhouette; the cape also pivots as weight moves forward.
    steps = {3:1,4:2,5:3,6:4,7:4,8:4,9:3,10:2,11:1}
    for direction in ('north', 'north-east', 'north-west'):
        source_dir = 'north-east' if direction == 'north-west' else direction
        crouches = [align(im,(88,88)) for im in exported_frames(WORK/'export','down',source_dir,8)]
        if direction == 'north-west': crouches = [ImageOps.mirror(im) for im in crouches]
        for action, (before, after) in ACTIONS.items():
            frames = [align(im,(88,88)) for im in exported_frames(WORK/'export',action,direction,16)]
            for phase, depth in steps.items():
                # The diagonal collapse's fourth frame overbalances. Its third
                # frame is the stable, bent-knee reach with a planted boot.
                if direction != 'north': depth = min(depth,3)
                # North's first knee poses stay upright. Keep the provider's
                # initial lean, then use its fully kneeling pose at contact.
                if direction == 'north' and depth < 4: continue
                kind = before if phase < 7 else after
                frames[phase] = gripping_pose(crouches[depth],direction,depth,kind,props)
            start = Image.open(WORK/'pickup-inputs'/(action+'-'+direction+'-start.png')).convert('RGBA')
            end = Image.open(WORK/'pickup-inputs'/(action+'-'+direction+'-end.png')).convert('RGBA')
            for phase in (0,1,2): frames[phase] = start.copy()
            for phase in (12,13,14,15): frames[phase] = end.copy()
            paths=[]
            for phase, image in enumerate(frames):
                path=action+'-'+direction+'-%02d.png'%phase
                image.save(target/path);paths.append(path)
            review[action+'_'+direction]=paths
    write_json(target/'review.json',review)
    print('Authored 12 rear pickup clips from actual PixelLab knee and lean poses.')


if __name__ == '__main__': main()
