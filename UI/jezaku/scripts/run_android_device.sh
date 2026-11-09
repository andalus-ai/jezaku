#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_android_device.sh [--host ORIGIN] [--realm REALM] [--install-start] [FLUTTER_ARGS...]

  ./scripts/run_android_device.sh --host https://api.jezaku.com --realm jezaku

Notes:
  - If --host is provided, the app will use gateway-style routes:
    ORIGIN/<realm>/auth, ORIGIN/<realm>/chat, ORIGIN/<realm>/ws, etc.
  - If --host is not provided, the script falls back to direct service ports
    on the detected LAN IP (identity 7101, chat 7109, mina signaling 2443).
  - Flutter arguments such as --profile and --dart-define=KEY=VALUE are
    forwarded to flutter run by default.
  - --install-start builds, installs, and launches the APK without attaching
    the Flutter VM-service websocket. Use this when profile flutter run flakes.
EOF
}

HOST_ORIGIN=""
TENANT_REALM="${TENANT_REALM:-jezaku}"
INSTALL_START=false
USER_DART_DEFINES=()
FLUTTER_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-start)
      INSTALL_START=true
      shift
      ;;
    --host)
      if [[ $# -lt 2 ]]; then
        echo "[ERROR] --host requires a value" >&2
        usage
        exit 1
      fi
      HOST_ORIGIN="$2"
      shift 2
      ;;
    --realm)
      if [[ $# -lt 2 ]]; then
        echo "[ERROR] --realm requires a value" >&2
        usage
        exit 1
      fi
      TENANT_REALM="$2"
      shift 2
      ;;
    --dart-define=*)
      USER_DART_DEFINES+=("$1")
      shift
      ;;
    --dart-define)
      if [[ $# -lt 2 ]]; then
        echo "[ERROR] --dart-define requires KEY=VALUE" >&2
        usage
        exit 1
      fi
      USER_DART_DEFINES+=(--dart-define="$2")
      shift 2
      ;;
    --profile|--debug|--release)
      FLUTTER_ARGS+=("$1")
      shift
      ;;
    --)
      shift
      FLUTTER_ARGS+=("$@")
      break
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      FLUTTER_ARGS+=("$1")
      shift
      ;;
  esac
done

if ! command -v adb >/dev/null 2>&1; then
  echo "[ERROR] adb not found. Please install Android platform tools."
  exit 1
fi

get_host_ip() {
  local ip=""
  if command -v ipconfig >/dev/null 2>&1; then
    ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
    if [ -z "$ip" ]; then
      ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
    fi
  fi
  if [ -z "$ip" ] && command -v ifconfig >/dev/null 2>&1; then
    ip="$(ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')"
  fi
  echo "$ip"
}

can_reach_host() {
  local host="$1"
  local port="${2:-7101}"
  if [ -z "$host" ]; then
    return 1
  fi
  # Try TCP connect using bash built-in /dev/tcp (fast, no extra deps).
  timeout 1 bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" >/dev/null 2>&1
}

select_device() {
  local devices=()
  while read -r line; do
    [ -z "$line" ] && continue
    devices+=("$line")
  done < <(adb devices -l | awk 'NR>1 && $2=="device" {print $1}')
  if [ ${#devices[@]} -eq 0 ]; then
    echo "[ERROR] No Android device detected. Connect a device or start an emulator."
    exit 1
  fi
  if [ ${#devices[@]} -eq 1 ]; then
    echo "${devices[0]}"
    return
  fi
  echo "[INFO] Multiple devices detected:"
  local idx=1
  for dev in "${devices[@]}"; do
    echo "  [$idx] $dev"
    idx=$((idx + 1))
  done
  local choice=""
  while true; do
    read -r -p "Select device (1-${#devices[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#devices[@]}" ]; then
      echo "${devices[$((choice - 1))]}"
      return
    fi
    echo "Invalid selection."
  done
}

DEVICE_ID="${ANDROID_DEVICE_ID:-$(select_device)}"
AUTO_DETECTED_IP="$(get_host_ip)"
DEFAULT_BACKEND_HOST="${DEFAULT_BACKEND_HOST:-192.168.8.184}"

# IMPORTANT:
# Use "auto" by default so the app aligns with backend canonical user IDs.
# "username" can create legacy/duplicate DM rooms (uuid vs username) and can
# block strict E2EE sending when peer keys are published under UUID.
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

EXTRA_DEFINES=()
if [[ "$ENABLE_FCM_PUSH" == "true" ]]; then
  if [[ ! -f android/app/google-services.json ]] &&
    ! has_firebase_android_runtime_defines; then
    echo "[ERROR] ENABLE_FCM_PUSH=true but Firebase Android config is missing."
    echo "        Add android/app/google-services.json or export FIREBASE_ANDROID_API_KEY,"
    echo "        FIREBASE_ANDROID_APP_ID, FIREBASE_ANDROID_MESSAGING_SENDER_ID,"
    echo "        and FIREBASE_ANDROID_PROJECT_ID before running."
    echo "        For websocket/local-only testing: ENABLE_FCM_PUSH=false ./scripts/run_android_device.sh ..."
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
    --dart-define=TENANT_REALM="$TENANT_REALM"
    --dart-define=AUTH_BASE_URL="${ORIGIN}/${TENANT_REALM}/auth"
    --dart-define=CHAT_BASE_URL="${ORIGIN}/${TENANT_REALM}/chat"
    --dart-define=CHAT_WS_BASE_URL="${WS_SCHEME}://${HOSTPORT}/${TENANT_REALM}/chat"
    --dart-define=MINA_SIGNALING_WS_URL="${WS_SCHEME}://${HOSTPORT}/${TENANT_REALM}/ws"
    --dart-define=MINA_NOTIFICATION_WS_URL="${WS_SCHEME}://${HOSTPORT}/${TENANT_REALM}/notifications/ws"
    --dart-define=NOTIFICATION_API_BASE_URL="${ORIGIN}/${TENANT_REALM}/notifications"
    --dart-define=ADMIN_BASE_URL="${ORIGIN}/${TENANT_REALM}/admin"
  )
  HOST_IP="$HOSTPORT"
else
  if [ -n "${BACKEND_HOST:-}" ]; then
    HOST_IP="$BACKEND_HOST"
  elif [ -n "$DEFAULT_BACKEND_HOST" ] && can_reach_host "$DEFAULT_BACKEND_HOST" 7101; then
    HOST_IP="$DEFAULT_BACKEND_HOST"
  else
    HOST_IP="$AUTO_DETECTED_IP"
  fi
  if [ -z "$HOST_IP" ]; then
    echo "[ERROR] Could not determine host IP. Set BACKEND_HOST manually."
    exit 1
  fi

  # Direct microservice ports (dev/local).
  EXTRA_DEFINES+=(
    --dart-define=BACKEND_HOST="$HOST_IP"
    --dart-define=TENANT_REALM="$TENANT_REALM"
    --dart-define=AUTH_BASE_URL="http://${HOST_IP}:7101"
    --dart-define=CHAT_BASE_URL="http://${HOST_IP}:7109"
    --dart-define=CHAT_WS_BASE_URL="ws://${HOST_IP}:7109"
    --dart-define=MINA_SIGNALING_WS_URL="${MINA_SIGNALING_WS_URL:-ws://${HOST_IP}:2443/ws}"
    --dart-define=MINA_NOTIFICATION_WS_URL="${MINA_NOTIFICATION_WS_URL:-ws://${HOST_IP}:7112/api/notifications/ws}"
    --dart-define=NOTIFICATION_API_BASE_URL="${NOTIFICATION_API_BASE_URL:-http://${HOST_IP}:7112/api/notifications}"
  )
fi

echo "[INFO] Using device: $DEVICE_ID"
echo "[INFO] Using host IP: $HOST_IP"
if [ -n "$AUTO_DETECTED_IP" ]; then
  echo "[INFO] Auto-detected IP: $AUTO_DETECTED_IP"
fi
if [ -n "$DEFAULT_BACKEND_HOST" ]; then
  echo "[INFO] Default BACKEND_HOST: $DEFAULT_BACKEND_HOST"
fi
echo "[INFO] TENANT_REALM=$TENANT_REALM CHAT_USER_ID_SOURCE=$CHAT_USER_ID_SOURCE ENABLE_FCM_PUSH=$ENABLE_FCM_PUSH"
if [ ${#FLUTTER_ARGS[@]} -gt 0 ]; then
  echo "[INFO] Flutter args: ${FLUTTER_ARGS[*]}"
fi
if [ ${#USER_DART_DEFINES[@]} -gt 0 ]; then
  echo "[INFO] Extra dart defines: ${USER_DART_DEFINES[*]}"
fi
if [[ "$INSTALL_START" == "true" ]]; then
  echo "[INFO] Launch mode: build/install/start (no flutter run VM-service attach)"
fi

maybe_reverse_localhost_port() {
  local hostport="$1"
  if [[ "$hostport" != localhost:* && "$hostport" != 127.0.0.1:* ]]; then
    return
  fi
  local port="${hostport##*:}"
  if [[ ! "$port" =~ ^[0-9]+$ ]]; then
    return
  fi
  echo "[INFO] Setting adb reverse tcp:$port tcp:$port for device localhost backend access"
  adb -s "$DEVICE_ID" reverse "tcp:$port" "tcp:$port" >/dev/null || {
    echo "[WARN] Failed to set adb reverse for tcp:$port; offline demo can still run without backend."
  }
}

build_mode() {
  local arg
  for arg in "${FLUTTER_ARGS[@]}"; do
    case "$arg" in
      --release) echo "release"; return ;;
      --profile) echo "profile"; return ;;
      --debug) echo "debug"; return ;;
    esac
  done
  echo "debug"
}

if [[ "$INSTALL_START" == "true" ]]; then
  maybe_reverse_localhost_port "$HOST_IP"
  MODE="$(build_mode)"
  APK_PATH="build/app/outputs/flutter-apk/app-${MODE}.apk"
  echo "[INFO] Building APK: $MODE"
  flutter build apk \
    "${FLUTTER_ARGS[@]}" \
    "${EXTRA_DEFINES[@]}" \
    "${USER_DART_DEFINES[@]}" \
    --dart-define=ENABLE_FCM_PUSH="$ENABLE_FCM_PUSH" \
    --dart-define=CHAT_USER_ID_SOURCE="$CHAT_USER_ID_SOURCE"
  echo "[INFO] Installing $APK_PATH"
  adb -s "$DEVICE_ID" install -r "$APK_PATH"
  echo "[INFO] Starting tech.kayys.jezaku/.MainActivity"
  adb -s "$DEVICE_ID" shell am start -n tech.kayys.jezaku/.MainActivity
  echo "[INFO] To read AR frame diagnostics:"
  echo "       adb -s $DEVICE_ID logcat -v time | rg 'AR_HANGING_FRAME|AREngine/ARCoreGLRenderer|AndroidRuntime|Fatal signal'"
  exit 0
fi

flutter run -d "$DEVICE_ID" \
  "${FLUTTER_ARGS[@]}" \
  "${EXTRA_DEFINES[@]}" \
  "${USER_DART_DEFINES[@]}" \
  --dart-define=ENABLE_FCM_PUSH="$ENABLE_FCM_PUSH" \
  --dart-define=CHAT_USER_ID_SOURCE="$CHAT_USER_ID_SOURCE"
