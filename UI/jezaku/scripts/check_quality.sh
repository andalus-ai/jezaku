#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

run_tests=true
run_full_tests=false
run_golden_tests=false
run_pub_get=false
run_l10n=false
staged_only=false

show_help() {
  cat <<EOF
jezaku UI quality check

Usage:
  ./scripts/check_quality.sh [options]

Default checks:
  dart analyze
  flutter test test/auth/screens/panic_recovery_screen_test.dart
  git diff --check

Options:
  --pub-get       Run flutter pub get before checks
  --gen-l10n      Run flutter gen-l10n before analyzer
  --full-test     Run the full Flutter test suite instead of the smoke test
  --goldens       Run golden verification after tests
  --no-tests      Skip Flutter tests
  --staged-only   Check staged git changes instead of the full working tree
  -h, --help      Show this help
EOF
}

step() {
  echo ""
  echo -e "${BLUE}==>${NC} ${GREEN}$*${NC}"
}

fail() {
  echo -e "${RED}Quality check failed:${NC} $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --pub-get)
      run_pub_get=true
      ;;
    --gen-l10n)
      run_l10n=true
      ;;
    --full-test)
      run_full_tests=true
      ;;
    --goldens)
      run_golden_tests=true
      ;;
    --no-tests)
      run_tests=false
      ;;
    --staged-only)
      staged_only=true
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      fail "unknown option '$1'"
      ;;
  esac
  shift
done

cd "$PROJECT_DIR"

if [ "$run_pub_get" = true ]; then
  step "Resolving Flutter dependencies"
  flutter pub get
fi

if [ "$run_l10n" = true ]; then
  step "Generating localization files"
  flutter gen-l10n
fi

step "Running Dart analyzer"
dart analyze

if [ "$run_tests" = true ]; then
  if [ "$run_full_tests" = true ]; then
    step "Running full Flutter test suite"
    flutter test --reporter=compact
  else
    step "Running app-lock recovery smoke test"
    flutter test test/auth/screens/panic_recovery_screen_test.dart --reporter=compact
  fi
else
  echo -e "${YELLOW}Skipping Flutter tests.${NC}"
fi

if [ "$run_golden_tests" = true ]; then
  step "Running golden verification"
  flutter test test/golden_auth_screens_test.dart --reporter=compact
  flutter test test/golden_main_screens_test.dart --reporter=compact
  flutter test test/golden_security_screens_test.dart --reporter=compact
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ "$staged_only" = true ]; then
    step "Checking staged whitespace and conflict markers"
    git diff --cached --check
  else
    step "Checking whitespace and conflict markers"
    git diff --check
  fi
else
  echo -e "${YELLOW}Skipping git diff --check; not inside a git worktree.${NC}"
fi

echo ""
echo -e "${GREEN}Quality check passed.${NC}"
