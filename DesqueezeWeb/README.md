# Desqueeze — web client

The third client, after macOS and Windows. Lives at
<https://chambersandlight.com/u/desqueeze/>.

Same operation as the other two: **widen by the squeeze factor, leave height
untouched** (`Services/DesqueezeProcessor.cs`), and the same nine presets
(`Models/SqueezePreset.cs`). Up to **36 images** at once.

## Running it

There is no build step and no dependencies. Open `index.html`, or serve the
folder:

```sh
python3 -m http.server 8000 --directory DesqueezeWeb
```

Every path is relative, so it works from any prefix without configuration.

## Why no framework

The utilities CSP allows **no external origins** and `script-src 'self'`. Plain
files satisfy that by construction — nothing to audit, nothing to pin, no lockfile
to keep current. The whole client is a handful of plain files: the app's
three, and the site's header (a copy of the site's own — see `docs/UTILITIES.md`
in `bchambers67/briantchambers.com`).

## What it does that the native apps do

| Feature                | Here                                                     |
| ---------------------- | -------------------------------------------------------- |
| Nine presets + custom  | Yes, identical factors and glass names                   |
| Batch                  | Yes, up to 36                                            |
| Per-image override     | Yes — each card has its own factor, or follows the batch |
| Preview                | Yes, thumbnails corrected to the output aspect           |
| EXIF preserved         | Yes on JPEG output, with pixel dimensions corrected      |
| Export JPEG / PNG      | Yes (JPEG at quality 92, matching the native encoders)   |
| Drag and drop          | Yes                                                      |

## What it does not

- **No automatic factor detection.** The macOS app uses Vision's on-device face
  detector; browsers have no equivalent, so factors are chosen manually here,
  as on Windows.
- **No TIFF export.** Browsers cannot encode TIFF natively, and shipping an
  encoder would mean the third-party code the CSP exists to exclude.
- **No external-editor round trip.** There is no browser equivalent of
  "Edit In…".
- **PNG output from the ordinary path carries no EXIF.** `canvas.toBlob` drops
  it and there is no APP1 to splice. Choose JPEG to keep capture metadata on
  images that fit in one canvas. Images too large for one canvas are written
  by the app's own PNG encoder, which does carry it, as an `eXIf` chunk.

## Privacy

Images are never uploaded. There is no server, no account and no analytics.
Nothing is written to `localStorage`, `sessionStorage`, IndexedDB or the Cache
API, and there is no service worker. Object URLs are revoked as soon as an image
is removed or the tab goes away, so a cleared queue is unreachable immediately.

Verified in a real browser, not asserted: after a full 36-image run,
`localStorage.length` and `sessionStorage.length` are both `0` and
`navigator.serviceWorker.controller` is `null`.

## Implementation notes

- **EXIF** (`findAPP1` / `patchPixelDims` / `spliceAPP1`) — canvas re-encoding
  drops all markers, so APP1 is lifted from the source and spliced back in after
  SOI. `PixelXDimension` / `PixelYDimension` are rewritten in place to match the
  new size; only inline 4-byte value fields are touched, so nothing moves. Both
  layouts are handled — cameras put these tags in the Exif sub-IFD, some writing
  libraries put them in IFD0. Anything unrecognised is left untouched: stale
  dimensions are a blemish, corrupt EXIF is damage.
- **ZIP** (`makeZip`) — store-only, no deflate. JPEG and PNG are already
  compressed, so deflating buys nothing and would mean shipping a compressor.
- **Canvas limits** (`probeLimits` / `renderTiled` / `encodePNG`) — browsers
  cap canvases two ways: Chrome and Firefox by side (16384 / 32767), Safari by
  total area (4096², or 8192² since iOS 18). An over-limit canvas does not
  throw; it silently yields a blank bitmap. Both limits are measured at first
  use with small probe canvases rather than assumed, and the tool uses half the
  measured area so the source bitmap and encoder have room beside it.
  A result that fits goes through one canvas as before. One that does not is
  rendered in tiles, each inside the measured limits and overlapping its
  neighbours by four source pixels so the resampler sees no edge, and the rows
  are streamed straight into a PNG written here: IDAT is a zlib stream, which is
  exactly what the browser's native `CompressionStream("deflate")` produces, so
  no library is needed and the whole image is never held in one canvas. The
  only ceiling left is memory for the encoded bytes. JPEG needs the canvas
  encoder, so an over-limit result is saved as PNG and the card says so.
- **Sequential processing** with a yield between images, so the grid repaints
  and progress is honest rather than a frozen tab.

## Deploying

`.github/workflows/deploy-web.yml` syncs this folder to
`s3://chambersandlight-utilities/u/desqueeze/` on every push to `main` that
touches it, using GitHub OIDC — no stored AWS keys.

Requires the repository variable `AWS_UTILITY_ROLE_ARN`:

```
arn:aws:iam::715924016379:role/chambersandlight-utility-desqueeze
```

The role can write only that one prefix.
