# Capture list

Take each screen at the device's native size, put it in `captures/<device>/<name>.png`, then run
`python3 compose.py`. It sets each capture on a pine canvas at the store size with its caption.
Captions are in `shots.json`; change them there.

Use the **current TestFlight build**. Captures made before the green palette, the glass bars,
the circled-✕ Clear button and the removed "TAP TO INSPECT" label show the old interface and must
not be used.

## How to capture cleanly

- **Simulator:** `xcrun simctl status_bar booted override --time 9:41 --batteryState charged
  --batteryLevel 100 --cellularBars 4 --wifiBars 3`, then
  `xcrun simctl io booted screenshot name.png`. Simulators give exact store pixel sizes.
- **Device:** screenshot with the side button + volume up; do not use a screen recording (it
  adds the red recording indicator). Turn on Do Not Disturb and set the clock before capturing.
- Use real photos: ones shot through an anamorphic lens, and a corrected result. Avoid recognisable
  people unless you hold a release. A photograph you own works best.
- No personal data in the frame (names in the photo picker, notifications).

## Sizes and files

| Device folder | Capture at | Store canvas | Shots to capture (file names) |
|---|---|---|---|
| `iphone` | 1320 x 2868 (6.9" Pro Max simulator) | 1320 x 2868 | `empty` first launch screen; `factor` slider panel open, a photo behind it; `photo` a corrected photo; `inspect` the 1:1 inspector; `batch` the batch grid with some selected; `detected` the "Review N squeezed photos" button on the empty screen after a scan |
| `ipad` | 2064 x 2752 portrait or 2752 x 2064 landscape (13" simulator) | 2752 x 2064 | `photo`, `factor` (landscape bar with the panel open), `batch`, `inspect` |
| `duo-open-landscape` | 2853 x 2007 | 2853 x 2007 | `photo` (controls at the right edge, slider strip underneath), `batch` |
| `duo-open-portrait` | 2007 x 2853 | 2007 x 2853 | `photo`, `factor` |
| `duo-folded` | 1398 x 2034 | 1398 x 2034 | `photo`, `factor` |
| `mac` | window about 1440 x 900 points at 2x | 2880 x 1800 | `photo`, `batch` |

App Store Connect takes up to 10 screenshots per device size; the first three show in search
results, so make the first three the strongest (`empty` or `photo`, `factor`, `batch`).
