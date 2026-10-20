"""Render fixture-exported Lua widget geometry; not an in-game screenshot.

Requires Pillow only for this optional developer preview. Fonts and item icons
are simulated; coordinates, text, colors and rounded masks come from the addon.
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def render(source, target, font_path):
    data=json.loads(Path(source).read_text())
    objects={o['id']:o for o in data['objects']}
    root=objects[data['root']]
    geometry={root['id']:(0,0,root['width'],root['height'])}
    def rect(o):
        if o['id'] in geometry:
            return geometry[o['id']]
        parent=objects.get(o.get('parent'))
        if not parent:
            return (0,0,0,0)
        px,py,pw,ph=rect(parent)
        width=o.get('width',0);height=o.get('height',o.get('fontSize',12)+4)
        if o.get('allPoints'):
            result=(px,py,pw,ph)
        else:
            points=o.get('points') or [['TOPLEFT',0,0]]
            first=points[0]
            point,dx,dy=first
            if len(points)>1 and point=='TOPLEFT' and points[1][0]=='BOTTOMRIGHT':
                width=pw+points[1][1]-dx;height=ph-points[1][2]+dy
            x=px+dx;y=py-dy
            if 'RIGHT' in point:
                x=px+pw+dx-width
            if 'BOTTOM' in point:
                y=py+ph-dy-height
            result=(x,y,width,height)
        geometry[o['id']]=result
        return result
    def visible(o):
        if not o.get('shown',True):return False
        if o['id']==root['id']:return True
        parent=objects.get(o.get('parent'))
        return bool(parent) and visible(parent)
    def clip(o):
        parent=objects.get(o.get('parent'))
        if parent and parent.get('kind')=='ScrollFrame':return rect(parent)
        return clip(parent) if parent and parent['id']!=root['id'] else (0,0,root['width'],root['height'])
    def color(o,default=(.9,.92,.95,1)):
        return tuple(round(v*255) for v in o.get('color',default))
    def alpha(o):
        parent=objects.get(o.get('parent'))
        return o.get('alpha',1)*(alpha(parent) if parent and parent['id']!=root['id'] else 1)
    image=Image.new('RGBA',(root['width'],root['height']),(10,11,15,255))
    def depth(o):
        parent=objects.get(o.get('parent'))
        return 0 if o['id']==root['id'] or not parent else depth(parent)+1
    # Draw each frame's background before its descendants. Real game textures
    # and fonts are replaced only in this renderer, never in the Lua UI.
    children={}
    for o in objects.values():children.setdefault(o.get('parent'),[]).append(o)
    def draw(o):
        if not visible(o):return
        layer=Image.new('RGBA',image.size)
        canvas=ImageDraw.Draw(layer)
        x,y,w,h=map(round,rect(o))
        if o['kind']=='Texture' and w>0 and h>0:
            texture=str(o.get('texture',''))
            name=texture.split('\\')[-1]
            if name in ('Round','Border'):
                path=ROOT/'UI/Media'/f'{name}.tga'
                tile=Image.open(path).convert('RGBA')
                uv=o.get('uv',[0,1,0,1]);u0,u1,v0,v1=uv
                tw,th=tile.size
                tile=tile.crop((round(u0*tw),round(v0*th),round(u1*tw),round(v1*th))).resize((w,h))
                ink=Image.new('RGBA',(w,h),color(o));ink.putalpha(tile.getchannel('A'))
                layer.alpha_composite(ink,(x,y))
            else:
                canvas.rounded_rectangle((x,y,x+w,y+h),radius=3,fill=(70,85,108,255))
                canvas.line((x+w*.25,y+h*.7,x+w*.65,y+h*.25,x+w*.78,y+h*.35),fill=(190,205,225),width=2)
        elif o['kind']=='CheckButton':
            canvas.rounded_rectangle((x+3,y+3,x+w-3,y+h-3),radius=3,fill=(25,27,34),outline=(70,74,88))
            if o.get('checked'):
                canvas.line((x+7,y+13,x+11,y+17,x+19,y+8),fill=(236,238,244),width=2)
        elif o['kind'] in ('FontString','EditBox') and o.get('text'):
            font=ImageFont.truetype(str(font_path),o.get('fontSize',12))
            text=str(o['text']);ink=color(o)
            while canvas.textlength(text,font=font)>w and len(text)>1:text=text[:-2]+'…'
            tw=canvas.textlength(text,font=font)
            if o.get('align')=='RIGHT':x+=w-tw
            elif o.get('align')=='CENTER':x+=(w-tw)/2
            canvas.text((x,y),text,font=font,fill=ink,anchor='lt')
        cx,cy,cw,ch=map(round,clip(o))
        cropped=Image.new('RGBA',image.size)
        cropped.paste(layer.crop((cx,cy,cx+cw,cy+ch)),(cx,cy))
        opacity=alpha(o)
        if opacity<1:cropped.putalpha(cropped.getchannel('A').point(lambda value:round(value*opacity)))
        image.alpha_composite(cropped)
        ordered=sorted(children.get(o['id'],[]),key=lambda c:({'BACKGROUND':0,'BORDER':1,'ARTWORK':2}.get(c.get('layer'),3),c['id']))
        for child in ordered:draw(child)
    draw(root)
    image.convert('RGB').save(target)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('snapshot');parser.add_argument('output');parser.add_argument('--font',required=True)
    args=parser.parse_args()
    render(args.snapshot,args.output,args.font)
