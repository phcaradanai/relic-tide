"""Native raster authoring: source props under actual PixelLab fingers.

References stay at the character's native 88px canvas. No runtime item overlay,
drawn body, fake camera motion or additional paid request is used here.
"""
import json
from pathlib import Path
from PIL import Image, ImageFilter
from assemble_holding import WORK, align, exported_frames
from character_production import DIRECTIONS
from common import ROOT, write_json

# Reviewed native hand positions, with direction-dependent torso occlusion.
GRIPS = {
    'south': ((44,50),(30,52)), 'south-east': ((48,50),(35,54)),
    'east': ((48,50),(52,51)), 'north-east': ((58,50),(55,51)),
    'north': ((30,50),(58,50)), 'north-west': ((34,50),(35,52)),
    'west': ((34,50),(40,52)), 'south-west': ((39,50),(50,55)),
}
LEFT_ARMS = {'south':(46,34,58,57),'south-east':(44,34,60,57),
    'east':(34,34,45,55),'north-east':(49,34,64,56),
    'north':(24,34,36,57),'north-west':(28,34,41,57),
    'west':(31,33,48,55),'south-west':(40,34,56,56)}
CRADLE = {'south':(52,50),'south-east':(50,50),'east':(46,50),
    'north-east':(35,50),'north':(29,50),'north-west':(34,50),
    'west':(35,50),'south-west':(43,50)}


def prop_pixels(name,size):
    image = Image.open(ROOT / 'assets' / (name+'.png')).convert('RGBA')
    # The originals contain nearly transparent specks outside their silhouette.
    silhouette = image.getchannel('A').point(lambda a:255 if a>64 else 0)
    image = image.crop(silhouette.getbbox()).resize((size[0]-2,size[1]-2),Image.Resampling.LANCZOS)
    alpha = image.getchannel('A').point(lambda a:255 if a>=80 else 0)
    image = image.convert('RGB').quantize(colors=24).convert('RGBA')
    image.putalpha(alpha)
    padded=Image.new('RGBA',size)
    padded.alpha_composite(image,(1,1))
    outline=Image.new('RGBA',size,(18,15,20,255))
    outline.putalpha(padded.getchannel('A').filter(ImageFilter.MaxFilter(3)))
    outline.alpha_composite(padded)
    image=outline
    image.save(ROOT / 'assets' / (name+'-grip-v2.png'))
    return image


def paint_grip(body,prop,origin,fingers,rear):
    result = Image.new('RGBA',body.size)
    if rear:
        result.alpha_composite(prop,origin)
        result.alpha_composite(body)
    else:
        result.alpha_composite(body)
        result.alpha_composite(prop,origin)
    for box in fingers:
        result.alpha_composite(body.crop(box),box[:2])
    return result


def main():
    relic = prop_pixels('relic',(15,18))
    lantern = prop_pixels('lantern',(9,16))
    review = {kind:{} for kind in ('relic','lantern','dual')}
    refs = {}
    repairs = WORK / 'repairs'
    inputs = WORK / 'pickup-inputs'
    repairs.mkdir(exist_ok=True);inputs.mkdir(exist_ok=True)
    vectors = [(0,1),(-1,1),(-1,0),(-1,-1),(0,-1),(1,-1),(1,0),(1,1)]
    for direction,vector in zip(DIRECTIONS,vectors):
        empty = align(exported_frames(WORK/'export','idle',direction,8)[0],(88,88))
        supporting = align(exported_frames(WORK/'export','carry_walk',direction,12)[5],(88,88))
        supporting.paste(empty.crop((0,58,88,88)),(0,58))
        base,hand = GRIPS[direction]
        rear = direction in ('north','north-east','north-west')
        relic_origin = (base[0]-relic.width//2,base[1]-relic.height)
        light_origin = (hand[0]-lantern.width//2,hand[1]-1)
        relic_fingers = [(base[0]-4,base[1]-6,base[0]+4,base[1]+1)]
        if direction=='south':relic_fingers=[(34,39,41,46),(49,39,57,46)]
        light_fingers = [(hand[0]-3,hand[1]-4,hand[0]+3,hand[1]+3)]
        held_relic = paint_grip(supporting,relic,relic_origin,relic_fingers,rear)
        held_light = paint_grip(empty,lantern,light_origin,light_fingers,rear)
        dual_body=empty.copy()
        arm=(30,34,42,56) if direction=='north-east' else LEFT_ARMS[direction]
        # Replace the actual left forearm, including transparent pixels, so an
        # old lowered hand cannot remain as a third hand below the bent arm.
        dual_body.paste(supporting.crop(arm),arm[:2])
        single=CRADLE[direction]
        single_origin=(single[0]-relic.width//2,single[1]-relic.height)
        single_fingers=[(single[0]-4,single[1]-6,single[0]+4,single[1]+1)]
        held_dual=paint_grip(dual_body,relic,single_origin,single_fingers,rear)
        dual_hand=(55,52) if direction=='north-west' else hand
        dual_light=(dual_hand[0]-lantern.width//2,dual_hand[1]-1)
        dual_fingers=[(dual_hand[0]-3,dual_hand[1]-4,dual_hand[0]+3,dual_hand[1]+3)]
        held_dual=paint_grip(held_dual,lantern,dual_light,dual_fingers,rear)
        refs[direction] = {'relic':held_relic,'lantern':held_light,'dual':held_dual,'empty':empty}
        for kind,image in [('relic',held_relic),('lantern',held_light),('dual',held_dual)]:
            name=kind+'-'+direction+'.png';image.save(repairs/name)
            review[kind][direction]={'pose':5,'split':58,'repair':name,
                'extra': [[*(dual_light if kind=='dual' else light_origin),lantern.width,lantern.height]] if kind in ('lantern','dual') else [],
                'hand_grip':hand if kind=='lantern' else base}
        ground_base = (44+vector[0]*15,74+vector[1]*10)
        for action,prop,start_kind,end_kind in [
            ('pickup_relic',relic,'empty','relic'),('pickup_lantern',lantern,'empty','lantern'),
            ('pickup_relic_light',relic,'lantern','dual'),('pickup_lantern_relic',lantern,'relic','dual')]:
            start = refs[direction][start_kind].copy()
            ground = (ground_base[0]-prop.width//2,ground_base[1]-prop.height)
            if vector[1]<0:
                image=Image.new('RGBA',start.size);image.alpha_composite(prop,ground);image.alpha_composite(start);start=image
            else:start.alpha_composite(prop,ground)
            start.save(inputs/(action+'-'+direction+'-start.png'))
            refs[direction][end_kind].save(inputs/(action+'-'+direction+'-end.png'))
    write_json(WORK/'review.json',review)
    print('Authored 24 integrated grip references and 32 matched pickup start/end pairs.')


if __name__=='__main__':main()
