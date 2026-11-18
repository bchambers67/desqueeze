#!/usr/bin/env python3
"""Sets real captures on App Store canvases, with a caption above each.

    python3 compose.py            # every shot in shots.json that has a capture
    python3 compose.py ipad       # one device

A shot is a real screenshot or screen-recording frame of the app, kept in
captures/<device>/<name>.png. Nothing is drawn or mocked: the capture is
scaled to fit and placed as it is. Output goes to output/<device>/.
"""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
PINE, PAPER, HALIDE = (0x1C, 0x27, 0x23), (0xEC, 0xEA, 0xE1), (0xC7, 0xD9, 0xCE)
FONT = "/usr/share/fonts/opentype/inter/Inter-Medium.otf"

def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()

def wrap(draw, text, fnt, width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=fnt) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]

def compose(capture: Path, size, caption: str, out: Path):
    w, h = size
    canvas = Image.new("RGB", size, PINE)
    draw = ImageDraw.Draw(canvas)
    landscape = w > h
    pad = int(min(w, h) * 0.06)
    cap_size = int(min(w, h) * (0.052 if landscape else 0.058))
    fnt = font(cap_size)
    lines = wrap(draw, caption, fnt, w - pad * 2)
    y = pad
    for line in lines:
        draw.text((w / 2, y), line, font=fnt, fill=PAPER, anchor="ma")
        y += int(cap_size * 1.25)
    draw.rectangle([w / 2 - pad, y + pad // 3, w / 2 + pad, y + pad // 3 + 4], fill=HALIDE)
    top = y + pad

    shot = Image.open(capture).convert("RGB")
    room_w, room_h = w - pad * 2, h - top - pad
    scale = min(room_w / shot.width, room_h / shot.height)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)
    radius = round(min(shot.size) * 0.045)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *shot.size], radius, fill=255)
    canvas.paste(shot, ((w - shot.width) // 2, top + (room_h - shot.height) // 2), mask)
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, "PNG", optimize=True)

def main():
    spec = json.loads((HERE / "shots.json").read_text())
    only = sys.argv[1] if len(sys.argv) > 1 else None
    made, missing = 0, []
    for device, d in spec["devices"].items():
        if only and device != only:
            continue
        for i, shot in enumerate(d["shots"], 1):
            capture = HERE / "captures" / device / f"{shot['name']}.png"
            if not capture.exists():
                missing.append(f"{device}/{shot['name']}.png")
                continue
            compose(capture, tuple(d["size"]), shot["caption"], HERE / "output" / device / f"{i:02d}-{shot['name']}.png")
            made += 1
    print(f"made {made}")
    for m in missing:
        print("  needs capture:", m)

main()
