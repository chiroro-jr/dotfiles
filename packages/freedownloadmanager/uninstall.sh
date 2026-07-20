#!/bin/sh

set -e

INSTALL_DIR="$HOME/.local/share/freedownloadmanager"
BIN_PATH="$HOME/.local/bin/fdm"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/freedownloadmanager.desktop"
ICON_PATH="$HOME/.local/share/icons/hicolor/256x256/apps/freedownloadmanager.png"

if [ ! -d "$INSTALL_DIR" ] && [ ! -e "$BIN_PATH" ] && [ ! -L "$BIN_PATH" ]; then
  echo "Free Download Manager is not installed."
  exit 0
fi

rm -rf "$INSTALL_DIR"
rm -f "$BIN_PATH" "$DESKTOP_FILE" "$ICON_PATH"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
fi

echo "Free Download Manager uninstalled successfully."
