#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

STORE_PASSWORD="${MIKU_STORE_PASSWORD:-M!ku0n3Ummah}"

keytool -list -v \
 -keystore release.keystore \
 -storepass "$STORE_PASSWORD"


alias=$(keytool -list -keystore release.keystore -storepass "$STORE_PASSWORD" 2>/dev/null | grep ', PrivateKeyEntry' | cut -d',' -f1)
echo "Detected alias: $alias"
