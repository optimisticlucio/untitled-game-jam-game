"""Packs one layer of the surgeon's Spine frame export into sheets for Godot.
   python3 pack_surgeon.py <frames dir> <out dir> [name] [scale]
name is the layer's file prefix (default "surgeon"): <name>_<anim>.png (more pages: _2, _3, ...)
and <name>_frames.json. The surgeon has two layers, drawn with a tool on his hand between them:
   python3 pack_surgeon.py .../frames_15fps_v18_back  assets/surgeon surgeon
   python3 pack_surgeon.py .../frames_15fps_v18_front assets/surgeon surgeon_front
Every frame is cut to the box that holds anything drawn in any frame of the layer (the fingers
layer is mostly empty), recorded as "crop" so the frames keep their full size in Godot.
The slow breathing loop (idle) keeps every STEP-th frame at a slower speed (same length), and no sheet is
bigger than MAX_SHEET on a side, so they stay light in memory and fit older phones.
scale (default 1) shrinks the frames; the Surgeon's pixel_size must grow by as much (both layers
use the same scale), so he stays the same size on screen."""
import json, os, re, sys
from PIL import Image

STEP = {"idle": 2}   # the snaps in impatient are fast, so it keeps every frame
MAX_SHEET = 2048

src, out = sys.argv[1], sys.argv[2]
name = sys.argv[3] if len(sys.argv) > 3 else "surgeon"
scale = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
anchors = json.load(open(os.path.join(src, "anchors.json")))
fw, fh = (round(v * scale) for v in anchors["frame_size"])
fps = anchors["fps"]

frames = {}
box = None
for anim in anchors["animations"]:
    files = sorted(f for f in os.listdir(os.path.join(src, anim)) if f.endswith(".png"))
    frames[anim] = [Image.open(os.path.join(src, anim, f)).convert("RGBA").resize((fw, fh), Image.LANCZOS)
                    for f in files]
    for im in frames[anim]:
        assert im.size == (fw, fh), (anim, im.size)
        b = im.getchannel("A").getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
# One transparent pixel around the drawing, then out to 4 px blocks for VRAM compression.
x0, y0 = max(box[0] - 1, 0), max(box[1] - 1, 0)
cw, ch = box[2] - x0 + 1, box[3] - y0 + 1
cw, ch = (cw + 3) // 4 * 4, (ch + 3) // 4 * 4
cols, rows = MAX_SHEET // cw, MAX_SHEET // ch

meta = {"frame_size": [fw, fh], "scale": scale, "crop": [x0, y0, cw, ch], "cell_size": [cw, ch], "columns": cols,
        "rows": rows, "fps": fps, "animations": {}}
old = re.compile(r"^%s_(%s)(_\d+)?\.png$" % (re.escape(name), "|".join(map(re.escape, frames))))
for f in [f for f in os.listdir(out) if old.match(f)]:
    os.remove(os.path.join(out, f))   # this layer's old sheets and pages
for anim, ims in frames.items():
    step = STEP.get(anim, 1)
    keep = list(range(0, len(ims), step))
    pages = (len(keep) + cols * rows - 1) // (cols * rows)
    for p in range(pages):
        page = keep[p * cols * rows:(p + 1) * cols * rows]
        used_cols = min(cols, len(page))
        sheet = Image.new("RGBA", (used_cols * cw, ((len(page) + cols - 1) // cols) * ch), (0, 0, 0, 0))
        for i, k in enumerate(page):
            sheet.paste(ims[k].crop((x0, y0, x0 + cw, y0 + ch)), ((i % cols) * cw, (i // cols) * ch))
        path = os.path.join(out, f"{name}_{anim}.png" if p == 0 else f"{name}_{anim}_{p + 1}.png")
        sheet.save(path, optimize=True)
        print(name, anim, "page", p + 1, len(page), sheet.size, os.path.getsize(path) // 1024, "KB")
    a = anchors["animations"][anim]
    meta["animations"][anim] = {"frames": len(keep), "pages": pages, "fps": fps / step, "loop": a["loop"],
                                "hand": [[v * scale for v in a["frames"][k]["hand"]] for k in keep]}
json.dump(meta, open(os.path.join(out, f"{name}_frames.json"), "w"), indent=1)
print(name, "crop", meta["crop"], "cells", cols, "x", rows, "per sheet")
