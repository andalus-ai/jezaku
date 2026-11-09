#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$PROJECT_DIR/.githooks"

show_help() {
  cat <<EOF
Install jezaku UI Git hooks

Usage:
  ./scripts/install_git_hooks.sh [options]

Options:
  --dry-run   Show what would change without writing git config
  -h, --help  Show this help

The pre-commit hook runs:
  ./scripts/check_quality.sh --staged-only --no-tests

Optional stricter modes:
  jezaku_PRECOMMIT_TESTS=1  Also run the smoke test
  jezaku_PRECOMMIT_FULL=1   Run the full Flutter test suite
  jezaku_PRECOMMIT_L10N=1   Regenerate localization before analysis
EOF
}

dry_run=false

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=true
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "" >&2
      show_help >&2
      exit 1
      ;;
  esac
  shift
done

cd "$PROJECT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git worktree: $PROJECT_DIR" >&2
  exit 1
fi

if [ ! -x "$HOOKS_DIR/pre-commit" ]; then
  chmod +x "$HOOKS_DIR/pre-commit"
fi

if [ "$dry_run" = true ]; then
  echo "Would set core.hooksPath to .githooks"
  echo "Would use hook: $HOOKS_DIR/pre-commit"
  exit 0
fi

git config core.hooksPath .githooks

echo "Installed jezaku UI Git hooks."
echo "Current core.hooksPath: $(git config --get core.hooksPath)"
