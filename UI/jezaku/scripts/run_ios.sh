#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# Usage:
#   ./scripts/run_ios.sh                 -> auto-pick an available iOS simulator
#   ./scripts/run_ios.sh "<device-id>"   -> run on specific Flutter device id
#   ./scripts/run_ios.sh "iPhone 16e"    -> run on specific device name
TARGET=""
HOST_ORIGIN=""
REALM="${TENANT_REALM:-jezaku}"
CHAT_USER_ID_SOURCE="${CHAT_USER_ID_SOURCE:-auto}"
ENABLE_FCM_PUSH="${ENABLE_FCM_PUSH:-true}"

if [[ $# -gt 0 && "$1" != --* ]]; then
  TARGET="$1"
  shift
fi

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_ios.sh [TARGET] [--host ORIGIN] [--realm REALM]

Examples:
  ./scripts/run_ios.sh
  ./scripts/run_ios.sh "iPhone 16e" --host http://localhost:7100
  ./scripts/run_ios.sh --host https://api.jezaku.com --realm jezaku
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST_ORIGIN="$2"
      shift 2
      ;;
    --realm)
      REALM="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

EXTRA_DEFINES=()
if [[ -n "$HOST_ORIGIN" ]]; then
  HOST_RAW="${HOST_ORIGIN%/}"
  SCHEME=""
  HOSTPORT=""
  if [[ "$HOST_RAW" == *"://"* ]]; then
    SCHEME="${HOST_RAW%%://*}"
    HOSTPORT="${HOST_RAW#*://}"
  else
    SCHEME="http"
    HOSTPORT="$HOST_RAW"
  fi
  HOSTPORT="${HOSTPORT%%/*}"
  ORIGIN="${SCHEME}://${HOSTPORT}"
  WS_SCHEME="ws"
  if [[ "$SCHEME" == "https" ]]; then
    WS_SCHEME="wss"
  fi
  EXTRA_DEFINES+=(
    --dart-define=BACKEND_HOST="$HOSTPORT"
    --dart-define=TENANT_REALM="$REALM"
    --dart-define=AUTH_BASE_URL="${ORIGIN}/${REALM}/auth"
    --dart-define=CHAT_BASE_URL="${ORIGIN}/${REALM}/chat"
    --dart-define=CHAT_WS_BASE_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/chat"
    --dart-define=MINA_SIGNALING_WS_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/ws"
    --dart-define=MINA_NOTIFICATION_WS_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/notifications/ws"
    --dart-define=NOTIFICATION_API_BASE_URL="${ORIGIN}/${REALM}/notifications"
    --dart-define=ADMIN_BASE_URL="${ORIGIN}/${REALM}/admin"
  )
fi

if [[ -n "${TARGET}" ]]; then
  echo "Launching on iOS target: ${TARGET}"
  exec flutter run -d "${TARGET}" \
    "${EXTRA_DEFINES[@]}" \
    --dart-define=ENABLE_FCM_PUSH="$ENABLE_FCM_PUSH" \
    --dart-define=CHAT_USER_ID_SOURCE="$CHAT_USER_ID_SOURCE"
fi

# Validate that installed simulator runtimes match Xcode's iphonesimulator SDK.
SDK_VERSION="$(
  xcodebuild -showsdks 2>/dev/null | awk '/-sdk iphonesimulator/ { sub(/^.*iphonesimulator/, "", $NF); print $NF }' | tail -n1
)"
RUNTIME_VERSIONS="$(
  xcrun simctl list runtimes 2>/dev/null | awk '/^iOS / { print $2 }'
)"

if [[ -n "${SDK_VERSION}" ]]; then
  if ! grep -qx "${SDK_VERSION}" <<<"${RUNTIME_VERSIONS}"; then
    echo "Xcode iOS Simulator SDK ${SDK_VERSION} is active, but that runtime is not installed."
    echo "Installed iOS simulator runtimes: ${RUNTIME_VERSIONS:-none}"
    echo "Install iOS ${SDK_VERSION} in Xcode > Settings > Components, then retry."
    exit 1
  fi
fi

# Prefer a booted simulator first, then fallback to first available iPhone/iPad.
SIM_ID="$(
  xcrun simctl list devices available | awk -F '[()]' '
    /Booted/ && /iPhone|iPad/ { print $2; exit }
  '
)"

if [[ -z "${SIM_ID}" ]]; then
  SIM_ID="$(
    xcrun simctl list devices available | awk -F '[()]' '
      /iPhone|iPad/ { print $2; exit }
    '
  )"
fi

if [[ -z "${SIM_ID}" ]]; then
  echo "No available iOS simulator found."
  echo "Open Simulator.app and create/download one from Xcode > Settings > Components."
  exit 1
fi

echo "Launching on simulator id: ${SIM_ID}"
exec flutter run -d "${SIM_ID}" \
  "${EXTRA_DEFINES[@]}" \
  --dart-define=ENABLE_FCM_PUSH="$ENABLE_FCM_PUSH" \
  --dart-define=CHAT_USER_ID_SOURCE="$CHAT_USER_ID_SOURCE"
