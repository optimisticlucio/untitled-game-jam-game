"""Packs the surgeon's Spine frame export into one sheet per animation for Godot.
   python3 pack_surgeon.py <frames dir> <out dir>"""
import json, os, sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
COLS = 8
anchors = json.load(open(os.path.join(src, "anchors.json")))
fw, fh = anchors["frame_size"]
cw, ch = (fw + 3) // 4 * 4, (fh + 3) // 4 * 4   # cells on 4 px blocks for VRAM compression
meta = {"frame_size": [fw, fh], "cell_size": [cw, ch], "columns": COLS, "fps": anchors["fps"], "animations": {}}
for name in anchors["animations"]:
    files = sorted(f for f in os.listdir(os.path.join(src, name)) if f.endswith(".png"))
    rows = (len(files) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * cw, rows * ch), (0, 0, 0, 0))
    for i, f in enumerate(files):
        im = Image.open(os.path.join(src, name, f)).convert("RGBA")
        assert im.size == (fw, fh), (f, im.size)
        sheet.paste(im, ((i % COLS) * cw, (i // COLS) * ch))
    path = os.path.join(out, f"surgeon_{name}.png")
    sheet.save(path, optimize=True)
    a = anchors["animations"][name]
    meta["animations"][name] = {"frames": len(files), "loop": a["loop"],
                                "hand": [fr["hand"] for fr in a["frames"]]}
    print(name, len(files), sheet.size, os.path.getsize(path) // 1024, "KB")
json.dump(meta, open(os.path.join(out, "surgeon_frames.json"), "w"), indent=1)
