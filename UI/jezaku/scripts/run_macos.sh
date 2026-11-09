#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_macos.sh [INSTANCE] [--host ORIGIN] [--realm REALM] [FLUTTER_ARGS...]

Examples:
  ./scripts/run_macos.sh
  ./scripts/run_macos.sh default --host http://localhost:7100
  ./scripts/run_macos.sh default --host https://api.tsiqahub.com --realm tsiqahub
EOF
}

INSTANCE_ID="default"
if [[ $# -gt 0 && "$1" != --* ]]; then
  INSTANCE_ID="$1"
  shift
fi

HOST_ORIGIN=""
REALM="${TENANT_REALM:-tsiqahub}"
CHAT_USER_ID_SOURCE="${CHAT_USER_ID_SOURCE:-auto}"
EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
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
      REALM="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
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
    --dart-define=API_BASE_URL="$ORIGIN"
    --dart-define=AUTO_DETECT_HOST=false
    --dart-define=BACKEND_HOST="$HOSTPORT"
    --dart-define=TENANT_REALM="$REALM"
    --dart-define=AUTH_BASE_URL="${ORIGIN}/${REALM}/auth"
    --dart-define=CHAT_BASE_URL="${ORIGIN}/${REALM}/chat"
    --dart-define=CHAT_WS_BASE_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/chat"
    --dart-define=MINA_SIGNALING_WS_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/ws"
    --dart-define=MINA_NOTIFICATION_WS_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/notifications/ws"
    --dart-define=ADMIN_BASE_URL="${ORIGIN}/${REALM}/admin"
  )
fi

DB_PATH="build/macos/Build/Intermediates.noindex/XCBuildData/build.db"
DB_DIR="$(dirname "$DB_PATH")"

# If a stale XCBuild DB lock exists, clear it before running.
if [[ -f "$DB_PATH" ]]; then
  if command -v lsof >/dev/null 2>&1 && lsof "$DB_PATH" >/dev/null 2>&1; then
    echo "build.db is currently in use by another build process."
    echo "Stop the other Flutter/Xcode build, then rerun this script."
    exit 1
  fi

  echo "Removing stale XCBuildData lock files..."
  rm -rf "$DB_DIR"
fi

echo "Launching macOS instance: $INSTANCE_ID"
exec flutter run -d macos \
  "${EXTRA_DEFINES[@]}" \
  --dart-define=CHAT_USER_ID_SOURCE="$CHAT_USER_ID_SOURCE" \
  "${EXTRA_ARGS[@]}"
