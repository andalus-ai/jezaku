#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

realm="${TENANT_REALM:-jezaku}"
identity_health="${IDENTITY_HEALTH_URL:-http://localhost:7101/health}"
chat_health="${CHAT_HEALTH_URL:-http://localhost:7109/health}"
keycloak_realm_url="${KEYCLOAK_REALM_URL:-}"
check_services=true
strict=false

show_help() {
  cat <<EOF
jezaku UI development doctor

Usage:
  ./scripts/doctor.sh [options]

Options:
  --realm REALM           Tenant realm to check. Default: ${realm}
  --identity-health URL   Identity health URL. Default: ${identity_health}
  --chat-health URL       Chat health URL. Default: ${chat_health}
  --keycloak-realm URL    Keycloak realm URL. Default: http://localhost:8199/auth/realms/<realm>
  --no-services           Skip backend/Keycloak HTTP checks
  --strict                Exit non-zero when a service check fails
  -h, --help              Show this help

Examples:
  ./scripts/doctor.sh
  ./scripts/doctor.sh --realm one-ummah
  ./scripts/doctor.sh --identity-health http://localhost:7101/health --chat-health http://localhost:7109/health
EOF
}

ok() {
  echo -e "${GREEN}OK${NC}  $*"
}

warn() {
  echo -e "${YELLOW}WARN${NC} $*"
}

bad() {
  echo -e "${RED}FAIL${NC} $*"
}

info() {
  echo -e "${BLUE}INFO${NC} $*"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

short_version() {
  "$@" 2>/dev/null | head -n 1 || true
}

get_host_ip() {
  local ip=""
  if have ipconfig; then
    ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
    if [ -z "$ip" ]; then
      ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
    fi
  fi
  if [ -z "$ip" ] && have ifconfig; then
    ip="$(ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')"
  fi
  echo "$ip"
}

check_command() {
  local name="$1"
  shift
  if have "$name"; then
    local version
    version="$(short_version "$@")"
    if [ -n "$version" ]; then
      ok "$name available: $version"
    else
      ok "$name available"
    fi
    return 0
  fi
  warn "$name not found"
  return 1
}

check_file() {
  local path="$1"
  local label="$2"
  if [ -e "$PROJECT_DIR/$path" ]; then
    ok "$label: $path"
  else
    warn "$label missing: $path"
  fi
}

check_executable() {
  local path="$1"
  if [ -x "$PROJECT_DIR/$path" ]; then
    ok "executable: $path"
  else
    warn "not executable: $path"
  fi
}

check_http() {
  local label="$1"
  local url="$2"

  if ! have curl; then
    warn "curl not found; skipping $label"
    return 0
  fi

  local status
  status="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 2 "$url" 2>/dev/null || true)"
  if [[ "$status" =~ ^[23] ]]; then
    ok "$label reachable: $url ($status)"
    return 0
  fi

  if [ -z "$status" ] || [ "$status" = "000" ]; then
    bad "$label not reachable: $url"
  else
    bad "$label returned HTTP $status: $url"
  fi

  if [ "$strict" = true ]; then
    return 1
  fi
  return 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --realm)
      realm="${2:-}"
      shift 2
      ;;
    --identity-health)
      identity_health="${2:-}"
      shift 2
      ;;
    --chat-health)
      chat_health="${2:-}"
      shift 2
      ;;
    --keycloak-realm)
      keycloak_realm_url="${2:-}"
      shift 2
      ;;
    --no-services)
      check_services=false
      shift
      ;;
    --strict)
      strict=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      bad "unknown option: $1"
      echo ""
      show_help
      exit 1
      ;;
  esac
done

if [ -z "$realm" ]; then
  bad "--realm cannot be empty"
  exit 1
fi

if [ -z "$keycloak_realm_url" ]; then
  keycloak_realm_url="http://localhost:8199/auth/realms/$realm"
fi

cd "$PROJECT_DIR"

echo -e "${BLUE}jezaku UI Doctor${NC}"
echo "Project: $PROJECT_DIR"
echo "Realm: $realm"
echo ""

info "Tooling"
check_command flutter flutter --version
check_command dart dart --version
check_command git git --version
if have adb; then
  adb_version="$(short_version adb version)"
  if [ -n "$adb_version" ]; then
    ok "adb available: $adb_version"
  else
    ok "adb available"
  fi
else
  warn "adb not found; Android device checks skipped"
fi

echo ""
info "Project Files"
check_file pubspec.yaml "Flutter manifest"
check_file l10n.yaml "Localization config"
check_file analysis_options.yaml "Analyzer config"
check_file android/app/src/main/AndroidManifest.xml "Android manifest"
check_file ios/Runner/Info.plist "iOS plist"
check_file macos/Runner/Info.plist "macOS plist"

echo ""
info "Scripts"
while IFS= read -r script_path; do
  check_executable "${script_path#"$PROJECT_DIR"/}"
done < <(find "$PROJECT_DIR/scripts" -maxdepth 1 -type f -name '*.sh' | sort)

echo ""
info "Android Runtime Notes"
host_ip="$(get_host_ip)"
if [ -n "$host_ip" ]; then
  ok "detected host LAN IP: $host_ip"
  echo "     Suggested device command:"
  echo "     ./scripts/run_android_device.sh --host http://$host_ip:7100 --realm $realm"
else
  warn "could not auto-detect host LAN IP"
fi

if have adb; then
  if adb_devices="$(adb devices 2>/dev/null)"; then
    device_count="$(printf '%s\n' "$adb_devices" | awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
    if [ "$device_count" -gt 0 ]; then
      ok "connected Android devices: $device_count"
      echo "     Reminder: localhost inside Android points to the phone/emulator, not this Mac."
    else
      warn "no authorized Android devices detected"
    fi
  else
    warn "adb devices failed; Android daemon may be blocked or already owned by another process"
  fi
fi

echo ""
info "Firebase Push"
if [ "${ENABLE_FCM_PUSH:-true}" = "true" ]; then
  if [ -f android/app/google-services.json ] ||
    { [ -n "${FIREBASE_ANDROID_API_KEY:-}" ] &&
      [ -n "${FIREBASE_ANDROID_APP_ID:-}" ] &&
      [ -n "${FIREBASE_ANDROID_MESSAGING_SENDER_ID:-}" ] &&
      [ -n "${FIREBASE_ANDROID_PROJECT_ID:-}" ]; }; then
    ok "Android Firebase config available"
  else
    warn "ENABLE_FCM_PUSH=true but Android Firebase config was not found"
    echo "     For local websocket-only Android runs:"
    echo "     ENABLE_FCM_PUSH=false ./scripts/run_android_device.sh --realm $realm"
  fi
else
  ok "ENABLE_FCM_PUSH=false"
fi

if [ "$check_services" = true ]; then
  echo ""
  info "Local Services"
  check_http "Identity service" "$identity_health"
  check_http "Chat service" "$chat_health"
  check_http "Keycloak realm" "$keycloak_realm_url"
fi

echo ""
ok "doctor completed"
