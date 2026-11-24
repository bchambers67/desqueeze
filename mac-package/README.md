# StillScope: Mac package for Claude Code

Everything that could not be done from the cloud session, because it needs Xcode, the
simulators, a screen or your Apple credentials. Open Claude Code in the repo on your Mac and
give it one instruction:

```
cd path/to/desqueeze
git pull origin main
claude "Read mac-package/START-HERE.md and carry it out. Stop at each STOP."
```

| Path | What it is |
|---|---|
| `START-HERE.md` | the instructions Claude Code follows, in phases, with what to stop and ask about |
| `scripts/preflight.sh` | checks Xcode, simulators, gh, fastlane, Pillow, and the API key variables |
| `scripts/build-ios.sh`, `build-mac.sh` | compile the iOS and Mac apps (the first compile outside Xcode Cloud) |
| `scripts/test-core.sh` | the core package's tests |
| `scripts/capture-sim.sh` | one clean simulator screenshot (9:41, full battery, dark) |
| `scripts/capture-mac.sh` | a screenshot of a Mac window |
| `scripts/make-samples.py` | squeezes your own photos so the app has authentic input |
| `scripts/collect-crash.sh` | gathers the log that names what holds the lock in the 0xDEAD10CC crash |
| `scripts/make-metadata.py` | turns `store/listing/ios.md` into fastlane text and checks Apple's limits |
| `fastlane/` | uploads listing text and screenshots; never submits for review |

## What you provide

1. **Photographs of your own** in `samples/originals/`: six to ten, any subject you hold the rights
   to, a mix of landscape and portrait. Claude Code squeezes copies to make "anamorphic" input.
2. **An App Store Connect API key**, only for the upload phase. Create it under Users and Access >
   Integrations, download the `.p8`, then in the same Terminal: `export ASC_KEY_ID=...
   ASC_ISSUER_ID=... ASC_KEY_PATH=/path/AuthKey_XXXX.p8`. Never paste these into the chat.

## What stays with you

Pricing and availability, the trader status banner, the App Privacy and age-rating answers
(App Store Connect has no API for the privacy answers), hosting the privacy policy, the review
contact, and pressing Submit for Review. `START-HERE.md` never does these.
