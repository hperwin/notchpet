#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="NotchPet"
APP_BUNDLE="$PROJECT_DIR/.build/${APP_NAME}.app"

echo "Building $APP_NAME..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy SPM resource bundle next to the binary (where Bundle.module expects it)
if [ -d ".build/release/NotchPet_NotchPet.bundle" ]; then
    cp -r ".build/release/NotchPet_NotchPet.bundle" "$APP_BUNDLE/Contents/MacOS/"
fi

echo "App bundle created at: $APP_BUNDLE"
echo ""
echo "To install, run: ./Scripts/install.sh"
