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

if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "Removing previous installation..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

cp -r "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

echo "Installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "Launching $APP_NAME..."
open "$INSTALL_DIR/$APP_NAME.app"
