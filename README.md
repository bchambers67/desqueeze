# Desqueeze — A Chambers & Light Tool

A native macOS app for correcting horizontally-squeezed anamorphic photographs from digital sources, with a matching Windows client.

## Features

- **Automatic squeeze detection** — Vision's on-device face detector measures face geometry to suggest the squeeze factor for each image (macOS)
- **Nine preset factors** — 1.25×, 1.33×, 1.50×, 1.55×, 1.60×, 1.65×, 1.75×, 1.80×, 2.00×, plus a **Custom** field for any value
- **Batch mode** — drop a whole folder of images, auto-detect each one, override individually or apply a factor in bulk, then export them all to a destination folder
- **Side-by-side / single preview** with a live toggle
- **Drag-and-drop** or file-browser import (JPEG, TIFF, PNG, HEIC, RAW)
- **External editor round-trip** — open from Lightroom CC/Classic "Edit In…" or Finder "Open With" and save the desqueezed result straight back to the host (macOS)
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

## Windows

A WPF client lives in `DesqueezeWindows/`, sharing the brand system and the same
nine squeeze presets as the macOS app.

- Windows 10 / 11 (x64), [.NET 8 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/8.0)
- Batch: drop a folder (or several files) and process the queue to a destination folder
- Export as JPEG, PNG, or TIFF

```
dotnet run --project DesqueezeWindows -c Release
```

CI publishes a self-contained single-file `Desqueeze.exe` on every push touching
`DesqueezeWindows/` — see `.github/workflows/build-windows.yml`.

The Windows client has no equivalent of the Vision-based auto-estimator; factors
are chosen manually there.

### A note on letter-spacing

The brand tracks uppercase labels between `.12em` and `.22em`. **WPF has no
letter-spacing primitive** — `CharacterSpacing` exists only in WinUI/UWP, so
setting it on a `TextBlock` is a compile error rather than a no-op.
`Tracking.cs` provides a `Track.Em` attached property that approximates tracking
by interleaving Unicode fixed-width spaces, which is also literally how the house
lockup is set: `C H A M B E R S  &  L I G H T`. It resolves once, so it is
applied only to static labels, never to bound text.

## Brand

The interface implements the Chambers & Light system. Tokens are the
authoritative `:root` custom properties published at chambersandlight.com;
`BrandTheme.swift` (macOS) and `BrandTheme.xaml` (Windows) are the only places
a colour or face is declared.

The palette follows a darkroom metaphor: the **chamber** holds the image,
**paper** receives it, **halide** is the light-sensitive layer, **grain** the
texture, and **safelight** the only illumination safe to work by.

| Token            | Hex       | Use                                   |
|------------------|-----------|---------------------------------------|
| `chamber`        | `#16110F` | Window ground, image wells            |
| `pine`           | `#1C2723` | Selected rows, raised surfaces        |
| `paper`          | `#ECEAE1` | Primary text, active labels           |
| `halide`         | `#C7D9CE` | Numeric readouts, highlights          |
| `halide-deep`    | `#98B1A3` | Secondary text, section labels        |
| `grain`          | `#6E665F` | Tertiary text, hints, disabled states |
| `safelight`      | `#E63E2D` | Accent — selection, export, errors    |
| `safelight-deep` | `#C22E1F` | Pressed state                         |

**Typography** — Bodoni Moda (falling back through Didot to Georgia) for the
wordmark, Archivo for interface copy, Space Mono for factors and dimensions.
Each stack is resolved against the faces actually installed, so both apps
degrade cleanly on a machine without the brand fonts rather than substituting
silently. Uppercase labels are tracked between `.12em` and `.22em`.

Corners are square and rules are hairlines throughout.

## App icon

`generate_icon.py` renders the mark from the same brand tokens: an anamorphic
element squeezed narrow, opening along the safelight axis to the halide frame
marking its true width. Small renditions progressively drop the frame and
registration marks so the idea still reads at 16 px.

It writes both the ten macOS iconset PNGs and the eight-resolution Windows
`.ico`, so the binary assets are reproducible from source:

```
pip install Pillow
python3 generate_icon.py
```

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
| `BrandTheme`               | Design tokens, type resolution, brand devices               |
| `AppIconLogo`              | Renders the app icon asset at a given size                  |

### Windows

| File                      | Responsibility                                          |
|---------------------------|---------------------------------------------------------|
| `BrandTheme.xaml`         | Design tokens — colours, fonts, control styles          |
| `MainWindow.xaml/.cs`     | Root window, layout, event handling                     |
| `Models/SqueezePreset`    | The nine presets, in lockstep with macOS                |
| `Services/DesqueezeProcessor` | Image scaling via `RenderTargetBitmap`, file I/O    |
| `Services/BatchProcessor` | Folder enumeration for batch runs                       |
| `ViewModels/MainViewModel`| Single-image and batch state                            |
| `Tracking.cs`             | `Track.Em` attached property (letter-spacing)           |
| `Converters.cs`           | `InverseBoolToVisibilityConverter`                      |
| `Views/ImageCell`, `Views/InfoRow` | Reusable preview cell and label/value row      |

## License

© 2024 Chambers & Light LLC. All rights reserved.
