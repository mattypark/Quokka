#!/usr/bin/env bash
# Archives Quokka and exports an .ipa for App Store Connect.
#
#   scripts/testflight.sh              # archive + export
#   scripts/testflight.sh --upload     # and upload it
#
# Uploading needs an app-specific password in the keychain:
#   xcrun notarytool store-credentials  # or set ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Quokka"
ARCHIVE="build/Quokka.xcarchive"
EXPORT="build/export"
UPLOAD=0
[[ "${1:-}" == "--upload" ]] && UPLOAD=1

# Preflight. These are the two things that fail an upload after a five-minute archive rather
# than before it, which is the expensive way to find out.
ICON_DIR="ios/Quokka/Resources/Assets.xcassets/AppIcon.appiconset"
if ! ls "$ICON_DIR"/*.png >/dev/null 2>&1; then
  echo "!! No app icon in $ICON_DIR — App Store Connect rejects the build." >&2
  echo "   1024x1024, no alpha, no rounded corners." >&2
  exit 1
fi
if git ls-files --error-unmatch ios/Quokka/Resources/Fonts/KeeponTruckin.ttf >/dev/null 2>&1; then
  echo "!! KeeponTruckin.ttf is personal-use licensed and is still in the bundle." >&2
  echo "   See docs/TESTFLIGHT.md. Submitting with it is a licence violation." >&2
  exit 1
fi

echo "==> generating project"
(cd ios && xcodegen generate >/dev/null)

echo "==> archiving"
rm -rf "$ARCHIVE" "$EXPORT"
xcodebuild archive \
  -project ios/Quokka.xcodeproj \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  | grep -E "error:|warning: the|ARCHIVE" || true

[[ -d "$ARCHIVE" ]] || { echo "archive failed" >&2; exit 1; }

cat > build/ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>R43H5332KH</string>
  <key>uploadSymbols</key><true/>
  <key>destination</key><string>export</string>
</dict>
</plist>
PLIST

echo "==> exporting"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates \
  | grep -E "error:|EXPORT" || true

IPA=$(find "$EXPORT" -name "*.ipa" | head -1)
[[ -n "$IPA" ]] || { echo "no .ipa produced" >&2; exit 1; }
echo "==> $IPA"

if [[ "$UPLOAD" -eq 1 ]]; then
  echo "==> uploading"
  xcrun altool --upload-app -f "$IPA" -t ios --apiKey "${ASC_KEY_ID:?set ASC_KEY_ID}" --apiIssuer "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
else
  echo
  echo "Not uploaded. Either:"
  echo "  open $ARCHIVE          # then Distribute App in Xcode Organizer"
  echo "  scripts/testflight.sh --upload"
fi
