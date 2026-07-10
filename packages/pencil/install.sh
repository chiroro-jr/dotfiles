#!/bin/sh

set -e

INSTALL_DIR="$HOME/.local/share/pencil"
DESKTOP_DIR="$HOME/.local/share/applications"
BIN_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
TAR_URL="https://5ykymftd1soethh5.public.blob.vercel-storage.com/Pencil-linux-x64.tar.gz"
ICON_URL="https://www.pencil.dev/favicon.ico"

echo "Installing Pencil..."

# Create directories if they don't exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$DESKTOP_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$ICON_DIR"

# Download and extract
echo "Downloading Pencil..."
curl \
    --fail \
    --location \
    --http1.1 \
    --retry 5 \
    --retry-delay 2 \
    --retry-all-errors \
    "$TAR_URL" \
    -o /tmp/pencil.tar.gz

echo "Extracting..."
tar -xzf /tmp/pencil.tar.gz -C "$INSTALL_DIR" --strip-components=1

# Clean up
rm /tmp/pencil.tar.gz

# Download icon
echo "Downloading icon..."
curl \
    --fail \
    --location \
    --http1.1 \
    --retry 5 \
    --retry-delay 2 \
    --retry-all-errors \
    "$ICON_URL" \
    -o "$ICON_DIR/pencil.ico" 2>/dev/null || echo "Warning: Could not download icon"

# Create desktop entry
cat > "$DESKTOP_DIR/pencil.desktop" << EOF
[Desktop Entry]
Name=Pencil
Comment=GUI Prototyping Tool
Exec=$INSTALL_DIR/pencil
Icon=$ICON_DIR/pencil.ico
Type=Application
Categories=Graphics;Development;
Terminal=false
StartupNotify=true
EOF

# Make executable
chmod +x "$INSTALL_DIR/pencil"
chmod +x "$DESKTOP_DIR/pencil.desktop"

# Create symlink in bin
ln -sf "$INSTALL_DIR/pencil" "$BIN_DIR/pencil"

# Update desktop database
echo "Updating desktop database..."
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR"
fi

# Update icon cache
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

echo "Pencil installed successfully!"
echo "You can launch it from your application menu or by running 'pencil'"
