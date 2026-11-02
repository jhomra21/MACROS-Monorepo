"""Viewport-color bounds and fixed-index comparisons, in 402x874 screen points."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent
FONT = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 17)

def bounds(path):
    im = Image.open(path).convert("RGB").resize((402, 874))
    px = im.load()
    rows = []
    for y in range(50, 850):
        best = (0, 0)
        start = None
        for x in range(402):
            rgb = px[x,y]
            match = 58 <= min(rgb) <= 98 and max(rgb) - min(rgb) <= 5
            if match and start is None:
                start = x
            if not match or x == 401:
                if start is not None and x - start > best[1] - best[0]:
                    best = (start, x)
                start = None
        rows.append((y, best))
    groups, group = [], []
    for y, span in rows:
        if span[1] - span[0] >= 40:
            group.append((y, span))
        else:
            if len(group) >= 50:
                groups.append(group)
            group = []
    if len(group) >= 50:
        groups.append(group)
    if not groups:
        return None
    g = max(groups, key=lambda g: sum(s[1]-s[0] for _,s in g))
    if sum(s[1]-s[0] for _,s in g) < 800:
        return None
    return [min(s[0] for _,s in g),g[0][0],max(s[1] for _,s in g),g[-1][0]+1]

def crop_comparison(before, after, bi, ai, title, filename):
    sheet=Image.new("RGB",(804,780),"#202020")
    d=ImageDraw.Draw(sheet)
    for col, name, index in [(0,before,bi),(1,after,ai)]:
        src = Image.open(OUT/f"{name}-frames/{index+1:03d}.png").convert("RGB").resize((402,874))
        sheet.paste(src.crop((0,110,402,850)),(col*402,40))
        d.text((col*402+10,10),f"{name} frame {index:03d}",font=FONT,fill="white")
    sheet.save(OUT/filename)

if __name__ == "__main__":
    names=["before-wide","first-fix-wide","candidate-wide","final-wide","final-compact","final-dashboard-camera"]
    info={}
    for name in names:
        files=sorted((OUT/(name+"-frames")).glob("*.png"))
        all_bounds=[bounds(path) for path in files]
        first=next((i for i,b in enumerate(all_bounds) if b),None)
        info[name]={"first_gray_frame":first,
                    "bounds_at_onset":[{"frame":i,"bounds":all_bounds[i]}
                                       for i in range(first,min(first+12,len(files)))] if first is not None else []}
        print(name,info[name])
    (OUT/"viewport-frame-bounds.json").write_text(json.dumps(info,indent=2)+"\n")
    for index in (29,30,31,32,33,34,35,36):
        crop_comparison("before-wide","final-wide",index,index,"",f"wide-same-frame-{index:03d}.png")
    for offset in range(4):
        bi=info["before-wide"]["first_gray_frame"]+offset
        ai=info["final-wide"]["first_gray_frame"]+offset
        crop_comparison("before-wide","final-wide",bi,ai,"",f"wide-onset-relative-{offset:02d}.png")
