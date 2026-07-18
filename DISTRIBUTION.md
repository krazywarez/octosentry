# Distribution

octosentry ships as a notarized DMG and via Homebrew — no App Store
distribution. Same entitlements either way; there's only one channel.

## DMG

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
the corresponding GitHub Release:

```bash
gh release upload 1.0.0 build/octosentry-1.0.0.dmg
```

The update checker (`UpdateStore`) links there.

## Homebrew

Published at [zerolabsco/homebrew-tap](https://github.com/zerolabsco/homebrew-tap).
Users install via:

```bash
brew tap zerolabsco/tap
brew install --cask octosentry
```

Per release, after uploading the new DMG to its GitHub Release:

1. `shasum -a 256 build/octosentry-<version>.dmg`
2. Update `version` and `sha256` in [Casks/octosentry.rb](Casks/octosentry.rb)
   (kept here for reference — the canonical copy lives in the tap repo).
3. Copy the updated file into a local clone of `zerolabsco/homebrew-tap`,
   commit, and push.

## Version bumps

`MARKETING_VERSION` in the Xcode project must match the git tag for each
release — the update checker compares `CFBundleShortVersionString`
against the latest GitHub Release's tag name.
