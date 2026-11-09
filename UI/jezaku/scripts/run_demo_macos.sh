#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run_macos.sh" demo \
  --host http://localhost:7100 \
  --realm tsiqahub \
  --dart-define=OFFLINE_MODE=true \
  "$@"
