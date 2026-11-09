#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# Validate that required env vars are set
: "${MIKU_KEY_ALIAS:?Need to set MIKU_KEY_ALIAS}"
: "${MIKU_KEY_PASSWORD:?Need to set MIKU_KEY_PASSWORD}"

keytool -genkeypair -v \
 -keystore release.keystore \
 -alias jezaku \
 -keyalg RSA \
 -keysize 2048 \
 -validity 10000 \
 -storepass "M!ku0n3Ummah" \
 -keypass "M!ku0n3Ummah" \
 -dname "CN=Miku One, OU=jezaku, O=jezaku, L=Jakarta, S=Jakarta, C=Indonesia"
