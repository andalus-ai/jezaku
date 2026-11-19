#!/usr/bin/env bash
# Copies the AR debug log from the phone to this computer.
#
# The app writes the log to its own files directory, so it survives a dropped
# wireless-debug connection. Reconnect (adb connect <ip:port>) and run:
#
#   ./scripts/pull_ar_debug_log.sh [output-file]
#
# Set ANDROID_SERIAL to pick a device when several are connected.
# If this does not work, open the AR diagnostics sheet in the app and tap
# "Copy debug log" instead.
set -euo pipefail

PKG="${APP_PACKAGE:-tech.kayys.jezaku}"
OUT="${1:-ar_debug_$(date +%Y%m%d_%H%M%S).log}"
EXTERNAL_DIR="/sdcard/Android/data/$PKG/files"

if ! command -v adb >/dev/null 2>&1; then
  echo "[ERROR] adb not found. Please install Android platform tools." >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
: > "$TMP"

pulled=false
# Older rotated file first so the output is in time order.
for name in ar_debug.log.1 ar_debug.log; do
  if adb shell "test -f '$EXTERNAL_DIR/$name'" >/dev/null 2>&1; then
    adb exec-out "cat '$EXTERNAL_DIR/$name'" >> "$TMP"
    pulled=true
  fi
done

if [[ "$pulled" == "false" ]]; then
  # Private storage fallback; only works for debuggable builds.
  for name in ar_debug.log.1 ar_debug.log; do
    if adb exec-out run-as "$PKG" cat "files/$name" >> "$TMP" 2>/dev/null; then
      pulled=true
    fi
  done
fi

if [[ "$pulled" == "false" || ! -s "$TMP" ]]; then
  echo "[ERROR] No AR debug log found on the device." >&2
  echo "        Was the app started with AR_DEBUG_LOG=true, or the switch turned on in the AR diagnostics sheet?" >&2
  exit 1
fi

mv "$TMP" "$OUT"
trap - EXIT
echo "[INFO] Saved $(wc -l < "$OUT") lines to $OUT"
