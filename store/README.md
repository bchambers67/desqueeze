# StillScope store package

| File | What it is |
|---|---|
| `CHECKLIST.md` | everything left to do, and who does it |
| `listing/ios.md` | iPhone, iPad and iPhone Duo listing, keywords, review notes, privacy answers |
| `listing/mac.md` | Mac App Store listing |
| `privacy-policy.md` | text for the privacy policy page you must host |
| `screenshots/shots.json` | each device's store size and its caption for each shot |
| `screenshots/compose.py` | sets your real captures on store-size canvases (needs Pillow) |
| `screenshots/captures/SHOTLIST.md` | exactly which screens to capture, at what size, and how |

Run from `store/screenshots/`: `python3 compose.py` (all devices) or `python3 compose.py ipad`.
Output lands in `output/<device>/`. A capture that is missing is listed, and skipped.
