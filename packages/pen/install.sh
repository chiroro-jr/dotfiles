#!/bin/sh

set -eu

case "$(uname -sm)" in
    'Linux x86_64') ARCH=x64 ;;
    'Linux aarch64'|'Linux arm64') ARCH=arm64 ;;
    *) echo "Pen requires Linux x64 or ARM64." >&2; exit 1 ;;
esac

INSTALL_DIR="$HOME/.local/share/pen"
DESKTOP_DIR="$HOME/.local/share/applications"
BIN_DIR="$HOME/.local/bin"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
trap 'exit 1' HUP INT TERM

echo "Downloading Pen for $ARCH..."
curl --fail --location --retry 3 \
    "https://www.pen.dev/download/Pen-linux-$ARCH.tar.gz" \
    -o "$TMP_DIR/pen.tar.gz"
mkdir "$TMP_DIR/app"
tar -xzf "$TMP_DIR/pen.tar.gz" -C "$TMP_DIR/app" --strip-components=1
if [ ! -f "$TMP_DIR/app/pen" ]; then
    echo "Pen executable missing from tarball." >&2
    exit 1
fi
chmod +x "$TMP_DIR/app/pen"

curl --fail --location --retry 3 https://www.pen.dev/favicon.ico \
    -o "$TMP_DIR/app/pen.ico"

mkdir -p "$(dirname "$INSTALL_DIR")" "$DESKTOP_DIR" "$BIN_DIR"
rm -rf "$INSTALL_DIR"
mv "$TMP_DIR/app" "$INSTALL_DIR"

# The npm CLI owns the pen command.
ln -sfn "$INSTALL_DIR/pen" "$BIN_DIR/pen-desktop"
cat > "$DESKTOP_DIR/pen.desktop" <<EOF
[Desktop Entry]
Name=Pen
Comment=GUI Prototyping Tool
Exec="$INSTALL_DIR/pen" %U
Icon=$INSTALL_DIR/pen.ico
Type=Application
Categories=Graphics;Development;
Terminal=false
StartupNotify=true
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR"
fi

echo "Pen installed. Launch from the application menu or run pen-desktop."
