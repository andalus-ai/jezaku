#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WIDGET_TESTS=(
  "test/chat/widgets/chat_list_quick_filters_test.dart"
  "test/chat/widgets/chat_list_search_bar_test.dart"
  "test/chat/widgets/chat_list_section_header_test.dart"
  "test/chat/widgets/chat_list_state_panel_test.dart"
  "test/chat/widgets/chat_list_tab_bar_test.dart"
  "test/chat/widgets/chat_list_app_bar_test.dart"
  "test/chat/widgets/chat_list_app_bar_actions_test.dart"
  "test/chat/widgets/chat_room_list_item_test.dart"
  "test/chat/widgets/social_connection_list_item_test.dart"
)

GOLDEN_TESTS=(
  "test/chat/widgets/chat_list_component_gallery_golden_test.dart"
  "test/chat/widgets/chat_list_row_gallery_golden_test.dart"
)

show_help() {
  echo -e "${BLUE}Chat Component Smoke Runner${NC}"
  echo ""
  echo "Usage:"
  echo "  ./scripts/run_chat_component_smoke.sh [verify|update|widgets|goldens|help]"
  echo ""
  echo "Options:"
  echo "  verify   Run analyzer, focused widget tests, and gallery goldens"
  echo "  update   Rebuild the component gallery goldens"
  echo "  widgets  Run analyzer and focused widget tests only"
  echo "  goldens  Run gallery goldens without updating baselines"
  echo "  help     Show this help"
}

run_cmd() {
  local description=$1
  shift

  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}${description}${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  "$@"
}

run_analyze() {
  run_cmd \
    "Analyzing focused chat widget harnesses" \
    dart analyze \
    test/chat/widgets/chat_list_quick_filters_test.dart \
    test/chat/widgets/chat_list_search_bar_test.dart \
    test/chat/widgets/chat_list_section_header_test.dart \
    test/chat/widgets/chat_list_state_panel_test.dart \
    test/chat/widgets/chat_list_tab_bar_test.dart \
    test/chat/widgets/chat_list_app_bar_test.dart \
    test/chat/widgets/chat_list_app_bar_actions_test.dart \
    test/chat/widgets/chat_room_list_item_test.dart \
    test/chat/widgets/social_connection_list_item_test.dart \
    test/chat/widgets/chat_list_component_gallery_golden_test.dart \
    test/chat/widgets/chat_list_row_gallery_golden_test.dart \
    dart_test.yaml
}

run_widget_tests() {
  local test_file
  for test_file in "${WIDGET_TESTS[@]}"; do
    run_cmd "Running ${test_file}" flutter test "$test_file" --reporter=compact
  done
}

run_golden_tests() {
  local update_flag="${1:-}"
  local test_file
  for test_file in "${GOLDEN_TESTS[@]}"; do
    run_cmd "Running ${test_file}" flutter test "$test_file" ${update_flag} --reporter=compact
  done
}

cd "$PROJECT_DIR"

case "${1:-verify}" in
  verify)
    run_analyze
    run_widget_tests
    run_golden_tests
    echo -e "\n${GREEN}✅ Chat component smoke suite passed.${NC}"
    ;;
  update)
    run_analyze
    run_golden_tests "--update-goldens"
    echo -e "\n${GREEN}✅ Chat component gallery goldens updated.${NC}"
    ;;
  widgets)
    run_analyze
    run_widget_tests
    echo -e "\n${GREEN}✅ Focused chat widget tests passed.${NC}"
    ;;
  goldens)
    run_analyze
    run_golden_tests
    echo -e "\n${GREEN}✅ Chat component gallery goldens verified.${NC}"
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
