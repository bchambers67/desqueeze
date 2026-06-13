# Desqueeze — A Chambers & Light Tool

A native macOS app for correcting horizontally-squeezed anamorphic photographs from digital sources.

## Features

- **Three preset squeeze factors**: 1.33× (Hawk/Lomo), 1.50× (SLR Magic), 2.00× (full 2× glass)
- **Custom factor** — type any value you need
- **Side-by-side / single preview** with live toggle
- **Drag-and-drop** or file-browser import (JPEG, TIFF, PNG, HEIC, RAW)
- **One-click export** as JPEG or PNG
- Background processing with a progress indicator
- Output dimensions and aspect ratio displayed in real time

## Requirements

- macOS 13 Ventura or later
- Xcode 15+

## Building

1. Clone this repository
2. Open `desqueeze/AnamorphicDesqueeze.xcodeproj` in Xcode
3. Set your Development Team in *Signing & Capabilities*
4. Press **⌘R** to build and run

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

| File                       | Responsibility                                      |
|----------------------------|-----------------------------------------------------|
| `AnamorphicDesqueezeApp`   | App entry point, window scene                       |
| `ContentView`              | Root layout — HSplitView                            |
| `DropZoneView`             | Drag-and-drop / file-browser import                 |
| `PreviewView`              | Side-by-side and single-image preview modes         |
| `ControlsPanel`            | Factor selection, output info, export               |
| `DesqueezeProcessor`       | Core image scaling via `CGContext`, file I/O        |
| `BrandTheme`               | Design tokens (colors, spacing, typography)         |

## License

© 2024 Chambers & Light. All rights reserved.
