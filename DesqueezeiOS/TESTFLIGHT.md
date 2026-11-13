# Sending StillScope to TestFlight

The project is set up for upload. What is left happens in App Store Connect
and Xcode, signed in as the team's account holder.

## What the project already has

| Setting            | Value                                      |
|--------------------|--------------------------------------------|
| App name           | StillScope                                 |
| Bundle identifier  | `com.chambersandlight.stillscope`          |
| Team               | `FZ6W4MM7UN`, signing managed by Xcode     |
| Version / build    | 1.0 (2)                                    |
| Category           | Photography                                |
| App icon           | 1024 px, light and dark, no transparency   |
| Encryption         | Declared as none, so no compliance prompt  |
| Privacy manifest   | No tracking, no data collected             |
| Photo library      | Add-only permission, with its reason text  |
| iPad orientations  | All four, as multitasking requires         |

The bundle identifier is permanent once a build is uploaded. Change it in
`generate_project.py` before the first upload if you want a different one.

## One-time setup

1. Go to [App Store Connect](https://appstoreconnect.apple.com), open **Apps**,
   and press **+** then **New App**.
2. Platform **iOS**, name **StillScope**, your primary language.
3. For **Bundle ID**, pick `com.chambersandlight.stillscope`. If it is not in
   the list, build the app once in Xcode on a device or simulator so Xcode
   registers it, then reload the page.
4. SKU can be anything, for example `stillscope-ios`. Create the app.

If the name StillScope is taken on the App Store, App Store Connect says so
here. The name on the store can differ from the name under the icon.

## Automatic builds

Xcode Cloud now does the upload. Every push to `main` that changes a file
under `DesqueezeiOS/` is archived and sent to the Internal Test group, about
ten to fifteen minutes later. To start one by hand, open Xcode's Report
navigator, choose the Cloud tab, and use Start Build on the Default workflow.

The manual steps below still work and are only needed if Xcode Cloud is
unavailable.

## Each upload by hand

1. In Xcode, set the run destination to **Any iOS Device (arm64)**.
2. Choose **Product › Archive**. The Organizer window opens when it finishes.
3. Select the archive, press **Distribute App**, choose **TestFlight & App
   Store** (or **TestFlight Internal Only** for your own team), and follow the
   prompts with the defaults.
4. Wait for the processing email, usually five to fifteen minutes.

Every upload needs a build number higher than the last. Raise
`CURRENT_PROJECT_VERSION` in `generate_project.py`, run the generator, and
archive again.

## Adding testers

- **Internal testers** are people on your App Store Connect team, up to 100.
  Add them under **TestFlight › Internal Testing**. Builds reach them at once.
- **External testers** are anyone with an email address or the public link, up
  to 10,000. The first build for an external group goes through a short Beta
  App Review, usually within a day.

External testing asks for the following. Text you can paste:

**Beta app description**

> StillScope corrects photographs shot through anamorphic lenses. Choose a
> photo, set the squeeze factor on the slider, and save the widened result to
> your library. Several photos can be corrected together as a batch.

**What to test**

> Open one photo and drag the factor slider: the preview should follow at
> once and snap to the lens presets. Hold between two presets for two seconds
> to fine-tune. Tap the photo to inspect it at 1:1. Save, then check the
> result in Photos. Pick several photos to try the batch grid. In Settings,
> turn on the 5% matte and save again. On an iPhone Duo, fold and unfold
> while a photo is open.

**Feedback email**: your own address.

**Privacy policy URL** is required for external testing. A page stating that
the app collects no data and processes photos on the device is enough.

## Things that can stop an upload

- **Xcode version.** The app targets iOS 27. Upload with the Xcode that ships
  the iOS 27 SDK. Apple accepts TestFlight builds from beta Xcode during a
  beta period, but App Store submissions need the release version.
- **Name or bundle identifier already in use.** App Store Connect reports
  either one in the New App form.
- **Agreements.** App Store Connect blocks uploads until the latest Apple
  Developer Program agreement is accepted.
