# Desqueeze for iOS

Anamorphic correction on iPhone and iPad, built for iOS 27 and the iPhone Duo.

Corrects one photo with live preview and pixel-level inspection, or a batch of
up to 36. Suggests a factor from the faces in the frame, keeps capture metadata
on export, and saves to the photo library or the share sheet.

## Requirements

- iOS 27.0+
- Xcode 27
- Swift 6, strict concurrency

```
open DesqueezeiOS/Desqueeze.xcodeproj
```

Set your Development Team under *Signing & Capabilities* before running on
device.

## How it is built

The logic lives in `DesqueezeCore`, a Swift package with no UIKit, Core Image or
Vision in it, built test-first. The app is views and three adapters on top.

```
cd DesqueezeiOS/DesqueezeCore && swift test      # 33 tests, runs on macOS or Linux
```

In Xcode the same tests run from the `DesqueezeCore` scheme.

Tests sit at four seams, agreed before any were written:

| Seam | Module | What a test there catches |
|---|---|---|
| Geometry | `Squeeze` | wrong output size or ratio; typed factors, including `1,5` from a comma-decimal keypad |
| Capture metadata | `CaptureMetadata.carry` | EXIF lost, duplicated, or left describing the old size; a damaged block being "repaired" |
| Editor session | `EditorSession` | a slow render overwriting a newer one; state lost across a fold; a bad file leaving stale state |
| Batch queue | `BatchQueue` | one bad photo stopping the run; a retry saving finished photos twice |

The session and the queue reach pixels through one protocol, `FrameRenderer`.
Core Image satisfies it in the app (`CoreImageRenderer`); a fake does in tests.
That is the only thing faked: it is the one boundary the logic does not own.

Not under test, because no seam was agreed for them: the SwiftUI views, the
Core Image and Vision adapters, and the snap-to-preset rule for suggestions.

## The correction

Core Image has a filter made for exactly this job. `CILanczosScaleTransform`
takes both a `scale` and an `aspectRatio`, where the aspect ratio is a further
horizontal multiplier applied after the uniform scale. Holding `scale` at 1 and
passing the squeeze factor as `aspectRatio` widens the frame, leaves its height
untouched, and reconstructs with Lanczos — the right filter for a single-axis
upscale.

That is the whole of `CoreImageRenderer.widened(_:by:)`. The renderer is an `actor`,
so decode and render stay off the main thread and cannot overlap.

Preview renders are capped to roughly the pixels the current display can show. A
48MP frame widened 2× is far larger than any Duo surface, and rasterising it in
full would spend memory on pixels that are immediately downsampled. Export
re-renders from the original bytes at native size, so nothing is upscaled from
the preview.

## iPhone Duo

The Duo has two canvases and switches between them while the app is running:

| Surface | Size | Resolution | PPI |
|---------|------|------------|-----|
| Inner (open)   | 7.6 in | 1878 × 2670 | 430 |
| Outer (closed) | 5.4 in | 1398 × 2034 | 460 |

Both are ProMotion 120Hz, Always-On, P3. The device ships with iOS 27 on an
A20 Pro.

**Nothing in this app reads a hinge or fold API.** Apple's specification page
documents no such API, and the developer *What's New* page does not mention
foldables at all. Folding is handled the way any other resize is handled:

- The photograph fills the screen in both states; only the action bar moves,
  from the bottom edge folded to the right edge open.
- Document state lives in `EditorSession`, owned by the app, never in
  view-local `@State`. A fold is a resize: SwiftUI rebuilds the tree around the
  new size class, and view-local state goes with it. Holding it outside is what
  makes the fold lossless — factor, source image and render survive it.
- The preview budget follows the surface actually in use, so the folded state
  does not render pixels the outer display cannot show.

Points-per-surface are not hardcoded anywhere, because Apple does not publish
the Duo's logical resolution and a guess would be wrong on one of the two
screens.

## Brand

Implements the Chambers & Light system from the brand guide: chamber `#201612`,
coral `#FF6748`, silver `#C2C1BA`, white `#FFFFFF`, with `#D32F2F` reserved for
errors because coral sits too close to a warning colour to double as one.
Typography is one letterspaced sans (Neue Haas Grotesk → Helvetica Neue → Inter)
with Space Mono for frame-edge annotations. Square corners throughout, silver
hairlines, coral as punctuation only.

`BrandTheme.swift` is the single place a colour or face is declared.

**Controls are Liquid Glass.** They float above the photograph in one glass
layer, following Apple's *Adopting Liquid Glass*: the system toolbar along the
bottom on iPhone and on an open Duo held upright, and on an open Duo held
sideways a bar against the right edge, built
from the system's glass button styles in a single `GlassEffectContainer`. Icons
carry accessibility labels; the factor, being text, has a group to itself. Its
button opens a short sheet with a slider from 1.00 to 2.00. The nine lens
presets are stop points marked under the track: the factor snaps to them, with
a light haptic tap on each. Holding still between two stops for two seconds
releases the snap, and the factor then follows the thumb in hundredths until
the finger lifts. The preview reshapes with the factor at once and the proper
render follows; renders asked for while one is running collapse into one. Coral marks Save and the factor. The brand's square corners and flat surfaces hold for the
content layer beneath; the glass layer keeps the system's shapes.

`BarEdge` decides the side from the window's size, not from a device check or a
fold API: an open Duo's short side is about 626 points and no slab iPhone
exceeds 440.

**One deliberate departure.** The guide sets reading surfaces on white and
reserves chamber grounds for "covers, decks, and gallery materials." This app
sits on chamber throughout: a photo-judging surface is gallery context, and a
neutral dark ground avoids casting the image being evaluated. Flagging it
because it is a reading of the guide, not a rule in it.

## Limits worth knowing

- **Inspection is capped at 8192 px on the long edge.** A 48MP frame widened 2×
  is 16000 px wide, and one bitmap that size is not a reasonable ask of memory.
  Below the cap, 1:1 is every pixel of the export; above it, 1:1 is of the
  capped frame, and the bar shows its size.
- **Batch photos are numbered, not named.** The picker gives no filename
  without photo-library read access, which this app does not ask for.
- **Exports are JPEG.** TIFF and PNG are on macOS.
- **Suggestions are for single photos.** macOS also reads faces per batch item;
  here a batch follows the factor you choose, with per-photo overrides.
- **JPEG sources keep their Exif block byte for byte**, maker notes included.
  HEIC, RAW and other sources keep what Core Image can restate: date, camera,
  lens, exposure and location. An embedded Exif thumbnail is carried as shot.
- **No app icon yet.**

## iOS 27 adoption

Built against what Apple documents. Several widely-reported iOS 27 changes —
`@State` becoming a macro, `ReadableDocument` / `WritableDocument` replacing
`ReferenceFileDocument` — appear only in third-party write-ups that conflict
with each other, and are not on Apple's *What's New* page. None of them are
relied on here. Verify against the Xcode 27 release notes before adopting.

Worth looking at for this app specifically:

- **Core Image RAW v9** — Apple lists a new version of the RAW processing APIs.
  Relevant, since anamorphic stills are often shot RAW.
- **SwiftUI document support** with direct disk access, for open-in-place
  editing rather than copying bytes through the picker.
- **App Intents View Annotations**, to make the corrected frame addressable.
