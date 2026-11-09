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
Usage: ./scripts/build-android-production.sh --host HOST_OR_IP [OPTIONS]

Build jezaku_ui Android release with production backend host/ip injected.

Options:
  --host HOST          Required backend host or IP
  --realm REALM        Tenant realm. Default: jezaku
  --type TYPE          apk or aab. Default: apk
  --clean              Run flutter clean first
  --pub-get            Run flutter pub get before build
  --no-pub-get         Skip flutter pub get
  --chat-user-id-source VALUE
                       Default: auto
  --mina-ws URL        Override Mina signaling websocket URL
  --install            Install the built APK to a connected device via adb
  --help, -h           Show this help

Examples:
  ./scripts/build-android-production.sh --host [IP_ADDRESS]
  ./scripts/build-android-production.sh --host api.jezaku.com --type aab --clean
EOF
}

HOST=""
REALM="jezaku"
BUILD_TYPE="apk"
RUN_CLEAN=false
RUN_PUB_GET=true
CHAT_USER_ID_SOURCE="auto"
MINA_WS=""
INSTALL_AFTER_BUILD=false
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
      BUILD_CMD+=(--dart-define="$key=${!key}")
    fi
  done
}

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
        --type)
            BUILD_TYPE="$2"
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
        --install)
            INSTALL_AFTER_BUILD=true
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

if [[ "$BUILD_TYPE" != "apk" && "$BUILD_TYPE" != "aab" ]]; then
    print_error "--type must be 'apk' or 'aab'"
    exit 1
fi

# Extract version from pubspec.yaml
VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')

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

# Build metadata to verify installs on device.
BUILD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

print_header "jezaku UI Android Production Build"
echo "Project: $PROJECT_DIR"
echo "Version: $VERSION"
echo "Host: $HOST"
echo "Origin: $ORIGIN"
echo "Realm: $REALM"
echo "Type: $BUILD_TYPE"
echo "Auth URL: $AUTH_BASE_URL"
echo "Chat URL: $CHAT_BASE_URL"
echo "Mina WS: $MINA_SIGNALING_WS_URL"
echo "Notification WS: $MINA_NOTIFICATION_WS_URL"
echo "Notification API: $NOTIFICATION_API_BASE_URL"
echo "FCM enabled: $ENABLE_FCM_PUSH"
echo "Admin URL: $ADMIN_BASE_URL"

if [[ "$ENABLE_FCM_PUSH" == "true" ]]; then
    if [[ ! -f android/app/google-services.json ]] &&
        ! has_firebase_android_runtime_defines; then
        print_error "ENABLE_FCM_PUSH=true but Firebase Android config is missing."
        echo "Add android/app/google-services.json or export FIREBASE_ANDROID_API_KEY,"
        echo "FIREBASE_ANDROID_APP_ID, FIREBASE_ANDROID_MESSAGING_SENDER_ID,"
        echo "and FIREBASE_ANDROID_PROJECT_ID before building."
        echo "For websocket/local-only builds: ENABLE_FCM_PUSH=false $0 ..."
        exit 1
    fi
fi

if [[ "$RUN_CLEAN" == true ]]; then
    print_header "Cleaning previous build"
    flutter clean
fi

if [[ "$RUN_PUB_GET" == true ]]; then
    print_header "Fetching dependencies"
    flutter pub get
fi

BUILD_CMD=(flutter build)
if [[ "$BUILD_TYPE" == "aab" ]]; then
    BUILD_CMD+=(appbundle)
else
    BUILD_CMD+=(apk)
fi
BUILD_CMD+=(
    --release
    --no-tree-shake-icons
    --dart-define=AUTO_DETECT_HOST=false
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
    --dart-define=BUILD_SHA="$BUILD_SHA"
    --dart-define=BUILD_TIME="$BUILD_TIME"
)

if [[ "$ENABLE_FCM_PUSH" == "true" ]]; then
    append_firebase_android_defines
fi

print_header "Building Android release"
"${BUILD_CMD[@]}"


PREFERRED_OUTPUT_DIR="${ANDROID_RELEASE_OUTPUT_DIR:-$HOME/Library/CloudStorage/Dropbox/000/miku}"
FALLBACK_OUTPUT_DIR="$PROJECT_DIR/build/releases"

copy_release_artifact() {
    local source_path="$1"
    local file_name="$2"
    local preferred_path="$PREFERRED_OUTPUT_DIR/$file_name"
    mkdir -p "$PREFERRED_OUTPUT_DIR" 2>/dev/null || true
    if cp "$source_path" "$preferred_path" 2>/dev/null; then
        OUTPUT_PATH="$preferred_path"
        return
    fi

    mkdir -p "$FALLBACK_OUTPUT_DIR"
    OUTPUT_PATH="$FALLBACK_OUTPUT_DIR/$file_name"
    cp "$source_path" "$OUTPUT_PATH"
    print_error "Could not copy to $preferred_path; saved local fallback instead."
}

if [[ "$BUILD_TYPE" == "aab" ]]; then
    copy_release_artifact \
        build/app/outputs/bundle/release/app-release.aab \
        "jezaku-release-v$VERSION.aab"
else
    copy_release_artifact \
        build/app/outputs/flutter-apk/app-release.apk \
        "jezaku-release-v$VERSION.apk"
fi


if [[ ! -f "$OUTPUT_PATH" ]]; then
    print_error "Build finished but expected output was not found: $OUTPUT_PATH"
    exit 1
fi

print_success "Android production build completed"
echo "Output: $OUTPUT_PATH"

if [[ "$INSTALL_AFTER_BUILD" == true && "$BUILD_TYPE" == "apk" ]]; then
    if ! command -v adb >/dev/null 2>&1; then
        print_error "adb not found in PATH; cannot --install"
        exit 1
    fi
    print_header "Installing APK via adb"
    adb devices
    adb install -r build/app/outputs/flutter-apk/app-release.apk
    print_success "Installed to device"
fi
