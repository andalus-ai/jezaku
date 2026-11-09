#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat <<'EOF'
Usage: ./scripts/build-ios-production.sh --host HOST_OR_IP [OPTIONS]

Build jezaku_ui iOS release with production backend host/ip injected.

Options:
  --host HOST          Required backend host or IP
  --realm REALM        Tenant realm. Default: jezaku
  --clean              Run flutter clean first
  --pub-get            Run flutter pub get before build
  --no-pub-get         Skip flutter pub get
  --chat-user-id-source VALUE
                       Default: auto
  --mina-ws URL        Override Mina signaling websocket URL
  --no-codesign        Build unsigned IPA/archive
  --help, -h           Show this help

Examples:
  ./scripts/build-ios-production.sh --host 103.16.199.4
  ./scripts/build-ios-production.sh --host api.example.com --clean --no-codesign
EOF
}

HOST=""
REALM="jezaku"
RUN_CLEAN=false
RUN_PUB_GET=true
CHAT_USER_ID_SOURCE="auto"
MINA_WS=""
NO_CODESIGN=false
ENABLE_FCM_PUSH="${ENABLE_FCM_PUSH:-true}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            HOST="$2"
            shift 2
            ;;
        --realm)
            REALM="$2"
            shift 2
            ;;
        --clean)
            RUN_CLEAN=true
            shift
            ;;
        --pub-get)
            RUN_PUB_GET=true
            shift
            ;;
        --no-pub-get)
            RUN_PUB_GET=false
            shift
            ;;
        --chat-user-id-source)
            CHAT_USER_ID_SOURCE="$2"
            shift 2
            ;;
        --mina-ws)
            MINA_WS="$2"
            shift 2
            ;;
        --no-codesign)
            NO_CODESIGN=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$HOST" ]]; then
    print_error "--host is required"
    echo
    usage
    exit 1
fi

# Accept both "api.example.com" and "https://api.example.com".
HOST_RAW="${HOST%/}"
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

AUTH_BASE_URL="${ORIGIN}/${REALM}/auth"
CHAT_BASE_URL="${ORIGIN}/${REALM}/chat"
CHAT_WS_BASE_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/chat"
MINA_SIGNALING_WS_URL="${MINA_WS:-${WS_SCHEME}://${HOSTPORT}/${REALM}/ws}"
MINA_NOTIFICATION_WS_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/notifications/ws"
NOTIFICATION_API_BASE_URL="${ORIGIN}/${REALM}/notifications"
ADMIN_BASE_URL="${ORIGIN}/${REALM}/admin"

print_header "jezaku UI iOS Production Build"
echo "Project: $PROJECT_DIR"
echo "Host: $HOST"
echo "Origin: $ORIGIN"
echo "Realm: $REALM"
echo "Auth URL: $AUTH_BASE_URL"
echo "Chat URL: $CHAT_BASE_URL"
echo "Mina WS: $MINA_SIGNALING_WS_URL"
echo "Notification WS: $MINA_NOTIFICATION_WS_URL"
echo "Notification API: $NOTIFICATION_API_BASE_URL"
echo "FCM enabled: $ENABLE_FCM_PUSH"
echo "Admin URL: $ADMIN_BASE_URL"
echo "No codesign: $NO_CODESIGN"

if [[ "$RUN_CLEAN" == true ]]; then
    print_header "Cleaning previous build"
    flutter clean
fi

if [[ "$RUN_PUB_GET" == true ]]; then
    print_header "Fetching dependencies"
    flutter pub get
fi

BUILD_CMD=(
    flutter build ipa
    --release
    --no-tree-shake-icons
    --dart-define=BACKEND_HOST="$HOSTPORT"
    --dart-define=TENANT_REALM="$REALM"
    --dart-define=AUTH_BASE_URL="$AUTH_BASE_URL"
    --dart-define=CHAT_BASE_URL="$CHAT_BASE_URL"
    --dart-define=CHAT_WS_BASE_URL="$CHAT_WS_BASE_URL"
    --dart-define=MINA_SIGNALING_WS_URL="$MINA_SIGNALING_WS_URL"
    --dart-define=MINA_NOTIFICATION_WS_URL="$MINA_NOTIFICATION_WS_URL"
    --dart-define=NOTIFICATION_API_BASE_URL="$NOTIFICATION_API_BASE_URL"
    --dart-define=ENABLE_FCM_PUSH="$ENABLE_FCM_PUSH"
    --dart-define=CHAT_USER_ID_SOURCE="$CHAT_USER_ID_SOURCE"
    --dart-define=ADMIN_BASE_URL="$ADMIN_BASE_URL"
)

if [[ "$NO_CODESIGN" == true ]]; then
    BUILD_CMD+=(--no-codesign)
fi

print_header "Building iOS release"
"${BUILD_CMD[@]}"

IPA_PATH="$PROJECT_DIR/build/ios/ipa"
ARCHIVE_PATH="$PROJECT_DIR/build/ios/archive"

if [[ ! -d "$IPA_PATH" && ! -d "$ARCHIVE_PATH" ]]; then
    print_error "Build finished but no iOS output directory was found"
    exit 1
fi

print_success "iOS production build completed"
if [[ -d "$IPA_PATH" ]]; then
    echo "IPA output: $IPA_PATH"
fi
if [[ -d "$ARCHIVE_PATH" ]]; then
    echo "Archive output: $ARCHIVE_PATH"
fi
