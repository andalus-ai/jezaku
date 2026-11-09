#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
Usage: ./scripts/deploy-production.sh [OPTIONS]

Dedicated production deploy wrapper for Frontend/jezaku_ui.
This script delegates to ./scripts/run-deployer.sh with production-friendly defaults.

Options:
  --host HOST          Remote server hostname or IP
  --user USER          SSH username
  --port PORT          SSH port
  --ssh-key PATH       SSH private key
  --build-mode MODE    html or wasm. Default: html
  --build-local        Build locally before deployment
  --use-existing       Use existing local web build
  --clean              Run flutter clean before build
  --dry-run            Print delegated command only
  --help, -h           Show this help

Examples:
  ./scripts/deploy-production.sh --host 103.16.199.4 --user gitcicd --ssh-key ~/.ssh/miku-deploy-key --build-local
  ./scripts/deploy-production.sh --host 103.16.199.4 --user gitcicd --ssh-key ~/.ssh/miku-deploy-key --use-existing
EOF
}

HOST=""
USER_NAME=""
PORT=""
SSH_KEY=""
BUILD_MODE="html"
BUILD_LOCAL=false
USE_EXISTING=false
CLEAN=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            HOST="$2"
            shift 2
            ;;
        --user)
            USER_NAME="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        --build-mode)
            BUILD_MODE="$2"
            shift 2
            ;;
        --build-local)
            BUILD_LOCAL=true
            shift
            ;;
        --use-existing)
            USE_EXISTING=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

if [[ "$BUILD_MODE" != "html" && "$BUILD_MODE" != "wasm" ]]; then
    print_error "--build-mode must be 'html' or 'wasm'"
    exit 1
fi

if [[ "$BUILD_LOCAL" == true && "$USE_EXISTING" == true ]]; then
    print_error "--build-local and --use-existing cannot be combined"
    exit 1
fi

CMD=("$SCRIPT_DIR/run-deployer.sh" --build-mode "$BUILD_MODE")

if [[ -n "$HOST" ]]; then
    CMD+=(--host "$HOST")
fi
if [[ -n "$USER_NAME" ]]; then
    CMD+=(--user "$USER_NAME")
fi
if [[ -n "$PORT" ]]; then
    CMD+=(--port "$PORT")
fi
if [[ -n "$SSH_KEY" ]]; then
    CMD+=(--ssh-key "$SSH_KEY")
fi
if [[ "$BUILD_LOCAL" == true ]]; then
    CMD+=(--build-local)
fi
if [[ "$USE_EXISTING" == true ]]; then
    CMD+=(--use-existing)
fi
if [[ "$CLEAN" == true ]]; then
    CMD+=(--clean)
fi

print_header "jezaku UI Production Deploy"
echo "Working directory: $SCRIPT_DIR"
echo "Project directory: $PROJECT_DIR"
echo "Command: ${CMD[*]}"

if [[ "$DRY_RUN" == true ]]; then
    print_success "Dry run complete"
    exit 0
fi

"${CMD[@]}"

print_success "jezaku UI production deploy finished"
