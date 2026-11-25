# What is left before submission

Items marked **you** need your Apple ID, your decision or your hands. Everything else is done in
this folder or in the app.

## 1. Content (this folder)

- [x] iOS listing text, keywords, review notes, privacy answers: `listing/ios.md`
- [x] Mac listing text: `listing/mac.md`
- [x] Privacy policy text: `privacy-policy.md`
- [x] Screenshot builder, captions and shot list: `screenshots/`
- [ ] **you** Capture the screens in `screenshots/captures/SHOTLIST.md` on the current build, run
      `python3 compose.py`, and look at every output before uploading.
- [x] **you** Host the privacy policy at a public URL: https://chambersandlight.com/stillscope/privacy/
      and fill in the date and contact in it.
- [x] **you** Decide the support URL: https://chambersandlight.com/stillscope/support/
- [ ] **you** Fill in the review contact (name, phone, email) in `listing/ios.md`.

## 2. App Store Connect, iOS app (you)

- [ ] App record exists (StillScope, `com.chambersandlight.stillscope`): yes, from TestFlight.
- [ ] Version 1.0: paste the description, promo text, keywords, subtitle, what's new.
- [ ] Screenshots: upload the iPhone 6.9" set and the iPad 13" set. For iPhone Duo, check the
      screenshot page: Apple lists Duo sizes (1398x2034 / 2034x1398 outer, 2007x2853 /
      2853x2007 inner) but third-party reports disagree on whether the uploader accepts them yet.
      Upload them if the slot is there; if not, the iPhone set is enough.
- [ ] App Privacy: Data Not Collected.
- [ ] Age rating questionnaire: all "None" gives 4+.
- [ ] Pricing and availability (Free or a tier) and territories.
- [ ] Trader status: the EU banner in App Store Connect asks whether you are a trader. A paid
      app or a business account usually is. Required for EU distribution.
- [ ] Export compliance: already declared in the app (no questions at upload).
- [ ] Content rights: you own or are licensed for everything in the app.
- [ ] Select the build: pick the Xcode Cloud build you tested. Build numbers are set by
      Xcode Cloud.
- [ ] Beta App Review for external TestFlight is separate and can be pending; it does not block
      the App Store submission.
- [ ] Submit for review. Choose manual release or automatic.

## 3. iOS app: things to check on a device first

- [ ] Photos permission flow on a fresh install (add-only on first save; read when "Find
      squeezed photos" is switched on).
- [ ] The Share extension and the Photos editing extension both appear and save.
- [ ] Rotate and fold/unfold on a Duo; landscape bar and slider on iPad.
- [ ] A batch of a few dozen photos saves without running out of memory.
- [ ] The auto-detect numbers (the "Looked at X of Y" notice) match what you expect.
- [ ] The slider shows lens preset names. They are third-party brand names. They are not in the
      listing or keywords, but if you want no risk, rename them to generic labels before submitting.

## 4. Mac App Store (separate work)

The macOS app has not been through any of this yet:

- [x] One purchase across Apple platforms: the Mac app now uses the iOS bundle ID
      (`com.chambersandlight.stillscope`), so it goes in the same App Store Connect record as a
      macOS platform, with universal purchase. A person who buys once has it on every Apple device.
- [ ] **you** In App Store Connect, open the StillScope app and add the macOS platform (the "+"
      beside the platform list, then macOS). Do not create a second app. The name and price carry
      over.
- [ ] **you** Make sure the App ID `com.chambersandlight.stillscope` is enabled for macOS (Xcode's
      automatic signing does this), and create a Mac App Store distribution certificate and
      installer certificate (Xcode can do this under Signing).
- [x] Add a privacy manifest (`PrivacyInfo.xcprivacy`, no tracking, no collected data) to the
      Mac target; it has none.
- [x] `ITSAppUsesNonExemptEncryption = NO` is in the Mac Info.plist, so uploads do not ask.
- [ ] Confirm the sandbox entitlements: it has app-sandbox and user-selected read/write only,
      which is all it needs.
- [ ] Archive in Xcode (Product > Archive > Distribute > App Store Connect). Xcode Cloud has no
      Mac workflow yet.
- [ ] On the macOS version of the record, paste `listing/mac.md` and upload the 2880 x 1800
      screenshots.

## 5. Not covered

One purchase works across Apple platforms only. Microsoft Store purchases are separate and cannot
be linked to an App Store purchase; if you want Windows buyers covered, it would need its own price
or a free tier. Windows and the website are not part of this package; ask if you want them.
