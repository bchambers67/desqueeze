# StillScope brand package

StillScope is the anamorphic still-photo tool from Chambers & Light. It was
called Desqueeze until November 2026.

`brand-sheet.png` shows everything here on one page.

## The name

One word, capital S twice: **StillScope**. In the wordmark it is set in
capitals. "Scope" is the old cinema word for anamorphic widescreen; "Still" is
what the tool is for.

## The mark

A tall oval set across a wide frame. An anamorphic lens renders every point of
light as a tall oval, and the frame is the scope picture it produces. The oval
is twice as tall as it is wide, which is the 2× squeeze. The frame is 2.39:1.

## Colour

Taken from the Chambers & Light brand guide.

| Name      | Hex       | Use                                         |
|-----------|-----------|---------------------------------------------|
| Chamber   | `#201612` | Ground, icon background, aperture           |
| Coral     | `#FF6748` | The lens. One accent per surface.           |
| Silver    | `#C2C1BA` | Secondary text, hairlines                   |
| Warm gray | `#F5F3F1` | The frame on dark, the ground on light      |
| White     | `#FFFFFF` | Primary text on Chamber                     |

## Type

The wordmark is Inter Medium, capitals, tracked 0.15 em, converted to outlines
so it needs no font installed. Interface and document type follows the
Chambers & Light guide: Neue Haas Grotesk, then Helvetica Neue, then Inter,
with Space Mono for figures.

## App icon for Icon Composer

Apple's Icon Composer builds a Liquid Glass icon from flat layers. It adds the
glass, highlights, shadows and the dark, clear and tinted variants itself, so
the layers here carry shape and colour only: no gradients, shadows or masks.

`icon/layers/` holds three 1024 × 1024 SVG layers, back to front:

| File             | Layer    | Suggested setting in Icon Composer           |
|------------------|----------|----------------------------------------------|
| `1-frame.svg`    | Frame    | Glass on, some translucency, neutral shadow  |
| `2-lens.svg`     | Lens     | Glass on, in its own group above the frame   |
| `3-aperture.svg` | Aperture | Glass off, top group, so it reads as a hole  |

Set the background fill to Chamber `#201612`.

To build the icon:

1. Open Icon Composer, from Xcode's menu under Open Developer Tool.
2. Drag the three SVG files into the sidebar and order them as above, each in
   its own group.
3. Set the background colour and the settings in the table.
4. Check the Default, Dark, Clear and Tinted previews, then save as
   `AppIcon.icon` and add that file to the Xcode project.

`icon/StillScope.icon` is a hand-written bundle with those settings already
applied. It was written without access to Icon Composer and has not been
opened in it. If it does not open, build the icon from the layers as above.

`icon/preview/` holds flat renders for reference, with no glass. The iOS app
uses the dark and light PNGs as its icon until the composed icon replaces them.

## Wordmark and lockup

`wordmark/` holds the mark alone, the wordmark alone and the two together, each
for dark and light grounds. All are SVG with outlined type.

Keep clear space around the lockup equal to the height of the frame. Do not
recolour the lens, stretch the mark, or set the name in mixed weights.
