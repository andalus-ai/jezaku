#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_android.sh [--host ORIGIN] [--realm REALM] [--device DEVICE_ID]

Examples:
  ./scripts/run_android.sh
  ./scripts/run_android.sh --host http://localhost:7100
  ./scripts/run_android.sh --host https://api.jezaku.com --realm jezaku --device emulator-5554
EOF
}

HOST_ORIGIN=""
REALM="jezaku"
DEVICE_ID="emulator-5554"
CHAT_USER_ID_SOURCE="${CHAT_USER_ID_SOURCE:-auto}"
ENABLE_FCM_PUSH="${ENABLE_FCM_PUSH:-true}"

firebase_android_define_keys=(
  FIREBASE_ANDROID_API_KEY
  FIREBASE_ANDROID_APP_ID
  FIREBASE_ANDROID_MESSAGING_SENDER_ID
  FIREBASE_ANDROID_PROJECT_ID
  FIREBASE_ANDROID_STORAGE_BUCKET
  FIREBASE_ANDROID_AUTH_DOMAIN
  FIREBASE_ANDROID_MEASUREMENT_ID
  FIREBASE_ANDROID_CLIENT_ID
)

has_firebase_android_runtime_defines() {
  [[ -n "${FIREBASE_ANDROID_API_KEY:-}" ]] &&
    [[ -n "${FIREBASE_ANDROID_APP_ID:-}" ]] &&
    [[ -n "${FIREBASE_ANDROID_MESSAGING_SENDER_ID:-}" ]] &&
    [[ -n "${FIREBASE_ANDROID_PROJECT_ID:-}" ]]
}

append_firebase_android_defines() {
  local key
  for key in "${firebase_android_define_keys[@]}"; do
    if [[ -n "${!key:-}" ]]; then
      EXTRA_DEFINES+=(--dart-define="$key=${!key}")
    fi
  done
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
    --device)
      DEVICE_ID="$2"
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
if [[ "$ENABLE_FCM_PUSH" == "true" ]]; then
  if [[ ! -f android/app/google-services.json ]] &&
    ! has_firebase_android_runtime_defines; then
    echo "[ERROR] ENABLE_FCM_PUSH=true but Firebase Android config is missing."
    echo "        Add android/app/google-services.json or export FIREBASE_ANDROID_API_KEY,"
    echo "        FIREBASE_ANDROID_APP_ID, FIREBASE_ANDROID_MESSAGING_SENDER_ID,"
    echo "        and FIREBASE_ANDROID_PROJECT_ID before running."
    echo "        For websocket/local-only testing: ENABLE_FCM_PUSH=false ./scripts/run_android.sh ..."
    exit 1
  fi
  append_firebase_android_defines
fi

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

flutter run -d "$DEVICE_ID" \
  "${EXTRA_DEFINES[@]}" \
  --dart-define=ENABLE_FCM_PUSH="$ENABLE_FCM_PUSH" \
  --dart-define=CHAT_USER_ID_SOURCE="$CHAT_USER_ID_SOURCE"
