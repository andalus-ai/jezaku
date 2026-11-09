#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENABLE_FCM_PUSH="${ENABLE_FCM_PUSH:-false}"

exec "$SCRIPT_DIR/run_android_device.sh" \
  --host http://localhost:7100 \
  --realm jezaku \
  --install-start \
  --profile \
  --dart-define=PROFILE_MODE=demo \
  --dart-define=USE_DUMMY_DATA=true \
  --dart-define=OFFLINE_MODE=true \
  "$@"
