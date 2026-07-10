#!/bin/sh

set -e

INSTALL_DIR="$HOME/.local/share/pencil"
DESKTOP_DIR="$HOME/.local/share/applications"
BIN_DIR="$HOME/.local/bin"

echo "Uninstalling Pencil..."

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
fi

# Remove desktop entry
if [ -f "$DESKTOP_DIR/pencil.desktop" ]; then
    echo "Removing desktop entry..."
    rm "$DESKTOP_DIR/pencil.desktop"
fi

# Remove symlink
if [ -L "$BIN_DIR/pencil" ]; then
    echo "Removing symlink..."
    rm "$BIN_DIR/pencil"
fi

echo "Pencil uninstalled successfully!"
