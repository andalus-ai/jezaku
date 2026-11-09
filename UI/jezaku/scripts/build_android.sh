#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# Extract version from pubspec.yaml
VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')

echo "Detected version: $VERSION"

# Build the APK (Fat APK for universal compatibility)
flutter build apk --release --no-tree-shake-icons

# Check if build was successful
# Define destination
DESTINATION_DIR="${ANDROID_RELEASE_OUTPUT_DIR:-$HOME/Library/CloudStorage/Dropbox/000/miku}"
mkdir -p "$DESTINATION_DIR"
DEST="$DESTINATION_DIR/miku-release-v$VERSION.apk"

# Copy the file
# Note: APK output path is different from AAB
cp build/app/outputs/flutter-apk/app-release.apk "$DEST"

echo "✅ Build successful!"
echo "📂 Copied to: $DEST"
