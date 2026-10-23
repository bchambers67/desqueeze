# Desqueeze for iOS

Anamorphic correction on iPhone and iPad, built for iOS 27 and the iPhone Duo.

Status: **scaffold**. The correction pipeline, adaptive layout, import and export
work end to end. The items under *Not yet built* are deliberately absent.

## Requirements

- iOS 27.0+
- Xcode 27
- Swift 6, strict concurrency

```
open DesqueezeiOS/Desqueeze.xcodeproj
```

Set your Development Team under *Signing & Capabilities* before running on
device.

## The correction

Core Image has a filter made for exactly this job. `CILanczosScaleTransform`
takes both a `scale` and an `aspectRatio`, where the aspect ratio is a further
horizontal multiplier applied after the uniform scale. Holding `scale` at 1 and
passing the squeeze factor as `aspectRatio` widens the frame, leaves its height
untouched, and reconstructs with Lanczos — the right filter for a single-axis
upscale.

That is the whole of `DesqueezeService.desqueeze(_:factor:)`. It is an `actor`,
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

- Layout branches on `horizontalSizeClass`, not on device or measured points.
  Regular → image and controls side by side. Compact → image above, controls
  beneath. This covers the Duo's two states and every iPad configuration
  without a device check.
- Document state lives in an `@Observable` model owned by the app, never in
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

**One deliberate departure.** The guide sets reading surfaces on white and
reserves chamber grounds for "covers, decks, and gallery materials." This app
sits on chamber throughout: a photo-judging surface is gallery context, and a
neutral dark ground avoids casting the image being evaluated. Flagging it
because it is a reading of the guide, not a rule in it.

## Not yet built

- Batch — the macOS and Windows clients both have it
- Auto-detection — macOS uses Vision face geometry to suggest a factor
- Metadata preservation — macOS carries EXIF, GPS and capture data onto the
  export; this writes a clean JPEG
- App icon
- Share sheet export; currently saves to the photo library only

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
