"""
Chambers & Light — Desqueeze app icon generator.

Brand tokens are the authoritative :root values published at chambersandlight.com:

    --chamber        #16110F   warm near-black      ground
    --pine           #1C2723   deep green-black     lens body
    --paper          #ECEAE1   warm bone            highlight
    --halide         #C7D9CE   pale mint            glass / true-width frame
    --halide-deep    #98B1A3   sage                 secondary glass
    --grain          #6E665F   warm mid grey        texture
    --safelight      #E63E2D   darkroom red         accent, expansion axis

Concept: an anamorphic lens element, squeezed narrow, opening horizontally to
its true width. The safelight axis runs through it; the halide frame shows the
corrected extent. Liquid-glass rendering — frosted body, specular crescent,
refracted edge light.

Outputs all macOS @1x/@2x sizes into
AnamorphicDesqueeze/Assets.xcassets/AppIcon.appiconset/ and the Windows .ico into
DesqueezeWindows/Assets/.
"""

import os
from PIL import Image, ImageDraw, ImageFilter

# ── Output sizes (pt, scale) for a macOS app icon ────────────────────────────
SIZES = [
    (16, 1),  (16, 2),
    (32, 1),  (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

_ROOT = os.path.dirname(os.path.abspath(__file__))

OUTPUT_DIR = os.path.join(
    _ROOT, "AnamorphicDesqueeze/Assets.xcassets/AppIcon.appiconset"
)
os.makedirs(OUTPUT_DIR, exist_ok=True)

# The WPF app's .csproj declares <ApplicationIcon>Assets\icon.ico</ApplicationIcon>,
# so the same mark is emitted as a multi-resolution Windows icon.
WIN_ICON_DIR = os.path.join(_ROOT, "DesqueezeWindows/Assets")
WIN_ICON_SIZES = [16, 20, 24, 32, 48, 64, 128, 256]
os.makedirs(WIN_ICON_DIR, exist_ok=True)

# ── Brand palette ─────────────────────────────────────────────────────────────
CHAMBER      = (0x16, 0x11, 0x0F)
PINE         = (0x1C, 0x27, 0x23)
PAPER        = (0xEC, 0xEA, 0xE1)
HALIDE       = (0xC7, 0xD9, 0xCE)
HALIDE_DEEP  = (0x98, 0xB1, 0xA3)
GRAIN        = (0x6E, 0x66, 0x5F)
SAFELIGHT    = (0xE6, 0x3E, 0x2D)
SAFELIGHT_DP = (0xC2, 0x2E, 0x1F)


def make_icon(px: int) -> Image.Image:
    """Render one icon at `px` x `px` pixels."""
    # Supersample for clean curves, then downsample.
    SS = 4 if px <= 256 else 2
    S = px * SS

    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = S / 2, S / 2
    R = S * 0.46                      # disc radius

    # Small renditions drop everything but the essential idea — a squeezed
    # element on the safelight axis. The halide frame and its registration
    # marks only survive where there are pixels to resolve them.
    detail = px >= 64                 # flare, corner marks
    show_frame = px >= 48             # the true-width frame

    # ── 1. Chamber ground ────────────────────────────────────────────────────
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], fill=(*CHAMBER, 255))

    # Warm interior falloff toward pine at the rim. Many fine steps keep the
    # ramp smooth; too few and the disc bands visibly.
    steps = 160
    for i in range(steps, 0, -1):
        t = i / steps
        r = R * t
        col = tuple(
            int(PINE[c] + (CHAMBER[c] - PINE[c]) * (1 - t) ** 0.85)
            for c in range(3)
        )
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*col, 255))

    # ── 2. Halide frame — the corrected (true) width ──────────────────────────
    # A wide rectangle in pale mint marking where the image lands once opened.
    # Its half-width sets the shared extent used by the axis below, so the
    # frame edge and the axis ticks register exactly.
    fw, fh = R * 0.80, R * 0.45
    fr = max(1, int(S * 0.0085))
    frame = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    if show_frame:
        fd.rectangle([cx - fw, cy - fh, cx + fw, cy + fh],
                     outline=(*HALIDE_DEEP, 205), width=fr)
    # Corner registration marks, brighter than the frame itself.
    if detail:
        cm = R * 0.10
        for ox in (-1, 1):
            for oy in (-1, 1):
                px_, py_ = cx + ox * fw, cy + oy * fh
                fd.rectangle([min(px_, px_ - ox * cm), py_ - fr / 2,
                              max(px_, px_ - ox * cm), py_ + fr / 2],
                             fill=(*HALIDE, 235))
                fd.rectangle([px_ - fr / 2, min(py_, py_ - oy * cm * 0.7),
                              px_ + fr / 2, max(py_, py_ - oy * cm * 0.7)],
                             fill=(*HALIDE, 235))
    img = Image.alpha_composite(img, frame)
    draw = ImageDraw.Draw(img)

    # ── 3. Safelight expansion axis ──────────────────────────────────────────
    # The horizontal line the correction acts along; ticks land on the frame
    # edge to show the squeezed element opening to exactly that width.
    axis = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ad = ImageDraw.Draw(axis)
    # The axis carries the whole idea at small sizes, so it thickens as the
    # frame drops away.
    ah = max(1, S * (0.005 if show_frame else 0.010))
    ad.rectangle([cx - fw, cy - ah, cx + fw, cy + ah], fill=(*SAFELIGHT, 225))
    tick = S * (0.030 if show_frame else 0.055)
    for sx in (cx - fw, cx + fw):
        ad.rectangle([sx - ah * 1.2, cy - tick, sx + ah * 1.2, cy + tick],
                     fill=(*SAFELIGHT, 255))
    img = Image.alpha_composite(img, axis)
    draw = ImageDraw.Draw(img)

    # ── 4. Squeezed lens element ─────────────────────────────────────────────
    # Tall narrow ellipse — the anamorphic image before correction.
    lw, lh = (R * 0.24, R * 0.56) if show_frame else (R * 0.30, R * 0.68)
    lens = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lens)

    ld.ellipse([cx - lw, cy - lh, cx + lw, cy + lh], fill=(*PINE, 252))
    # Inner glass, cooler and lighter toward the centre.
    ld.ellipse([cx - lw * 0.70, cy - lh * 0.76, cx + lw * 0.70, cy + lh * 0.76],
               fill=(*HALIDE_DEEP, 46))
    lens = lens.filter(ImageFilter.GaussianBlur(S * 0.0012))
    img = Image.alpha_composite(img, lens)
    draw = ImageDraw.Draw(img)

    # Halide rim on the element.
    draw.ellipse([cx - lw, cy - lh, cx + lw, cy + lh],
                 outline=(*HALIDE, 225), width=max(1, int(S * 0.007)))

    # ── 5. Anamorphic flare ──────────────────────────────────────────────────
    # The horizontal streak that only anamorphic glass produces.
    if detail:
        fl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        fld = ImageDraw.Draw(fl)
        fy = cy + lh * 0.05
        fld.ellipse([cx - lw * 0.80, fy - S * 0.010,
                     cx + lw * 0.80, fy + S * 0.010],
                    fill=(*PAPER, 200))
        fl = fl.filter(ImageFilter.GaussianBlur(S * 0.007))
        img = Image.alpha_composite(img, fl)
        draw = ImageDraw.Draw(img)

    # ── 6. Liquid-glass specular crescent ────────────────────────────────────
    # Clipped to the disc so it reads as light *in* the glass, not a smudge
    # floating over it.
    spec = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spec)
    sx, sy = cx, cy - R * 0.52
    srx, sry = R * 0.62, R * 0.26
    sd.ellipse([sx - srx, sy - sry, sx + srx, sy + sry], fill=(*PAPER, 40))
    sd.ellipse([sx - srx * 0.40, sy - sry * 0.46,
                sx + srx * 0.40, sy + sry * 0.46], fill=(*PAPER, 60))
    spec = spec.filter(ImageFilter.GaussianBlur(S * 0.030))

    # Cool halide bounce along the lower rim.
    bd = ImageDraw.Draw(spec)
    bd.ellipse([cx - R * 0.50, cy + R * 0.62,
                cx + R * 0.50, cy + R * 0.86], fill=(*HALIDE, 34))
    spec = spec.filter(ImageFilter.GaussianBlur(S * 0.014))

    disc_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(disc_mask).ellipse([cx - R, cy - R, cx + R, cy + R], fill=255)
    spec.putalpha(Image.composite(spec.getchannel("A"),
                                  Image.new("L", (S, S), 0), disc_mask))
    img = Image.alpha_composite(img, spec)
    draw = ImageDraw.Draw(img)

    # ── 7. Disc edge ─────────────────────────────────────────────────────────
    ew = max(1, int(S * 0.005))
    draw.ellipse([cx - R, cy - R, cx + R, cy + R],
                 outline=(*CHAMBER, 190), width=ew + ew)
    draw.ellipse([cx - R, cy - R, cx + R, cy + R],
                 outline=(*HALIDE_DEEP, 95), width=ew)

    # ── 8. Resolve supersampling ─────────────────────────────────────────────
    if SS > 1:
        img = img.resize((px, px), Image.LANCZOS)
    return img


def filename(pt: int, scale: int) -> str:
    return f"icon_{pt}x{pt}.png" if scale == 1 else f"icon_{pt}x{pt}@{scale}x.png"


if __name__ == "__main__":
    print("macOS — Assets.xcassets/AppIcon.appiconset/")
    for pt, scale in SIZES:
        size_px = pt * scale
        out = os.path.join(OUTPUT_DIR, filename(pt, scale))
        make_icon(size_px).save(out, "PNG")
        print(f"  {filename(pt, scale):<24} {size_px}x{size_px}")

    # Windows: one .ico carrying every rendition, each rendered at its own size
    # so the small ones get the simplified mark rather than a downscaled large one.
    print("\nWindows — DesqueezeWindows/Assets/icon.ico")
    frames = [make_icon(s) for s in WIN_ICON_SIZES]
    ico_path = os.path.join(WIN_ICON_DIR, "icon.ico")
    frames[-1].save(
        ico_path,
        format="ICO",
        sizes=[(s, s) for s in WIN_ICON_SIZES],
        append_images=frames[:-1],
    )
    print(f"  icon.ico                 {', '.join(str(s) for s in WIN_ICON_SIZES)}")

    print("\nDone — all icon sizes generated.")
