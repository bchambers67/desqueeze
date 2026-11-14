# StillScope for iOS

Anamorphic correction on iPhone and iPad, built for iOS 27 and the iPhone Duo.

Corrects one photo with live preview and pixel-level inspection, or a batch of any
size. Suggests a factor from the faces in the frame, keeps capture metadata
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

Uses the green register of the palette published at chambersandlight.com:
pine `#1C2723` for the ground, halide `#C7D9CE` for the accent, halide deep
`#98B1A3` for secondary text and paper `#ECEAE1` for type, with safelight red
`#E63E2D` kept for errors. Typography is one letterspaced sans (Neue Haas
Grotesk → Helvetica Neue → Inter) with Space Mono for frame-edge annotations.
Square corners throughout, hairlines, the accent as punctuation only. Tokens
are named for their role (`ground`, `accent`, `secondary`, `primary`), so the
scheme changes in one file.

`BrandTheme.swift` is the single place a colour or face is declared.

**Controls are Liquid Glass.** They float above the photograph in one glass
layer, following Apple's *Adopting Liquid Glass*: the system toolbar along the
bottom on iPhone and on an open Duo held upright, and on an open Duo held
sideways a bar against the right edge, built
from the system's glass button styles in a single `GlassEffectContainer`. Icons
carry accessibility labels; the factor, being text, has a group to itself. Its
button pops a glass panel out over the photograph, just above the bar, holding
a slider from 1.00 to 2.00. The panel floats: nothing beneath it moves, and
the bar stays in reach. It grows out of the button and shrinks back into it on
a spring, as a folder does on the Home Screen. The nine lens
presets are stop points marked under the track: the factor snaps to them, with
a light haptic tap on each. Holding still between two stops for two seconds
releases the snap, and the factor then follows the thumb in hundredths until
the finger lifts. The preview reshapes with the factor at once and the proper
render follows; renders asked for while one is running collapse into one. On an
open Duo held sideways the panel is always on screen, in a strip of its own
under the photograph, and the side bar has no factor button. The accent marks Save and the factor. The brand's square corners and flat surfaces hold for the
content layer beneath; the glass layer keeps the system's shapes.

`BarEdge` decides the side from the window's size, not from a device check or a
fold API: an open Duo's short side is about 626 points and no slab iPhone
exceeds 440.

**A dark ground on purpose.** A photo-judging surface is gallery context, and
a dark, low-chroma ground keeps the interface from casting the image being
evaluated. Pine is a green-black, close enough to neutral not to tint what
sits on it.

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

## From other apps

StillScope can be reached without opening it first.

- **Share sheet.** In any app that shares a photo, choose StillScope from the
  share sheet. A small editor opens over that app with the photo and the
  factor slider, and Save to Photos writes the corrected copy to the library.
  This is the `Share` extension in `Extensions/Share`.
- **Edit in Photos.** In the Photos app, open a photo, tap Edit, then the
  extensions button, and choose StillScope. The correction is saved onto the
  photo itself. Photos keeps the original, so Revert undoes it, and the factor
  is stored with the photo. This is the `PhotoEdit` extension in
  `Extensions/PhotoEdit`.
- **Open in.** Files, Mail and other apps that hold an image file offer Open in
  StillScope, which opens the file in the full app.

Both extensions show `QuickEditor`, compiled from the same source as the app's
slider and renderer. They are built in Swift 5 mode because the extension
hosts pass completion handlers that predate `Sendable`.

## Finding squeezed photos

With **Find squeezed photos** on in Settings, StillScope checks the last two
weeks of the library each time it comes forward and offers to queue what it
finds. A button in the action bar runs the same check on demand, and a long press on
it offers a full recheck that looks again at photos an earlier check passed over. It is off by default, because it is the one feature that reads the
library, and turning it on is what asks for that access.

`SqueezeDetector` in the core package decides. Two signs are trusted outright:

- **The lens.** A lens the camera recorded as anamorphic, which often states
  its factor.
- **The session.** A photo taken within ten minutes of one you corrected, at
  the same pixel size, takes that photo's factor. Corrections are learned from
  photos saved out of the app while the finder is on.

Four more are read from the picture by `PictureReader` and `PictureSignals`:

- **Faces**, from how narrow they are. Trusted alone.
- **Text**, from the width of letters against the height of their line.
- **Bodies**, from shoulder width against torso length, taking the widest
  person as the one facing the camera.
- **Detail**, from how much denser fine texture is across the frame than down.

Text, bodies and detail are looser, so they only count in agreement: at least
two readings within 0.3 of each other, with more saying squeezed than
ordinary. Detail can support another reading but never leads. A photo with no
sign is left alone. Screenshots, edited photos, files StillScope saved and
frames already wide are skipped. `RecentScanner` reads the library and feeds
all of this. Photos that were saved, dismissed or found ordinary are
remembered and not examined again.

The reference proportions in `PictureSignals` are estimates and have not been
tuned against real photographs. Each reading is a plain number per photo,
which is also the form a trained classifier would take as input or replace.

Limits: a plain, soft photo with no people or text and no corrected neighbour
gives nothing to read and will not be found, and photos still in iCloud are
skipped until they are on the device. Scanning happens only while the app is open.
