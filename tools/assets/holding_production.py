"""Receipt-safe holding/pickup additions to the existing PixelLab character.

The carried prop is part of the authored pose, including hand overlap and
directional occlusion. Preserve the original export and use a separate v2 ZIP.
"""
from __future__ import annotations
import argparse
import json
import time
from character_production import DIRECTIONS, character_id, collect, folder, read, receipt, submit
from common import ROOT, PipelineError, load_env, write_json
from pixellab import encoded_image, request

IDOL = ('the small gold archaeological mask-shaped idol shown in the supplied images, '
        'with turquoise inset stones, a broad ornamental crown and a squat two-foot base')
LIGHT = ('a small brass and amber glass oil lantern with a dark U-shaped top handle, '
         'about 12 pixels tall')
COMMON = ('Face the supplied direction throughout. Keep the exact existing explorer, '
          'teal coat, boots, brown hair, backpack and native pixel art scale. Transparent '
          'background, no text, no effects, no turning, no canvas travel. Fingers and '
          'forearms visibly overlap and wrap around the carried object. Draw the actual '
          'object as part of the character pose in the same pixel style, never floating '
          'beside the hand. Preserve its size and shape throughout. ')
ACTIONS = {
    'relic_walk': (12, COMMON + 'A seamless careful walking loop while already holding ' + IDOL +
        ' in front of the waist. Both palms support the base from underneath, fingers curl '
        'around its sides, elbows bent, forearms tilted upward toward its weight. The idol '
        'is visible above the hands, in front of front-facing torso and partially behind '
        'the torso in back views. Alternating planted boots, bent knees, short deliberate '
        'steps, subtle one-pixel shared rise/fall of shoulders, hands and idol. Begin and '
        'end holding it; no reaching to take it, no lowered empty arms, no prop changes.'),
    'lantern_walk': (12, COMMON + 'A seamless relaxed walking loop while already holding ' + LIGHT +
        ' in the right hand by its top handle, beside the thigh. The knuckles cover the '
        'handle where it passes through the curled fingers; the lantern body hangs below '
        'the fist. The left arm swings naturally. Alternating heel contacts and knee bends, '
        'a tiny weight-responsive lantern swing from the wrist. In back views the '
        'lantern is beside the coat with the far arm occluded. Never hold it at chest '
        'height or by its glass. No reach-to-take lead-in.'),
    'dual_walk': (12, COMMON + 'A seamless slow walking loop carrying two objects: ' + IDOL +
        ' cradled against the left ribs in the left forearm, the left palm supporting '
        'its base, and ' + LIGHT + ' hanging from its top handle in the right fist beside '
        'the right thigh. Both objects touch their own hands; no floating, no extra hands. '
        'Alternating short careful grounded steps, small shoulder weight shifts, slight '
        'lantern swing. Begin and end already carrying both objects.'),
    'pickup_relic': (16, COMMON + 'One-shot pick-up of ' + IDOL + ' from the ground directly '
        'in front of the boots. Start standing empty-handed with the idol on the floor. '
        'Bend both knees and hinge the torso forward into a low squat, lower the head '
        'and shoulders visibly, reach both arms down. Both hands contact the sides of '
        'the base at the lowest crouch. After contact lift the same idol together with '
        'the hands, straighten the legs and back smoothly. End fully standing with both '
        'palms supporting its base in front of the waist. Feet stay planted throughout. '
        'Do not loop or return it to the floor; no vanishing or teleporting object.'),
    'pickup_lantern': (16, COMMON + 'One-shot pick-up of ' + LIGHT + ' from the floor directly '
        'in front of the boots. Start upright empty-handed, lantern resting on the '
        'ground. Bend the knees and hinge the back into a low forward crouch, head and '
        'shoulders descend, reach the right arm down and curl fingers around the top '
        'handle. At the lowest crouch the fist grips the handle. Lift the lantern only '
        'after contact and straighten the knees/back smoothly. End standing with '
        'lantern hanging by the handle in the right hand beside the thigh, left arm '
        'relaxed. Feet planted, no loop, no disappearing prop, no taking from backpack.'),
    'pickup_relic_light': (16, COMMON + 'One-shot pickup while already carrying ' + LIGHT +
        ' by its handle in the RIGHT hand. Keep this lantern visibly hanging from the '
        'same right fist throughout. A single ' + IDOL + ' rests on the ground in front '
        'of the boots. Bend knees and torso into a low forward crouch, extend the LEFT '
        'arm down, grip the idol base with the left palm, lift it only after contact. '
        'Straighten into a standing pose cradling the idol against the left ribs in '
        'the left forearm, left palm underneath; lantern still hanging from right '
        'hand beside right thigh. Planted feet, exactly two hands and two objects, '
        'no loop, no disappearing objects, no swapping hands.'),
    'pickup_lantern_relic': (16, COMMON + 'One-shot pickup while already cradling ' + IDOL +
        ' against the LEFT ribs with the left forearm and palm underneath its base. '
        'Keep this one idol touching the left hand throughout. A single ' + LIGHT +
        ' rests on the floor in front of the boots. Bend knees and torso into a low '
        'forward crouch; reach the RIGHT hand down and grip its top handle. Lift '
        'the lantern only after the right fist contacts the handle. Straighten to '
        'standing with idol cradled in left forearm and lantern hanging by handle '
        'from right fist beside thigh. Planted feet, exactly two hands and two '
        'objects, no loop, no disappearing or swapping objects.'),
}


def stage(action):
    return 'holding-v2-' + action


def animate(action,direction=None):
    count, prompt = ACTIONS[action]
    if action.startswith('pickup_'):
        group = None
        for angle in DIRECTIONS:
            kind=stage(action)+'-'+angle
            if receipt(kind).exists() and read(kind).get('state')!='rate_limited':
                data=read(kind)
                response=data.get('response',{})
                if not response.get('animation_group_id') or len(response.get('background_job_ids',[]))!=1:
                    raise PipelineError('Pickup outcome is unknown; inspect its receipt/dashboard before any further paid submission.')
                group=response['animation_group_id']
                if angle==direction: print('Accepted pickup already has a receipt; use status.');return
                continue
            if direction and angle!=direction: continue
            source=ROOT/'.asset-work/characters/explorer-holding-v2/pickup-inputs'
            payload={'character_id':character_id(),'animation_name':action,'mode':'v3',
                'action_description':prompt,'directions':[angle],'frame_count':count,
                'custom_start_frame':encoded_image(source/(action+'-'+angle+'-start.png'),256)[0],
                'end_frame':encoded_image(source/(action+'-'+angle+'-end.png'),256)[0],
                'keep_first_frame':False,'enhance_prompt':False,'seed':20261008+list(ACTIONS).index(action)}
            if group:payload['animation_group_id']=group
            submit(kind,'/animate-character',payload)
            group=read(kind).get('response',{}).get('animation_group_id')
            if not group:raise PipelineError('Missing animation group; inspect receipt, do not resubmit.')
        return
    submit(stage(action), '/animate-character', {'character_id': character_id(),
        'animation_name': action, 'mode': 'v3', 'action_description': prompt,
        'directions': DIRECTIONS, 'frame_count': count, 'keep_first_frame': False,
        'enhance_prompt': False, 'seed': 20261008 + list(ACTIONS).index(action)})


def status():
    for path in sorted(folder().glob('holding-v2-*.json')):
        data = json.loads(path.read_text())
        statuses = []
        for job in data.get('response', {}).get('background_job_ids', []):
            result = request('GET', '/background-jobs/' + job)
            write_json(folder() / 'jobs' / (job + '.json'), result)
            statuses.append(result.get('status'))
        print(data['kind'], statuses, flush=True)
        if len(statuses) == len(data['payload']['directions']) and all(s == 'completed' for s in statuses):
            data['state'] = 'completed'
            write_json(path, data)


def produce_pickups():
    for action in ACTIONS:
        if not action.startswith('pickup_'):continue
        while True:
            try:
                animate(action)
                break
            except PipelineError as error:
                if not str(error).startswith('PixelLab HTTP 429.'):raise
                print('Provider concurrency limit; accepted jobs are retained, retrying only the rejected request.',flush=True)
                time.sleep(30)
        last=-1
        while True:
            completed=0
            for direction in DIRECTIONS:
                data=read(stage(action)+'-'+direction)
                jobs=data.get('response',{}).get('background_job_ids',[])
                if len(jobs)!=1:raise PipelineError('Unknown submission outcome; inspect receipt, no paid retry.')
                result=request('GET','/background-jobs/'+jobs[0])
                write_json(folder()/'jobs'/(jobs[0]+'.json'),result)
                if result.get('status') in ('failed','cancelled','canceled'):
                    raise PipelineError('Accepted pickup job failed; inspect, do not resubmit.')
                if result.get('status')=='completed':
                    completed+=1
                    data['state']='completed'
                    write_json(receipt(stage(action)+'-'+direction),data)
            if completed!=last:
                print(action+': '+str(completed)+'/8 directions complete.',flush=True);last=completed
            if completed==8:break
            time.sleep(20)
    collect(ROOT/'.asset-work/characters/explorer-holding-v2')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['animate', 'status', 'collect','produce-pickups'])
    parser.add_argument('--action', choices=list(ACTIONS))
    parser.add_argument('--direction',choices=DIRECTIONS)
    args = parser.parse_args()
    load_env()
    if args.mode == 'animate':
        if not args.action: parser.error('animate requires --action')
        animate(args.action,args.direction)
    elif args.mode == 'status': status()
    elif args.mode == 'produce-pickups':produce_pickups()
    else: collect(ROOT / '.asset-work/characters/explorer-holding-v2')


if __name__ == '__main__':
    try: main()
    except PipelineError as error: raise SystemExit(str(error))
