#!/usr/bin/env bash
# Builds Quokka, then screenshots every screen on its own simulator -- one boot, one install,
# one seed, a launch per screen -- and shuts the simulator down, always.
#
#   scripts/tour.sh                  # every screen, sample data, into build/screenshots/tour
#   scripts/tour.sh --imports        # also paste a real Are.na channel, Pinterest board and
#                                    # TikTok first, so the wall fills with real pictures
#
# The transcripts on the breakdown screens are samples (-quokkaSampleTranscripts), and every
# screen showing one says so. Real transcription needs a phone -- see docs/TESTING.md.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="build/screenshots/tour"
BUNDLE_ID="com.matthewpark.quokka"
APP_GROUP="group.com.matthewpark.quokka"
DEVICE_NAME="Quokka Sim"
IMPORTS=0
[[ "${1:-}" == "--imports" ]] && IMPORTS=1

LINKS="https://www.are.na/lesha-berezovskiy/photography-research,https://www.pinterest.com/pinterest/official-news/,https://www.tiktok.com/@scout2015/video/6718335390845095173"

# A device of our own, so no other project's simulator is ever touched.
DEVICE=$(xcrun simctl list devices | grep "$DEVICE_NAME (" | grep -oE "[0-9A-F-]{36}" | head -1 || true)
if [[ -z "$DEVICE" ]]; then
  RUNTIME=$(xcrun simctl list runtimes | grep -oE "com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+" | tail -1)
  DEVICE=$(xcrun simctl create "$DEVICE_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$RUNTIME")
fi
# A booted simulator's mediaanalysisd has been measured pegging a core, so it never outlives
# the run -- not on success, not on Ctrl-C.
trap 'echo "==> shutting down $DEVICE_NAME"; xcrun simctl shutdown "$DEVICE" 2>/dev/null || true' EXIT INT TERM HUP

echo "==> building"
(cd ios && xcodegen generate >/dev/null)
xcodebuild -project ios/Quokka.xcodeproj -scheme Quokka -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/build build 2>&1 | grep -E "error:|BUILD" || true
APP=ios/build/Build/Products/Debug-iphonesimulator/Quokka.app
[[ -d "$APP" ]] || { echo "no Quokka.app was produced" >&2; exit 1; }

echo "==> booting"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true
xcrun simctl status_bar "$DEVICE" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE" "$APP"
GROUP_DIR=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" groups | grep "$APP_GROUP" | sed "s/^$APP_GROUP[[:space:]]*//")
node scripts/seed-inbox.mjs "$GROUP_DIR/Inbox"

rm -rf "$OUT" && mkdir -p "$OUT"
shot() {
  local name="$1"; shift
  local wait="$1"; shift
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -quokkaSeedIdeas YES "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$DEVICE" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "  $name"
}

echo "==> screens"
shot 00-onboarding 3
if [[ "$IMPORTS" -eq 1 ]]; then
  # Long first wait: a hundred pictures arrive in passes of 25.
  shot 01-home 75 -quokkaTab home -quokkaSampleTranscripts YES -quokkaAddLinks "$LINKS"
else
  shot 01-home 12 -quokkaTab home -quokkaSampleTranscripts YES
fi
shot 02-home-wall 6 -quokkaTab home -quokkaSampleTranscripts YES -quokkaScrollTo wall
shot 03-library 5 -quokkaTab library -quokkaSampleTranscripts YES
shot 04-studio 4 -quokkaTab studio -quokkaSampleTranscripts YES
shot 05-studio-ideas 4 -quokkaTab studio -quokkaPane ideas -quokkaSampleTranscripts YES
shot 06-playlist 5 -quokkaTab studio -quokkaScreen playlist -quokkaSampleTranscripts YES
shot 07-idea 5 -quokkaTab studio -quokkaScreen idea -quokkaSampleTranscripts YES
shot 08-breakdown 5 -quokkaTab home -quokkaScreen item -quokkaSampleTranscripts YES
shot 09-transcript 5 -quokkaTab home -quokkaScreen item -quokkaItemTab transcript -quokkaSampleTranscripts YES
shot 10-save 5 -quokkaTab home -quokkaScreen item -quokkaItemTab save -quokkaSampleTranscripts YES

echo "==> screenshots in $OUT"
ls "$OUT"
