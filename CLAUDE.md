# Working in this repository

## Merging

When a change is committed and pushed, open a pull request and merge it into
`main` without waiting to be asked. The owner has given standing approval for
this.

Before merging:

- Wait for CI on the pull request's head commit. Merge only if it is green.
  If it is red, fix the cause first.
- Do not merge over a merge conflict or an unresolved review comment. Resolve
  it, or say what blocks it.

After merging, tell the owner it is merged and give the command to update a
local clone:

```
git checkout main && git pull origin main
```

## Verification

The iOS and macOS app targets cannot be built outside Xcode. Say plainly when
a change was only syntax-checked and not compiled or run.

Core logic lives in `DesqueezeiOS/DesqueezeCore` and is tested with:

```
cd DesqueezeiOS/DesqueezeCore && swift test
```

## iOS project file

`DesqueezeiOS/Desqueeze.xcodeproj/project.pbxproj` is generated. After adding
or removing a Swift file or asset in `DesqueezeiOS/Desqueeze`, regenerate it:

```
cd DesqueezeiOS && python3 generate_project.py "$PWD"
```

The project has three targets: the app, and the `PhotoEdit` and `Share`
extensions under `DesqueezeiOS/Extensions`. The generator lists which app
files the extensions also compile, in `SHARED`.

The owner's signing team is set in the generator. Do not hand-edit the project
file; change the generator instead.

## iOS delivery

Xcode Cloud archives the iOS app and sends it to the Internal Test group in
TestFlight on every push to `main` that changes a file under `DesqueezeiOS/`.
The workflow is named Default, in the Xcode Cloud product named Desqueeze.

- Every merge that touches `DesqueezeiOS/` ships a build to testers. Group
  related iOS changes into one pull request so testers are not sent a string
  of half-steps, and so the monthly compute allowance lasts.
- Xcode Cloud assigns build numbers. `CURRENT_PROJECT_VERSION` in
  `generate_project.py` only matters for an archive made by hand in Xcode.
- External testers do not get builds automatically. The owner adds a build to
  the External Testers group in App Store Connect when one is worth sharing.
- Changes outside `DesqueezeiOS/`, such as Windows, web, brand or docs, do
  not start an iOS build.

## Adding an app extension

Xcode Cloud cannot register a new bundle identifier, and its export step
fails with "Automatic signing cannot register bundle identifier" until one
exists. Before merging a new extension target, have the owner register its
identifier at developer.apple.com under Identifiers, as an explicit App ID
with no capabilities. The two existing extensions are registered:
`com.chambersandlight.stillscope.share` and
`com.chambersandlight.stillscope.photoedit`.

Compile and archive errors show on the Xcode Cloud build page. Export and
signing errors do not: they are only in the build's downloadable "Logs for
Desqueeze archive", in `xcodebuild-export-archive.log`.
