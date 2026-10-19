"""Packs one layer of the surgeon's Spine frame export into one sheet per animation for Godot.
   python3 pack_surgeon.py <frames dir> <out dir> [name]
name is the layer's file prefix (default "surgeon"): <name>_<anim>.png and <name>_frames.json.
The surgeon has two layers, drawn with a tool on his hand between them:
   python3 pack_surgeon.py .../frames_15fps_v18_back  assets/surgeon surgeon
   python3 pack_surgeon.py .../frames_15fps_v18_front assets/surgeon surgeon_front
Every frame is cut to the box that holds anything drawn in any frame of the layer (the fingers
layer is mostly empty), recorded as "crop" so the frames keep their full size in Godot."""
import json, os, sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
name = sys.argv[3] if len(sys.argv) > 3 else "surgeon"
COLS = 8
anchors = json.load(open(os.path.join(src, "anchors.json")))
fw, fh = anchors["frame_size"]

frames = {}
box = None
for anim in anchors["animations"]:
    files = sorted(f for f in os.listdir(os.path.join(src, anim)) if f.endswith(".png"))
    frames[anim] = [Image.open(os.path.join(src, anim, f)).convert("RGBA") for f in files]
    for im in frames[anim]:
        assert im.size == (fw, fh), (anim, im.size)
        b = im.getchannel("A").getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
# One transparent pixel around the drawing, then out to 4 px blocks for VRAM compression.
x0, y0 = max(box[0] - 1, 0), max(box[1] - 1, 0)
cw, ch = box[2] - x0 + 1, box[3] - y0 + 1
cw, ch = (cw + 3) // 4 * 4, (ch + 3) // 4 * 4

meta = {"frame_size": [fw, fh], "crop": [x0, y0, cw, ch], "cell_size": [cw, ch], "columns": COLS,
        "fps": anchors["fps"], "animations": {}}
for anim, ims in frames.items():
    rows = (len(ims) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * cw, rows * ch), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        sheet.paste(im.crop((x0, y0, x0 + cw, y0 + ch)), ((i % COLS) * cw, (i // COLS) * ch))
    path = os.path.join(out, f"{name}_{anim}.png")
    sheet.save(path, optimize=True)
    a = anchors["animations"][anim]
    meta["animations"][anim] = {"frames": len(ims), "loop": a["loop"], "hand": [f["hand"] for f in a["frames"]]}
    print(name, anim, len(ims), sheet.size, os.path.getsize(path) // 1024, "KB")
json.dump(meta, open(os.path.join(out, f"{name}_frames.json"), "w"), indent=1)
print(name, "crop", meta["crop"])
