#!/usr/bin/env bash
# Records the three screens the marketing site shows, straight off the simulator.
#
# The site's app section is the strongest argument the page has, so what it shows has to be
# the build that ships rather than a mockup drawn next to it. This captures the real app, the
# real seeded library, and the real arrival animations, then encodes what the web wants:
# h264 with a moov atom at the front so it starts playing before it has finished downloading,
# plus a poster frame for the moment before it does.
#
#   scripts/capture-web-demos.sh
#
# The simulator is shut down on the way out, including on an interrupt. That is not optional:
# a booted runtime leaves mediaanalysisd running and it has been measured at 691% CPU on this
# machine.
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_NAME="Quokka Sim"
BUNDLE_ID="com.matthewpark.quokka"
APP_GROUP="group.com.matthewpark.quokka"
OUT="web/public/demos"
SECONDS_EACH="${SECONDS_EACH:-7}"
# Kept rather than temporary: when a clip comes out empty the only way to tell whether the
# recorder or the encoder was at fault is to still have what the recorder produced.
RAW="build/demo-captures"

# Screen, launch arguments, output name. Every one of these is a screen that exists today --
# the transcript UI does not, so it is not here pretending to.
# Screen, launch arguments, output name, seconds to let it settle before recording.
#
# The idea deep-link needs the tab as well as the screen: openForScreenshot() lives inside
# PlaylistsView, so with the tab left at its default the view never mounts and the sheet never
# opens -- which silently yields a second copy of the planner.
#
# The library settles for far longer than the others because its tiles arrive empty. Thumbnail
# enrichment has to either land or give up before the grid is worth filming: a resolved tile is
# a picture, and a refused one falls back to a title set in a serif, which is the app's own
# design. What is not worth filming is the grey rectangle in between.
SHOTS=(
  "library|-quokkaTab library|library|8"
  "idea|-quokkaTab playlists -quokkaScreen idea|idea|4"
  "planner|-quokkaTab today|planner|4"
)

DEVICE=$(xcrun simctl list devices | grep "$DEVICE_NAME (" | grep -oE "[0-9A-F-]{36}" | head -1 || true)
if [[ -z "$DEVICE" ]]; then
  RUNTIME=$(xcrun simctl list runtimes | grep -oE "com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+" | tail -1)
  DEVICE=$(xcrun simctl create "$DEVICE_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$RUNTIME")
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

# The App Group container does not exist until the app has run once, and the seed writes into
# it -- so the first launch is thrown away on purpose.
echo "==> first launch, to create the containers"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -quokkaTab library >/dev/null
sleep 4
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true

GROUP_DIR=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" groups 2>/dev/null \
  | grep "$APP_GROUP" | sed "s/^$APP_GROUP[[:space:]]*//" || true)
if [[ -n "$GROUP_DIR" ]]; then
  # seed-web-demo, not seed-inbox. The dev fixture gets its pictures from real YouTube ids,
  # and filming somebody else's cover art for a public marketing page is publication of it.
  echo "==> seeding the inbox"
  node scripts/seed-web-demo.mjs "$GROUP_DIR/Inbox"
fi

mkdir -p "$OUT" "$RAW"

# Thumbnails are fetched once and then live in the database, so a warm-up pass means the grid
# can be filmed arriving already full instead of arriving grey and filling in.
echo "==> warming the library, so the tiles have pictures to arrive with"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -quokkaTab library -quokkaSeedIdeas YES >/dev/null
sleep 24
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
sleep 1

for entry in "${SHOTS[@]}"; do
  IFS="|" read -r name args out settle <<< "$entry"
  echo "==> recording $name"

  # The recorder starts BEFORE the app does, and this is the whole trick.
  #
  # simctl's recordVideo only emits a frame when the display actually changes. Point it at a
  # screen that has finished settling and it produces a single frame, encodes it without
  # complaint, and hands back a "video" that nobody notices is one frame until it is on the
  # marketing site. Filming the launch means every clip has the splash, the wordmark spelling
  # itself out and the grid arriving in it -- real motion, from the real build, with no touch
  # automation to fake.
  xcrun simctl io "$DEVICE" recordVideo --codec h264 --force "$RAW/$out.mov" >/dev/null 2>&1 &
  REC=$!
  sleep 2

  # shellcheck disable=SC2086
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" $args -quokkaSeedIdeas YES >/dev/null
  sleep "$(( SECONDS_EACH + 2 ))"

  # SIGINT, not SIGKILL: recordVideo finalises the file on an interrupt and leaves a truncated
  # one on a kill.
  kill -INT "$REC" 2>/dev/null || true
  wait "$REC" 2>/dev/null || true

  have=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$RAW/$out.mov" 2>/dev/null || echo 0)
  echo "    captured ${have:-0}s"
  if ! awk -v d="${have:-0}" 'BEGIN { exit !(d > 1) }'; then
    echo "    !! $out is a single frame -- the screen never moved" >&2
  fi

  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  sleep 1
done

echo "==> encoding for the web"
for entry in "${SHOTS[@]}"; do
  IFS="|" read -r name args out settle <<< "$entry"
  src="$RAW/$out.mov"
  [[ -f "$src" ]] || { echo "!! $out never recorded" >&2; continue; }

  # 720 wide is plenty: the phone renders at 248 CSS pixels, so this is still better than 2x.
  # yuv420p because anything else will not decode in Safari, and +faststart so playback can
  # begin before the file has finished arriving.
  #
  # -t sits AFTER -i on purpose. As an input option it seeks, and seeking past the end of a
  # recording the simulator cut short produces a zero-byte file rather than an error.
  ffmpeg -y -loglevel error -i "$src" -t "$SECONDS_EACH" \
    -vf "scale=720:-2,fps=30" -an \
    -c:v libx264 -crf 27 -preset slow -pix_fmt yuv420p -movflags +faststart \
    "$OUT/$out.mp4"

  # The poster comes from the END of the clip, not the beginning. The recording opens on the
  # launch -- a white screen and a wordmark spelling itself out -- so an early frame is a
  # poster of nothing. The last second is the settled screen, which is what should be sitting
  # there before the video starts playing.
  ffmpeg -y -loglevel error -sseof -1.5 -i "$src" -frames:v 1 \
    -vf "scale=720:-2,format=yuvj420p" -q:v 6 "$OUT/$out.jpg"

  for artefact in "$OUT/$out.mp4" "$OUT/$out.jpg"; do
    if [[ ! -s "$artefact" ]]; then
      echo "!! $artefact is empty -- raw capture kept at $src" >&2
    fi
  done

  printf "    %-10s %6s KB video  %5s KB poster\n" "$out" \
    "$(( $(stat -f%z "$OUT/$out.mp4") / 1024 ))" \
    "$(( $(stat -f%z "$OUT/$out.jpg") / 1024 ))"
done

echo "==> done"
