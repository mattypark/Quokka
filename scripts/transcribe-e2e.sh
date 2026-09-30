#!/usr/bin/env bash
# Proves the transcript ladder end to end on the simulator: pastes a real post, transcribes
# it through the live worker, and reports what happened at each step. Shuts the simulator
# down, always.
#
#   scripts/transcribe-e2e.sh                                    # the default TikTok
#   scripts/transcribe-e2e.sh https://www.instagram.com/reel/…   # an Instagram reel
#   scripts/transcribe-e2e.sh https://www.reddit.com/r/…/comments/…  # a Reddit video
#
# Expected on the simulator: config fetched, media found by the web view, download OK, then
# "No speech model" -- the simulator cannot download Apple's speech models. On a phone the
# same run finishes with a transcript. See docs/TESTING.md.
set -uo pipefail
cd "$(dirname "$0")/.."

URL="${1:-https://www.tiktok.com/@scout2015/video/6718335390845095173}"
# The platform the app should transcribe, read from the link's host.
case "$URL" in
  *instagram.com*) PLATFORM=instagram ;;
  *tiktok.com*) PLATFORM=tiktok ;;
  *reddit.com*|*redd.it*) PLATFORM=reddit ;;
  *youtube.com*|*youtu.be*) PLATFORM=youtube ;;
  *) echo "only Instagram, TikTok, Reddit or YouTube links" >&2; exit 1 ;;
esac
BUNDLE_ID="com.matthewpark.quokka"
DEVICE=$(xcrun simctl list devices | grep "Quokka Sim (" | grep -oE "[0-9A-F-]{36}" | head -1)
[[ -n "$DEVICE" ]] || { echo "no 'Quokka Sim' -- run scripts/tour.sh once to create it" >&2; exit 1; }
OUT="build/e2e"
rm -rf "$OUT" && mkdir -p "$OUT"
LOGPID=""
trap '[[ -n "$LOGPID" ]] && kill "$LOGPID" 2>/dev/null; xcrun simctl shutdown "$DEVICE" 2>/dev/null; echo "==> simulator shut down"' EXIT INT TERM HUP

APP=ios/build/Build/Products/Debug-iphonesimulator/Quokka.app
[[ -d "$APP" ]] || { echo "no build -- run scripts/tour.sh first" >&2; exit 1; }

echo "==> worker"
curl -s -m 10 https://quokka.matthew-parkk0.workers.dev/config | head -c 120; echo

echo "==> booting and transcribing $URL"
xcrun simctl boot "$DEVICE" 2>/dev/null; xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1
xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID" 2>/dev/null
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl spawn "$DEVICE" log stream --level info --style compact \
  --predicate 'subsystem == "com.matthewpark.quokka"' > "$OUT/log.txt" 2>&1 &
LOGPID=$!
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -quokkaTab home -quokkaAddLinks "$URL" -quokkaTranscribe "$PLATFORM" >/dev/null
sleep 90

DATA=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data)
DB=$(find "$DATA/Library/Application Support" -name "quokka.sqlite" | head -1)
echo "==> transcript"
sqlite3 "$DB" "SELECT source, length(text), substr(text, 1, 160) FROM item_transcript;"
echo "==> job (attempts, last failure)"
sqlite3 "$DB" "SELECT attempts, lastFailure FROM transcript_job;"
echo "==> what the app said"
grep -iE "transcrib|config|webview|speech|resolve" "$OUT/log.txt" | tail -20
