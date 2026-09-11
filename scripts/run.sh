#!/usr/bin/env bash
# Builds Allim, runs it on a dedicated simulator, screenshots it, and shuts the simulator
# back down.
#
# That last part is not optional. A booted simulator runtime leaves mediaanalysisd running,
# and it has been seen pegging a core.
#
#   scripts/run.sh                # launch empty, screenshot, shut down
#   scripts/run.sh --seed         # inject sample inbox records first, to see the drain path
#   scripts/run.sh --export       # plant a synthetic Instagram export and import it
#   scripts/run.sh --ideas        # seed sample playlists and ideas
#   scripts/run.sh --relaunch     # relaunch after the first pass, to prove data persisted
#   scripts/run.sh --keep         # leave the simulator up (it will run hot -- see below)
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_NAME="Allim Sim"
BUNDLE_ID="com.matthewpark.allim"
APP_GROUP="group.com.matthewpark.allim"
SHOTS="build/screenshots"
KEEP=0
SEED=0
RELAUNCH=0
EXPORT=0
IDEAS=0
TAB=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    --seed) SEED=1; shift ;;
    --relaunch) RELAUNCH=1; shift ;;
    --export) EXPORT=1; shift ;;
    --ideas) IDEAS=1; shift ;;
    --tab) TAB="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

# A device of our own. Other simulators on this machine belong to other projects, and
# shutting one of those down would kill someone else's work.
DEVICE=$(xcrun simctl list devices | grep "$DEVICE_NAME (" | grep -oE "[0-9A-F-]{36}" | head -1 || true)
if [[ -z "$DEVICE" ]]; then
  RUNTIME=$(xcrun simctl list runtimes | grep -oE "com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+" | tail -1)
  DEVICE=$(xcrun simctl create "$DEVICE_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$RUNTIME")
  echo "created $DEVICE_NAME ($DEVICE)"
fi

cleanup() {
  if [[ "$KEEP" -eq 0 ]]; then
    echo "shutting down $DEVICE_NAME"
    xcrun simctl shutdown "$DEVICE" 2>/dev/null || true
  else
    # A booted runtime spawns mediaanalysisd, which has been measured at 691% CPU and 201F
    # on this machine. --keep is a real option, but it is never the quiet one.
    echo ""
    echo "  !!  $DEVICE_NAME LEFT BOOTED (--keep)"
    echo "  !!  mediaanalysisd will peg a core until you run:"
    echo "  !!    xcrun simctl shutdown $DEVICE"
    echo ""
  fi
}

# EXIT alone is not enough. An interrupted run (Ctrl-C, a killed parent) can skip it and
# leave the simulator booted and hot with nothing having said so.
trap cleanup EXIT INT TERM HUP

echo "==> generating project"
(cd ios && xcodegen generate >/dev/null)

echo "==> building"
xcodebuild -project ios/Allim.xcodeproj -scheme Allim \
  -destination "id=$DEVICE" -derivedDataPath ios/build build \
  2>&1 | grep -E "error:|BUILD" || true

APP=$(find ios/build/Build/Products -name "Allim.app" -maxdepth 3 | head -1)
if [[ -z "$APP" ]]; then echo "no Allim.app was produced" >&2; exit 1; fi

echo "==> booting"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true

xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE" "$APP"

if [[ "$SEED" -eq 1 ]]; then
  # Writes straight into the App Group inbox, which is exactly what the share extension
  # does. It exercises the whole drain path -- coordinated read, canonicalisation, delete --
  # without needing to drive another app's share sheet by hand.
  GROUP_DIR=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" groups 2>/dev/null \
    | grep "$APP_GROUP" | sed "s/^$APP_GROUP[[:space:]]*//" || true)
  if [[ -n "$GROUP_DIR" ]]; then
    node scripts/seed-inbox.mjs "$GROUP_DIR/Inbox"
  else
    echo "!! no App Group container yet -- launch once, then re-run with --seed" >&2
  fi
fi

LAUNCH_ARGS=()
if [[ -n "$TAB" ]]; then LAUNCH_ARGS+=(-allimTab "$TAB"); fi
if [[ "$IDEAS" -eq 1 ]]; then LAUNCH_ARGS+=(-allimSeedIdeas YES); fi
if [[ "$EXPORT" -eq 1 ]]; then
  # The document picker cannot be driven from a script, so the fixture is planted in the app's
  # own Documents and a debug-only launch argument points the importer straight at it.
  # Everything after that -- the walk, the parse, the dedupe, the insert -- is the real path.
  DATA_DIR=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data 2>/dev/null || true)
  if [[ -n "$DATA_DIR" ]]; then
    rm -rf "$DATA_DIR/Documents/TestExport"
    node scripts/seed-export.mjs "$DATA_DIR/Documents/TestExport"
    # Append, never assign -- assigning here silently discarded --tab.
    LAUNCH_ARGS+=(-allimImportFixture TestExport)
  else
    echo "!! no data container yet -- launch once, then re-run with --export" >&2
  fi
fi

mkdir -p "$SHOTS"
echo "==> launching"
# The +"..." form is required: under `set -u`, expanding an empty array is an error.
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" ${LAUNCH_ARGS[@]+"${LAUNCH_ARGS[@]}"} >/dev/null

# The wordmark spells itself out over roughly half a second, so the splash is caught early
# and the library after it has settled.
sleep 1
xcrun simctl io "$DEVICE" screenshot "$SHOTS/01-splash.png" >/dev/null 2>&1 || true
sleep 3
xcrun simctl io "$DEVICE" screenshot "$SHOTS/02-library.png" >/dev/null 2>&1 || true

if [[ "$RELAUNCH" -eq 1 ]]; then
  # The inbox is drained and deleted by the first launch, so anything still on screen after
  # this came out of the database rather than out of the App Group. That is the whole point:
  # it distinguishes "rendered what it was handed" from "actually persisted".
  echo "==> relaunching to check persistence"
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  sleep 1
  # Same arguments as the first launch, or --tab is silently lost on the relaunch capture.
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" ${LAUNCH_ARGS[@]+"${LAUNCH_ARGS[@]}"} >/dev/null
  sleep 4
  xcrun simctl io "$DEVICE" screenshot "$SHOTS/03-after-relaunch.png" >/dev/null 2>&1 || true
fi

echo "==> screenshots in $SHOTS"
ls -la "$SHOTS"
