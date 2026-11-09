#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

PACKAGE_TYPE="dmg"
CLEAN_BUILD=false
OUTPUT_DIR="$ROOT_DIR/dist/macos"
HOST=""
REALM="${TENANT_REALM:-jezaku}"
APP_NAME_OVERRIDE=""
APP_IDENTITY=""
INSTALLER_IDENTITY=""
INSTALL_LOCATION="/Applications"
NOTARIZE_PROFILE=""
CHAT_USER_ID_SOURCE="${CHAT_USER_ID_SOURCE:-auto}"
MINA_PASSIVE_ROOMS="${MINA_PASSIVE_ROOMS:-3}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/build-macos-package.sh [--type dmg|pkg] [--host URL] [--realm REALM] [--clean]
                           [--output-dir DIR] [--app-name NAME]
                           [--app-identity "Developer ID Application: ..."]
                           [--installer-identity "Developer ID Installer: ..."]
                           [--install-location PATH] [--notarize-profile PROFILE]

Examples:
  ./scripts/build-macos-package.sh --type dmg --host https://api.jezaku.com --realm jezaku
  ./scripts/build-macos-package.sh --type pkg --host https://api.jezaku.com --realm jezaku \
    --app-identity "Developer ID Application: Muhamad Fardan Wardhana (429KA77646)" \
    --installer-identity "Developer ID Installer: Muhamad Fardan Wardhana (429KA77646)"
  ./scripts/build-macos-package.sh --type dmg --host https://api.jezaku.com --realm jezaku \
    --app-identity "Developer ID Application: Muhamad Fardan Wardhana (429KA77646)" \
    --notarize-profile AC_PROFILE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      PACKAGE_TYPE="${2:-}"
      shift 2
      ;;
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --realm)
      REALM="${2:-}"
      shift 2
      ;;
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --app-name)
      APP_NAME_OVERRIDE="${2:-}"
      shift 2
      ;;
    --app-identity)
      APP_IDENTITY="${2:-}"
      shift 2
      ;;
    --installer-identity)
      INSTALLER_IDENTITY="${2:-}"
      shift 2
      ;;
    --install-location)
      INSTALL_LOCATION="${2:-}"
      shift 2
      ;;
    --notarize-profile)
      NOTARIZE_PROFILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$PACKAGE_TYPE" != "dmg" && "$PACKAGE_TYPE" != "pkg" ]]; then
  echo "Unsupported package type: $PACKAGE_TYPE" >&2
  exit 1
fi

if [[ "$CLEAN_BUILD" == true ]]; then
  flutter clean
fi

flutter pub get

BUILD_CMD=(
  flutter build macos
  --release
)

if [[ -n "$HOST" ]]; then
  BUILD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  HOST_RAW="${HOST%/}"
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
  BUILD_CMD+=(
    --dart-define=AUTO_DETECT_HOST=false
    --dart-define=BACKEND_HOST="$HOSTPORT"
    --dart-define=TENANT_REALM="$REALM"
    --dart-define=AUTH_BASE_URL="${ORIGIN}/${REALM}/auth"
    --dart-define=CHAT_BASE_URL="${ORIGIN}/${REALM}/chat"
    --dart-define=CHAT_WS_BASE_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/chat"
    --dart-define=MINA_SIGNALING_WS_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/ws"
    --dart-define=MINA_NOTIFICATION_WS_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/notifications/ws"
    --dart-define=NOTIFICATION_API_BASE_URL="${ORIGIN}/${REALM}/notifications"
    --dart-define=ADMIN_BASE_URL="${ORIGIN}/${REALM}/admin"
    --dart-define=BUILD_SHA="$BUILD_SHA"
    --dart-define=BUILD_TIME="$BUILD_TIME"
  )
fi

BUILD_CMD+=(
  --dart-define=CHAT_USER_ID_SOURCE="$CHAT_USER_ID_SOURCE"
  --dart-define=MINA_PASSIVE_ROOMS="$MINA_PASSIVE_ROOMS"
)

echo "Building macOS app..."
"${BUILD_CMD[@]}"

APP_DIR="$(find "$ROOT_DIR/build/macos/Build/Products/Release" -maxdepth 1 -type d -name '*.app' | head -n 1)"
if [[ -z "$APP_DIR" ]]; then
  echo "No .app found in build output." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1 | cut -d'+' -f1)"
BUILD_NUMBER="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1 | cut -s -d'+' -f2)"
APP_BASENAME="$(basename "$APP_DIR" .app)"
APP_NAME="${APP_NAME_OVERRIDE:-$APP_BASENAME}"
VERSION_SUFFIX="$VERSION"
if [[ -n "$BUILD_NUMBER" ]]; then
  VERSION_SUFFIX="${VERSION_SUFFIX}+${BUILD_NUMBER}"
fi
ENTITLEMENTS_FILE="$ROOT_DIR/macos/Runner/Release.entitlements"

sign_app_if_requested() {
  if [[ -z "$APP_IDENTITY" ]]; then
    return
  fi
  echo "Signing app with Developer ID Application identity..."
  codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "$ENTITLEMENTS_FILE" \
    --sign "$APP_IDENTITY" \
    "$APP_DIR"
}

notarize_if_requested() {
  local artifact_path="$1"
  if [[ -z "$NOTARIZE_PROFILE" ]]; then
    return
  fi
  echo "Submitting for notarization..."
  xcrun notarytool submit "$artifact_path" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait
  echo "Stapling notarization ticket..."
  xcrun stapler staple "$artifact_path"
}

sign_app_if_requested

if [[ "$PACKAGE_TYPE" == "dmg" ]]; then
  STAGING_DIR="$(mktemp -d)"
  cp -R "$APP_DIR" "$STAGING_DIR/"
  ln -s /Applications "$STAGING_DIR/Applications"
  DMG_PATH="$OUTPUT_DIR/${APP_NAME}-${VERSION_SUFFIX}.dmg"
  rm -f "$DMG_PATH"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
  rm -rf "$STAGING_DIR"
  if [[ -n "$APP_IDENTITY" ]]; then
    codesign --force --sign "$APP_IDENTITY" "$DMG_PATH"
  fi
  notarize_if_requested "$DMG_PATH"
  echo "Created DMG: $DMG_PATH"
  exit 0
fi

PKG_PATH="$OUTPUT_DIR/${APP_NAME}-${VERSION_SUFFIX}.pkg"
rm -f "$PKG_PATH"

PKG_CMD=(
  productbuild
  --component "$APP_DIR" "$INSTALL_LOCATION"
)

if [[ -n "$INSTALLER_IDENTITY" ]]; then
  PKG_CMD+=(--sign "$INSTALLER_IDENTITY")
fi

PKG_CMD+=("$PKG_PATH")
"${PKG_CMD[@]}"

notarize_if_requested "$PKG_PATH"

echo "Created PKG: $PKG_PATH"
