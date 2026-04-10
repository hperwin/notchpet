#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="NotchPet"
APP_BUNDLE="$PROJECT_DIR/.build/${APP_NAME}.app"
INSTALL_DIR="/Applications"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "App bundle not found. Building first..."
    bash "$SCRIPT_DIR/bundle.sh"
fi

echo "Installing $APP_NAME to $INSTALL_DIR..."

# Kill running instance
killall "$APP_NAME" 2>/dev/null || true
sleep 1

if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "Removing previous installation..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

cp -r "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

echo "Installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "Launching $APP_NAME..."
open "$INSTALL_DIR/$APP_NAME.app"
echo ""
echo "IMPORTANT: Grant accessibility permission when prompted, or go to:"
echo "  System Settings → Privacy & Security → Accessibility → enable NotchPet"
echo ""
echo "If typing isn't tracked, toggle NotchPet OFF then ON in Accessibility settings."
