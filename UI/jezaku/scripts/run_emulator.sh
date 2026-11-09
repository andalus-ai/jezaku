#!/bin/bash

set -euo pipefail

AVD_NAME="${1:-${ANDROID_AVD_NAME:-Pixel_Fold_API_35}}"

emulator -avd "$AVD_NAME" -read-only
