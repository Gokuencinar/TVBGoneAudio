#!/usr/bin/env python3
"""Generate the primary iOS app icon for IR Universal.

Uses only the Python standard library plus macOS `sips` for resizing, so the
GitHub Actions runner does not need Pillow or ImageMagick.
"""
from __future__ import annotations
import json, math, os, struct, subprocess, zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "Sources" / "Assets.xcassets"
SIZE = 1024

ICON_SETS = {
    "AppIcon": "power",
}
PREVIEWS = {}
SPECS = [
    ("20x20", "2x", 40), ("20x20", "3x", 60),
    ("29x29", "2x", 58), ("29x29", "3x", 87),
    ("40x40", "2x", 80), ("40x40", "3x", 120),
    ("60x60", "2x", 120), ("60x60", "3x", 180),
    ("1024x1024", "1x", 1024),
]

def clamp(v, lo=0.0, hi=1.0): return lo if v < lo else hi if v > hi else v

def mix(a, b, t): return a + (b-a)*t

def blend(base, over, a):
    a = clamp(a)
    return tuple(int(mix(base[i], over[i], a)) for i in range(3))

def line_dist(x, y, x1, y1, x2, y2):
    vx, vy = x2-x1, y2-y1
    wx, wy = x-x1, y-y1
    vv = vx*vx + vy*vy
    if vv == 0: return math.hypot(wx, wy)
    t = clamp((wx*vx + wy*vy)/vv)
    return math.hypot(x-(x1+t*vx), y-(y1+t*vy))

def rounded_rect_sdf(x, y, cx, cy, hw, hh, r):
    qx = abs(x-cx)-hw+r
    qy = abs(y-cy)-hh+r
    ox = max(qx,0); oy=max(qy,0)
    return math.hypot(ox,oy)+min(max(qx,qy),0)-r

def ring_alpha(d, radius, thickness, feather=0.004):
    e = abs(d-radius)-thickness/2
    return clamp(0.5 - e/feather)

def stroke_alpha(d, thickness, feather=0.004):
    return clamp(0.5 - (d-thickness/2)/feather)

def arc_alpha(x,y,cx,cy,r,thick, top=True):
    if top and y > cy: return 0.0
    if not top and y < cy: return 0.0
    return ring_alpha(math.hypot(x-cx,y-cy), r, thick)

def shade(style, x, y):
    dx, dy = x-.5, y-.52
    glow = clamp(1-math.hypot(dx,dy)/.75)
    if style == "remote":
        base = (4,14,34); bg2=(5,36,82)
    elif style == "led":
        base = (6,3,9); bg2=(36,2,12)
    else:
        base = (7,9,14); bg2=(25,15,24)
    c = tuple(int(mix(base[i],bg2[i],glow*.45)) for i in range(3))

    def paint(col, a):
        nonlocal c
        c = blend(c,col,a)

    if style in ("power","gradient"):
        pd = abs(math.hypot(x-.5,y-.635)-.225)
        paint((120,0,12), clamp(1-pd/.12)*.34)
        ang = math.atan2(y-.635,x-.5)
        a = ring_alpha(math.hypot(x-.5,y-.635), .225, .055)
        if -2.08 < ang < -1.06: a = 0
        col = (255,45,45) if style=="power" else (255,45+int(75*(1-y)),65)
        paint(col,a)
        d = line_dist(x,y,.5,.265,.5,.565)
        paint((255,70,45) if style=="power" else (255,80,32), stroke_alpha(d,.055))
        for r, th, k in ((.105,.038,1.0),(.175,.042,.9),(.245,.046,.8)):
            a = arc_alpha(x,y,.5,.355,r,th,top=True)
            wave = (255,95,42) if style=="power" else (255,75,35)
            paint(wave,a*k)
    elif style == "remote":
        for r, th in ((.11,.035),(.18,.04),(.25,.045)):
            paint((40,210,255),arc_alpha(x,y,.5,.31,r,th,top=True))
        sdf = rounded_rect_sdf(x,y,.5,.64,.145,.285,.055)
        bodya = clamp(.5-sdf/.004)
        paint((235,242,250),bodya)
        paint((14,47,85), ring_alpha(math.hypot(x-.5,y-.535),.062,.026))
        paint((18,64,105), clamp(1-math.hypot(x-.5,y-.535)/.025))
        paint((10,45,84), clamp(1-math.hypot(x-.5,y-.405)/.018))
        for yy in (.65,.705,.76):
            for xx in (.445,.5,.555):
                paint((15,44,78), clamp(1-math.hypot(x-xx,y-yy)/.015))
    elif style == "led":
        for r, th in ((.12,.032),(.20,.038),(.28,.042)):
            paint((255,20,65),arc_alpha(x,y,.5,.35,r,th,top=True))
        dome = math.hypot((x-.5)/.09,(y-.61)/.13)
        if y < .64:
            paint((245,20,55), clamp(1-dome)*.92)
        sdf = rounded_rect_sdf(x,y,.5,.675,.10,.13,.025)
        paint((210,14,48), clamp(.5-sdf/.004)*.84)
        paint((255,225,235), clamp(1-math.hypot(x-.5,y-.60)/.035))
        paint((210,185,190), stroke_alpha(line_dist(x,y,.465,.78,.455,.93),.018))
        paint((210,185,190), stroke_alpha(line_dist(x,y,.535,.78,.55,.93),.018))
    return (*c,255)

def write_png(path: Path, style: str):
    raw = bytearray()
    n = SIZE
    for j in range(n):
        raw.append(0)
        y=(j+.5)/n
        for i in range(n):
            x=(i+.5)/n
            raw.extend(shade(style,x,y))
    def chunk(tag,data):
        return struct.pack(">I",len(data))+tag+data+struct.pack(">I",zlib.crc32(tag+data)&0xffffffff)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR",struct.pack(">IIBBBBB",n,n,8,6,0,0,0))
    png += chunk(b"IDAT",zlib.compress(bytes(raw),9))
    png += chunk(b"IEND",b"")
    path.write_bytes(png)

def resize(master: Path, out: Path, size: int):
    if size == SIZE:
        if out != master: out.write_bytes(master.read_bytes())
        return
    subprocess.run(["sips","-z",str(size),str(size),str(master),"--out",str(out)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def main():
    CATALOG.mkdir(parents=True,exist_ok=True)
    (CATALOG/"Contents.json").write_text(json.dumps({"info":{"author":"xcode","version":1}},indent=2)+"\n")
    masters={}
    for set_name,style in ICON_SETS.items():
        d=CATALOG/f"{set_name}.appiconset"; d.mkdir(parents=True,exist_ok=True)
        master=d/f"{set_name}-1024.png"
        write_png(master,style); masters[set_name]=master
        images=[]
        for size_text,scale,px in SPECS:
            fn=f"{set_name}-{px}.png"; out=d/fn; resize(master,out,px)
            images.append({"idiom":"ios-marketing" if px==1024 else "iphone","size":size_text,"scale":scale,"filename":fn})
        (d/"Contents.json").write_text(json.dumps({"images":images,"info":{"author":"xcode","version":1}},indent=2)+"\n")
    for image_name,set_name in PREVIEWS.items():
        d=CATALOG/f"{image_name}.imageset"; d.mkdir(parents=True,exist_ok=True)
        fn=f"{image_name}.png"; resize(masters[set_name],d/fn,256)
        data={"images":[{"idiom":"universal","filename":fn,"scale":"1x"}],"info":{"author":"xcode","version":1}}
        (d/"Contents.json").write_text(json.dumps(data,indent=2)+"\n")
    print("Generated IR Universal primary app icon")

if __name__ == "__main__": main()
