#!/bin/sh

set -eu

INSTALL_DIR="$HOME/.local/share/pen"
DESKTOP_DIR="$HOME/.local/share/applications"
BIN_DIR="$HOME/.local/bin"

echo "Uninstalling Pen..."
rm -rf "$INSTALL_DIR"
rm -f "$DESKTOP_DIR/pen.desktop"
if [ -L "$BIN_DIR/pen-desktop" ]; then
    rm "$BIN_DIR/pen-desktop"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR"
fi

echo "Pen uninstalled."
