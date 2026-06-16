# Desqueeze — A Chambers & Light Tool

A native macOS app for correcting horizontally-squeezed anamorphic photographs from digital sources.

## Features

- **Automatic squeeze detection** — Vision's on-device face detector measures face geometry to suggest the squeeze factor for each image
- **Nine preset factors** — 1.25×, 1.33×, 1.50×, 1.55×, 1.60×, 1.65×, 1.75×, 1.80×, 2.00×, plus a **Custom** field for any value
- **Batch mode** — drop a whole folder of images, auto-detect each one, override individually or apply a factor in bulk, then export them all to a destination folder
- **Side-by-side / single preview** with a live toggle
- **Drag-and-drop** or file-browser import (JPEG, TIFF, PNG, HEIC, RAW)
- **External editor round-trip** — open from Lightroom CC/Classic "Edit In…" or Finder "Open With" and save the desqueezed result straight back to the host
- **Metadata preserved** — capture date, camera, lens, GPS, and EXIF are carried onto the exported image (pixel-dimension tags updated to match)
- **One-click export** as JPEG, PNG, or TIFF
- Background processing with progress indication and live output dimensions / aspect ratio

## Requirements

- macOS 13 Ventura or later
- Xcode 15+

## Building

1. Clone this repository
2. Open `AnamorphicDesqueeze/AnamorphicDesqueeze.xcodeproj` in Xcode
3. Set your Development Team in *Signing & Capabilities*
4. Press **⌘R** to build and run

## How auto-detection works

Faces in un-squeezed photographs have a fairly stable bounding-box width-to-height
ratio. When an image is captured with an anamorphic lens and shown un-desqueezed,
faces appear vertically elongated by the squeeze factor. `SqueezeEstimator` runs
Vision's neural face detector, compares the observed face aspect against a
calibrated reference, and recovers the factor (clamped to a plausible 1.10–2.30
range). The measured value is snapped to the nearest preset when it's close, or
offered as a Custom value otherwise. You always stay in control — every suggestion
can be overridden.

## Brand

Dark-theme UI built to Chambers & Light brand standards:

| Token             | Hex       | Use                          |
|-------------------|-----------|------------------------------|
| Background        | `#0D0D0D` | App window                   |
| Surface           | `#242424` | Cards, panels                |
| Accent (Gold)     | `#C9A84C` | Highlights, active states    |
| Text Primary      | `#F5F0E8` | Body copy                    |
| Text Secondary    | `#8A8580` | Labels, captions             |

Typography: SF Pro (system) for UI, Georgia Serif for the app wordmark.

## Architecture

| File                       | Responsibility                                              |
|----------------------------|-------------------------------------------------------------|
| `AnamorphicDesqueezeApp`   | App entry point, window scene, app delegate wiring          |
| `ContentView`              | Root layout — HSplitView, single/batch mode switching       |
| `DropZoneView`             | Drag-and-drop / file-browser import                         |
| `PreviewView`              | Side-by-side and single-image preview modes                 |
| `ControlsPanel`            | Factor selection, suggestion, output info, export           |
| `DesqueezeProcessor`       | Core image scaling via `CGContext`, round-trip, file I/O    |
| `ImageWriter`              | Metadata-preserving encode through ImageIO                  |
| `SqueezeEstimator`         | Vision-based automatic squeeze-factor detection             |
| `BatchProcessor` / `BatchItem` | Multi-file batch detection, override, and export        |
| `BatchView` / `BatchControlsPanel` | Batch list UI and bulk controls                     |
| `ExternalEditState` / `AppDelegate` | Receives "Edit In…" / "Open With" file events      |
| `BrandTheme`               | Design tokens (colors, spacing, typography)                 |
| `AppIconLogo`              | Wordmark / app-icon vector drawing                          |

## License

© 2024 Chambers & Light. All rights reserved.
