#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

show_help() {
  echo -e "${BLUE}Chat Test Runner${NC}"
  echo ""
  echo "Usage:"
  echo "  ./scripts/run_chat_tests.sh [all|screens|components|widgets|goldens|update|help]"
  echo ""
  echo "Options:"
  echo "  all         Run chat screen tests plus component widget and golden coverage"
  echo "  screens     Run chat screen widget and golden tests"
  echo "  components  Run the reusable chat component smoke suite"
  echo "  widgets     Run reusable chat component widget tests only"
  echo "  goldens     Run reusable chat component gallery goldens only"
  echo "  update      Update reusable chat component gallery goldens"
  echo "  help        Show this help"
}

run_cmd() {
  local description=$1
  shift

  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}${description}${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  "$@"
}

run_screen_suite() {
  run_cmd \
    "Analyzing chat screen harnesses" \
    dart analyze \
    test/chat/screens/chat_list_screen_test.dart \
    test/chat/screens/chat_list_screen_golden_test.dart

  run_cmd \
    "Running chat_list_screen_test.dart" \
    flutter test test/chat/screens/chat_list_screen_test.dart --reporter=compact

  run_cmd \
    "Running chat_list_screen_golden_test.dart" \
    flutter test test/chat/screens/chat_list_screen_golden_test.dart --reporter=compact
}

cd "$PROJECT_DIR"

case "${1:-all}" in
  all)
    run_screen_suite
    bash "$SCRIPT_DIR/run_chat_component_smoke.sh" verify
    echo -e "\n${GREEN}✅ Full chat test suite passed.${NC}"
    ;;
  screens)
    run_screen_suite
    echo -e "\n${GREEN}✅ Chat screen test suite passed.${NC}"
    ;;
  components)
    bash "$SCRIPT_DIR/run_chat_component_smoke.sh" verify
    ;;
  widgets)
    bash "$SCRIPT_DIR/run_chat_component_smoke.sh" widgets
    ;;
  goldens)
    bash "$SCRIPT_DIR/run_chat_component_smoke.sh" goldens
    ;;
  update)
    bash "$SCRIPT_DIR/run_chat_component_smoke.sh" update
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    echo ""
    show_help
    exit 1
    ;;
esac
