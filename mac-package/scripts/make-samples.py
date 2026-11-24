#!/usr/bin/env python3
"""Makes squeezed sample photos from ordinary ones.

    make-samples.py <originals-dir> <output-dir> [factor]

Each image in originals-dir is squeezed horizontally by 1/factor (default 1.5),
as an anamorphic lens would have recorded it. Use your own photographs.
Needs Pillow.
"""
import sys
from pathlib import Path
from PIL import Image

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
factor = float(sys.argv[3]) if len(sys.argv) > 3 else 1.5
dst.mkdir(parents=True, exist_ok=True)
count = 0
for p in sorted(src.iterdir()):
    if p.suffix.lower() not in {".jpg", ".jpeg", ".png", ".tif", ".tiff"}:
        continue
    try:
        im = Image.open(p).convert("RGB")
    except Exception as e:
        print("skip", p.name, e)
        continue
    im.resize((max(1, round(im.width / factor)), im.height), Image.LANCZOS).save(dst / f"{p.stem}_sq{factor:g}.jpg", quality=92)
    count += 1
print(f"wrote {count} squeezed samples to {dst}")
