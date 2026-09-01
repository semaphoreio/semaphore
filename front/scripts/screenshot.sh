#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/screenshot.sh <url> <out.png> [WIDTHxHEIGHT]" >&2
  echo "       CHROME_BIN=/path/to/chrome overrides browser detection" >&2
}

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

URL="$1"
OUT="$2"
SIZE="${3:-1600x1200}"

if ! [[ "$SIZE" =~ ^[0-9]+x[0-9]+$ ]]; then
  usage
  exit 1
fi

DEFAULT_CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if [ -n "${CHROME_BIN:-}" ]; then
  CHROME="$CHROME_BIN"
elif [ -x "$DEFAULT_CHROME" ]; then
  CHROME="$DEFAULT_CHROME"
elif command -v chromium >/dev/null 2>&1; then
  CHROME="$(command -v chromium)"
elif command -v chromium-browser >/dev/null 2>&1; then
  CHROME="$(command -v chromium-browser)"
else
  echo "no chrome or chromium found; set CHROME_BIN" >&2
  exit 1
fi

if [ ! -x "$CHROME" ]; then
  echo "not executable: $CHROME" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
OUT_DIR="$(cd "$(dirname "$OUT")" && pwd)"
OUT_ABS="$OUT_DIR/$(basename "$OUT")"

PROFILE="$(mktemp -d)"
CHROME_PID=""
cleanup() {
  if [ -n "$CHROME_PID" ]; then
    kill "$CHROME_PID" 2>/dev/null || true
    wait "$CHROME_PID" 2>/dev/null || true
  fi
  rm -rf "$PROFILE" 2>/dev/null || true
}
trap cleanup EXIT

rm -f "$OUT_ABS"

"$CHROME" \
  --headless=new \
  --disable-gpu \
  --hide-scrollbars \
  --no-first-run \
  --no-default-browser-check \
  --user-data-dir="$PROFILE" \
  --window-size="${SIZE/x/,}" \
  --virtual-time-budget=5000 \
  --screenshot="$OUT_ABS" \
  "$URL" >/dev/null 2>&1 &
CHROME_PID=$!

DEADLINE=$((SECONDS + ${SCREENSHOT_TIMEOUT:-45}))
while [ ! -s "$OUT_ABS" ] && kill -0 "$CHROME_PID" 2>/dev/null; do
  if [ "$SECONDS" -ge "$DEADLINE" ]; then
    echo "timed out waiting for $OUT_ABS" >&2
    exit 1
  fi
  sleep 0.5
done

sleep 1

if [ ! -s "$OUT_ABS" ]; then
  echo "no screenshot written for $URL" >&2
  exit 1
fi

if [ "$(od -An -tx1 -N4 "$OUT_ABS" | tr -d ' \n')" != "89504e47" ]; then
  echo "not a png: $OUT_ABS" >&2
  exit 1
fi

echo "$OUT_ABS"
