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
Usage: ./scripts/build-production.sh [OPTIONS]

Build Frontend/jezaku_ui for production.

Options:
  --mode MODE       Build mode: html or wasm. Default: html
  --clean           Run flutter clean first
  --pub-get         Run flutter pub get before build
  --no-pub-get      Skip flutter pub get
  --help, -h        Show this help

Examples:
  ./scripts/build-production.sh
  ./scripts/build-production.sh --mode wasm
  ./scripts/build-production.sh --clean --pub-get
EOF
}

BUILD_MODE="html"
RUN_CLEAN=false
RUN_PUB_GET=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            BUILD_MODE="$2"
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
    print_error "--mode must be 'html' or 'wasm'"
    exit 1
fi

print_header "jezaku UI Production Build"
echo "Project: $PROJECT_DIR"
echo "Mode: $BUILD_MODE"
echo "Clean: $RUN_CLEAN"
echo "Pub get: $RUN_PUB_GET"

if [[ "$RUN_CLEAN" == true ]]; then
    print_header "Cleaning previous build"
    flutter clean
fi

if [[ "$RUN_PUB_GET" == true ]]; then
    print_header "Fetching dependencies"
    flutter pub get
fi

print_header "Building web release"
if [[ "$BUILD_MODE" == "wasm" ]]; then
    flutter build web --wasm --release --no-tree-shake-icons
else
    flutter build web --release --no-tree-shake-icons
fi

if [[ ! -d "$PROJECT_DIR/build/web" ]]; then
    print_error "Build finished but build/web was not found"
    exit 1
fi

BUILD_SIZE="$(du -sh "$PROJECT_DIR/build/web" | awk '{print $1}')"
print_success "Production build completed"
echo "Output: $PROJECT_DIR/build/web"
echo "Size: $BUILD_SIZE"
