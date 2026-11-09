#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# Extract version from pubspec.yaml
VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')
DESTINATION_DIR="${ANDROID_RELEASE_OUTPUT_DIR:-$HOME/Library/CloudStorage/Dropbox/000/miku}"
mkdir -p "$DESTINATION_DIR"

echo "Detected version: $VERSION"

# Build the app bundle
flutter build appbundle --release --no-tree-shake-icons

# Check if build was successful
# Define destination
DEST="$DESTINATION_DIR/miku-release-v$VERSION.aab"

# Copy the file
cp build/app/outputs/bundle/release/app-release.aab "$DEST"

echo "✅ Build successful!"
echo "📂 Copied to: $DEST"
