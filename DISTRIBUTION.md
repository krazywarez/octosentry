# Distribution

octosentry ships on two channels with a single codebase and identical
entitlements (spec §9) — the only divergence is signing method at export
time and whether the update checker runs.

## App Store

1. Requires an active Apple Developer Program membership and an **Apple
   Distribution** certificate (Xcode > Settings > Accounts > Manage
   Certificates).
2. Create the app record in [App Store Connect](https://appstoreconnect.apple.com)
   with bundle ID `net.cleberg.octosentry`.
3. Archive: Product > Archive in Xcode (Release configuration).
4. In the Organizer, Distribute App > App Store Connect > Upload.
5. Complete the app listing (screenshots, description, privacy nutrition
   label — [PrivacyInfo.xcprivacy](octosentry/PrivacyInfo.xcprivacy) already
   declares no tracking and no collected data) and submit for review.

The update checker (`UpdateStore`) detects the App Store receipt at
runtime and never runs on this build — no code changes needed per release.

## DMG (direct distribution)

Requires a **Developer ID Application** certificate and notarization
credentials stored once locally:

```bash
xcrun notarytool store-credentials "octosentry-notary" \
  --apple-id "you@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "an-app-specific-password"
```

(App-specific password from [appleid.apple.com](https://appleid.apple.com),
not your main Apple ID password.)

Then, per release:

```bash
scripts/build-dmg.sh 1.0.0
```

This archives, exports with Developer ID signing, notarizes, staples the
ticket, and produces `build/octosentry-1.0.0.dmg`. Attach that file to
the corresponding GitHub Release (`gh release create 1.0.0 build/octosentry-1.0.0.dmg`)
— the update checker links there.

## Homebrew

Not published yet. [Casks/octosentry.rb](Casks/octosentry.rb) is a
template — to actually publish it:

1. Create a `zerolabsco/homebrew-tap` repo.
2. Copy the cask there, filling in the real `sha256` of the released DMG
   (`shasum -a 256 octosentry-1.0.0.dmg`).
3. Users install via `brew tap zerolabsco/tap && brew install --cask octosentry`.

## Version bumps

`MARKETING_VERSION` in the Xcode project must match the git tag for each
release — the update checker compares `CFBundleShortVersionString`
against the latest GitHub Release's tag name.
