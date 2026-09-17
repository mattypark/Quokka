#!/usr/bin/env bash
# Captures App Store screenshots at the one size Apple still requires.
#
# Since 2025 only 6.9" iPhone (1320x2868) is mandatory -- Apple scales the rest -- so this
# uses an iPhone 17 Pro Max and nothing else. Its own device, not the one run.sh uses, because
# shutting down a simulator somebody else is looking at is rude and this one is 6.9".
#
# Every shot is the app in use. Guideline 2.3.3 rejects screenshots of a splash or a login
# screen, which is the classic first-timer rejection.
#
# The library is seeded by seed-web-demo.mjs, not seed-inbox.mjs. Screenshots are published,
# and the dev fixture's tiles are real YouTube cover art.
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_NAME="Quokka Shots"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
BUNDLE_ID="com.matthewpark.quokka"
APP_GROUP="group.com.matthewpark.quokka"
OUT="assets/screenshots"

SHOTS=(
  "01-library|-quokkaTab library"
  "02-idea|-quokkaTab playlists -quokkaScreen idea"
  "03-playlists|-quokkaTab playlists"
  "04-planner|-quokkaTab today"
  "05-settings|-quokkaTab settings"
)

DEVICE=$(xcrun simctl list devices | grep "$DEVICE_NAME (" | grep -oE "[0-9A-F-]{36}" | head -1 || true)
if [[ -z "$DEVICE" ]]; then
  RUNTIME=$(xcrun simctl list runtimes | grep -oE "com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+" | tail -1)
  DEVICE=$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME")
  echo "created $DEVICE_NAME ($DEVICE)"
fi

cleanup() {
  echo "==> shutting down $DEVICE_NAME"
  xcrun simctl shutdown "$DEVICE" 2>/dev/null || true
}
trap cleanup EXIT INT TERM HUP

echo "==> generating and building"
(cd ios && xcodegen generate >/dev/null)
xcodebuild -project ios/Quokka.xcodeproj -scheme Quokka \
  -destination "id=$DEVICE" -derivedDataPath ios/build build \
  2>&1 | grep -E "error:|BUILD" || true

APP=$(find ios/build/Build/Products -name "Quokka.app" -maxdepth 3 | head -1)
[[ -n "$APP" ]] || { echo "no Quokka.app was produced" >&2; exit 1; }

echo "==> booting"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true
xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE" "$APP"

# A clean status bar. The real one shows a simulator clock, a partial battery and no carrier,
# and a screenshot carrying that reads as a screenshot of a simulator rather than of an app.
xcrun simctl status_bar "$DEVICE" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 2>/dev/null || true

echo "==> first launch, to create the containers"
xcrun simctl launch "$BUNDLE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || \
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -quokkaTab library >/dev/null
sleep 4
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true

GROUP_DIR=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" groups 2>/dev/null \
  | grep "$APP_GROUP" | sed "s/^$APP_GROUP[[:space:]]*//" || true)
if [[ -n "$GROUP_DIR" ]]; then
  echo "==> seeding"
  node scripts/seed-web-demo.mjs "$GROUP_DIR/Inbox"
fi

# Warm once so the tiles have resolved before anything is captured.
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -quokkaTab library -quokkaSeedIdeas YES >/dev/null
sleep 20
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
sleep 1

mkdir -p "$OUT"
for entry in "${SHOTS[@]}"; do
  IFS="|" read -r out args <<< "$entry"
  # shellcheck disable=SC2086
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" $args -quokkaSeedIdeas YES >/dev/null
  # Long enough for the arrival animations to finish. A screenshot caught mid-stagger has
  # half its tiles at 98% scale and reads as a rendering bug.
  sleep 6
  xcrun simctl io "$DEVICE" screenshot "$OUT/$out.png" >/dev/null 2>&1
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  sleep 1
  printf "    %-14s %s\n" "$out" "$(sips -g pixelWidth -g pixelHeight "$OUT/$out.png" 2>/dev/null | awk '/pixel/{printf "%s ", $2}')"
done

echo "==> done -- $OUT"
