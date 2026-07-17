#!/bin/bash
#
# build-dmg.sh
#
# Builds a notarized, Developer-ID-signed DMG for direct distribution
# (spec §9: DMG/Homebrew channel). Requires local one-time setup this
# script does NOT do for you:
#
#   1. A "Developer ID Application" certificate in your keychain, tied to
#      an active Apple Developer Program membership. Xcode > Settings >
#      Accounts > Manage Certificates > + > Developer ID Application.
#   2. Notarization credentials stored once via:
#        xcrun notarytool store-credentials "octosentry-notary" \
#          --apple-id "you@example.com" \
#          --team-id "YOUR_TEAM_ID" \
#          --password "an-app-specific-password"
#      (App-specific password from appleid.apple.com, not your main
#      Apple ID password.)
#
# Usage: scripts/build-dmg.sh [version]
# Output: build/octosentry-<version>.dmg

set -euo pipefail

VERSION="${1:-dev}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/octosentry.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/export-options.plist"
DMG_PATH="$BUILD_DIR/octosentry-$VERSION.dmg"
NOTARY_PROFILE="octosentry-notary"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving (Release configuration)"
xcodebuild archive \
  -project "$PROJECT_DIR/octosentry.xcodeproj" \
  -scheme octosentry \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH"

cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
</dict>
</plist>
PLIST

echo "==> Exporting (Developer ID)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

APP_PATH="$EXPORT_PATH/octosentry.app"

echo "==> Notarizing"
DMG_STAGING="$BUILD_DIR/staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "octosentry" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"

echo "==> Done: $DMG_PATH"
