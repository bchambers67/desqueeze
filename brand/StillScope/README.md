# StillScope brand package

StillScope is the anamorphic still-photo tool from Chambers & Light. It was
called Desqueeze until November 2026.

`brand-sheet.png` shows everything here on one page.

## The name

One word, capital S twice: **StillScope**. In the wordmark it is set in
capitals. "Scope" is the old cinema word for anamorphic widescreen; "Still" is
what the tool is for.

## The mark

One shape: the wide scope frame as an anamorphic lens draws it. The sides
stand straight and the top and bottom edges bow toward the centre, which is
the curve of an anamorphic field and the shape of a curved scope screen. On a
dark ground it is halide; on a light ground it is halide deep or pine.

## Colour

The green register of the palette published at chambersandlight.com. It
replaced the chamber-and-coral scheme in November 2026.

| Name        | Hex       | Use                                        |
|-------------|-----------|--------------------------------------------|
| Pine        | `#1C2723` | Ground, icon background                    |
| Halide      | `#C7D9CE` | The accent and the mark. One per surface.  |
| Halide deep | `#98B1A3` | Secondary text, hairlines                  |
| Paper       | `#ECEAE1` | Primary text on pine; the light ground     |
| Safelight   | `#E63E2D` | Errors only                                |

Halide is pale. Anything set on it, such as the label of a primary button, is
pine, never paper.

## Type

The wordmark is Inter Medium, capitals, tracked 0.15 em, converted to outlines
so it needs no font installed. Interface and document type follows the
Chambers & Light guide: Neue Haas Grotesk, then Helvetica Neue, then Inter,
with Space Mono for figures.

## App icon for Icon Composer

Apple's Icon Composer builds a Liquid Glass icon from flat layers. It adds the
glass, highlights, shadows and the dark, clear and tinted variants itself, so
the layers here carry shape and colour only: no gradients, shadows or masks.

`icon/layers/field.svg` is the whole icon: one 1024 × 1024 layer holding the
halide shape. Set the background fill to Pine `#1C2723`.

To build the icon:

1. Open Icon Composer, from Xcode's menu under Open Developer Tool.
2. Drag `field.svg` into the sidebar.
3. Set the background colour. Turn glass on for the layer, with a little
   translucency and a shadow in the layer's own colour.
4. Check the Default, Dark, Clear and Tinted previews, then save as
   `AppIcon.icon` and add that file to the Xcode project.

`icon/StillScope.icon` is a hand-written bundle with those settings already
applied. It was written without access to Icon Composer and has not been
opened in it. If it does not open, build the icon from the layers as above.

`icon/preview/` holds flat renders for reference, with no glass. The iOS app
uses the dark and light PNGs as its icon until the composed icon replaces them.

## Wordmark and lockup

`wordmark/` holds the mark alone, the wordmark alone and the two together. The
wordmark and lockup come for dark and light grounds; the mark is the same on
both. All are SVG with outlined type.

Keep clear space around the lockup equal to the height of the mark. Do not
set the mark in colours outside the palette, straighten or reverse its curve,
or set the name in mixed weights.
