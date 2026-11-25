# Instructions for Claude Code on the Mac

You are working in the StillScope repository (iOS app, native Mac app, core Swift package,
store material). The earlier work was done in a cloud session that could not run Xcode, the
simulators or a screen, so **nothing in the iOS app has ever been compiled outside Xcode
Cloud**. Your job is the part that needs this Mac. Work in the phases below, in order. After
each phase, say what you did in a few lines. Where it says **STOP**, wait for the owner.

Read first: `CLAUDE.md` (repo rules), `store/CHECKLIST.md`, `store/README.md`.

## Ground rules

- Follow `CLAUDE.md`. In particular: the iOS project file is generated (`python3 -I
  generate_project.py "$PWD"` from `DesqueezeiOS`), never hand-edited. The Mac project
  (`AnamorphicDesqueeze.xcodeproj`) is hand-maintained.
- Every merge that touches `DesqueezeiOS/` sends a TestFlight build to testers. Put all iOS
  changes from this run in as few pull requests as you can (one per phase at most).
- **Never**: submit for review, change price or availability, create or revoke certificates,
  identifiers or provisioning profiles, send builds to external testers, or print, log, commit or
  paste the API key or its variables. Use them only through the environment.
- Do not invent facts about the app. If a screen or behaviour differs from the listing text in
  `store/listing/`, report it; do not change the text to fit without asking.
- If a step fails twice for the same reason, stop and report the cause. Do not loop.

## Phase 0. Preflight

Run `mac-package/scripts/preflight.sh`. It lists what is missing. Install what you can with
Homebrew (`gh`, `fastlane`, `python3`, then `python3 -m pip install --user pillow`). Do not install
Xcode. **STOP** if Xcode, an iPhone 6.9-inch simulator or an iPad 13-inch simulator is missing,
and say exactly what.

## Phase 1. Compile and test the iOS app

1. `mac-package/scripts/test-core.sh` (expect all tests to pass).
2. `mac-package/scripts/build-ios.sh`. This is the first real compile of the app target.
3. Fix every compile error. They will be small (Swift 6 isolation, API spellings, a missing
   import). Fix the cause, not the symptom. Keep each fix minimal and tell the owner what each
   was. Re-run until it prints "iOS build succeeded".
4. Fix every deprecation warning it prints, using the replacement the compiler names.
5. Open one pull request, `mac/ios-compile-fixes`, with the fixes. Follow `CLAUDE.md` for
   merging. If CI does not exist for iOS, say so and ask before merging.

## Phase 2. The native Mac app

1. `mac-package/scripts/build-mac.sh`. Fix compile errors the same way.
2. The Mac target has no privacy manifest. Add `AnamorphicDesqueeze/PrivacyInfo.xcprivacy`:
   no tracking, no tracking domains, no collected data types, and a required-reason entry for
   `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`) only if the target uses `UserDefaults`
   (grep first). Add it to the target's resources in `project.pbxproj`. Prefer `ruby -e 'require
   "xcodeproj"'` (`gem install xcodeproj`) over hand-editing. Rebuild.
3. The Mac bundle ID is now `com.chambersandlight.stillscope` (shared with iOS for universal
   purchase). Confirm the project has no other leftover `com.chambersandlight.desqueeze`.
4. Create a Release archive to prove it archives: `xcodebuild archive -project
   AnamorphicDesqueeze.xcodeproj -scheme AnamorphicDesqueeze -configuration Release -archivePath
   /tmp/StillScopeMac.xcarchive` (signing may need the owner's team; report if it does).
5. One pull request, `mac/mac-app-store-ready`. **STOP** before any upload to App Store Connect.

## Phase 3. Screenshots

The goal: real captures from the current app at the sizes in `store/screenshots/shots.json`,
composed by `store/screenshots/compose.py`.

1. Samples. Check `mac-package/samples/originals/` has the owner's photographs (stop and ask if
   it is empty). Run `python3 mac-package/scripts/make-samples.py mac-package/samples/originals
   mac-package/samples/squeezed 1.5`.
2. A screenshot mode, in **debug builds only** (`#if DEBUG`), so release builds are unaffected.
   In `AppModel`, read `ProcessInfo.processInfo.arguments` at launch:
   `-shot-dir <path>` (a folder of images) and `-shot <name>` where name is one of:
   `empty` (nothing), `photo` (open the first image, factor 1.50), `factor` (photo with the factor
   panel open), `inspect` (photo with the inspector open), `batch` (queue up to six images, the
   first four selected, factors varied), `detected` (skip: needs the library scan; the owner
   captures it by hand). Reuse the app's existing paths (`session.open`, `batch.add`,
   `isFactorPanelOpen`, `isInspecting`) rather than adding new behaviour. Keep it small.
3. Always launch with `-welcome.seenVersion 1.0 -welcome.tourSeen YES` so the welcome sheet is
   not in the shots (those are plain `UserDefaults` launch arguments; no code needed).
4. Build with `build-ios.sh`, then capture with `capture-sim.sh "<device>" <shot> <dir> -shot-dir
   $PWD/mac-package/samples/squeezed -shot <shot> -welcome.seenVersion 1.0 -welcome.tourSeen YES`.
   Devices and outputs (use the exact simulator names from `xcrun simctl list devices available`):
   - an iPhone 6.9-inch (Pro Max): `store/screenshots/captures/iphone/` (1320 x 2868)
     Then `cp -R store/screenshots/captures/iphone store/screenshots/captures/iphone-medium`.
     Apple's one required iPhone size is 1206 x 2622; it has the same proportions, so compose.py
     scales the same captures to it.
   - an iPad 13-inch: `store/screenshots/captures/ipad/`, landscape (rotate the Simulator window
     with ⌘→ before capturing; `sips -g pixelWidth -g pixelHeight` must read 2752 x 2064)
   - iPhone Duo simulators, if Xcode has them: `duo-open-landscape` (2853 x 2007),
     `duo-open-portrait` (2007 x 2853), `duo-folded` (1398 x 2034). If the simulator is missing,
     say so; do not substitute another device.
5. Mac: run the native Mac app (`open` the built `.app` with the squeezed samples), size its window
   to about 1440 x 900, and capture `photo` and `batch` with `capture-mac.sh` into
   `store/screenshots/captures/mac/`. The owner may need to click the window when it asks.
6. Run `python3 store/screenshots/compose.py`. It lists any capture still missing. **Look at every
   output image yourself** (open or read each PNG). Reject any that show: the welcome sheet, a
   status bar with the wrong time, placeholder or blank states, a notice chip, clipped controls,
   or anything that differs from how the real app looks. Fix the capture and repeat.
7. Copy the approved outputs into `mac-package/fastlane/screenshots/en-US/` (fastlane picks the
   device from the image size; give files an order prefix `01_`, `02_`, ...). Copy both `iphone`
   and `iphone-medium` outputs. If fastlane rejects or skips the 1206 x 2622 images, tell the owner
   to upload `store/screenshots/output/iphone-medium/` by hand in App Store Connect; that size is
   the required one. Duo sizes are not
   recognised by fastlane: leave them in `store/screenshots/output/` and tell the owner to upload
   those by hand if App Store Connect offers a Duo slot.
8. Commit the debug-only screenshot mode in a pull request, `mac/screenshot-mode`. Do not commit
   images. **STOP**: show the owner the composed images and wait for approval.

## Phase 4. Listing text and upload

1. `python3 mac-package/scripts/make-metadata.py` (it checks Apple's limits).
2. Confirm `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` are set (check only that they are
   non-empty; never print them).
3. **STOP and ask** before uploading. On a yes, from `mac-package`: `fastlane ios metadata`, then
   `fastlane ios screenshots`. Do not run anything that submits for review.
4. Tell the owner the remaining manual items from `store/CHECKLIST.md` (section 2 and 4).

## Phase 5. Only if the owner reports a crash

Run `mac-package/scripts/collect-crash.sh`, read the output, and report what names the lock for
the `0xDEAD10CC` termination (a file path, a database, a process). Do not guess a fix; report the
holder and propose the smallest change.

## Phase 6. Optional visual check of the rounded-corner layout

Build and run the iOS app as "My Mac (Designed for iPad)" (`xcodebuild -destination
'platform=macOS,variant=Designed for iPad'`), put it full screen, and take a screenshot. Compare
the canvas corner with a real macOS window corner and the bottom buttons with the corner (their
centres should sit on the corner's own centre). Report the numbers you see; change
`DisplayCorners.windowRadius` or the 0.77 scale only if they are clearly off.

## Final report

List, per phase: done, not done and why, pull request links, and anything the owner must do.
