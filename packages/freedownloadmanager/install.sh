#!/bin/sh

set -eu

DOWNLOAD_URL="https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"
INSTALL_DIR="$HOME/.local/share/freedownloadmanager"
APP_DIR="$INSTALL_DIR/app"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/fdm"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/freedownloadmanager.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
ICON_PATH="$ICON_DIR/freedownloadmanager.png"

if [ "$(uname -m)" != "x86_64" ]; then
  echo "Free Download Manager only provides an x86_64 Linux build." >&2
  exit 1
fi

for command in ar curl tar; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command is not installed: $command" >&2
    exit 1
  fi
done

# Runtime dependencies used by the official package.
yay -S --noconfirm --needed \
  openssl \
  xdg-utils \
  ffmpeg \
  libtorrent \
  gst-plugins-base \
  qt6-wayland

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

deb_path="$tmp_dir/freedownloadmanager.deb"
payload_dir="$tmp_dir/payload"
mkdir -p "$payload_dir"

echo "Downloading Free Download Manager..."
curl --fail --location --output "$deb_path" "$DOWNLOAD_URL"

data_member=$(ar t "$deb_path" | awk '/^data\.tar(\.|$)/ { print; exit }')
if [ -z "$data_member" ]; then
  echo "Downloaded DEB does not contain a data archive." >&2
  exit 1
fi

data_archive="$tmp_dir/$data_member"
ar p "$deb_path" "$data_member" > "$data_archive"
tar -xf "$data_archive" -C "$payload_dir"

if [ ! -x "$payload_dir/opt/freedownloadmanager/fdm" ]; then
  echo "Downloaded DEB does not contain the FDM executable." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"
rm -rf "$APP_DIR"
mv "$payload_dir/opt/freedownloadmanager" "$APP_DIR"
ln -sfn "$APP_DIR/fdm" "$BIN_PATH"
cp "$APP_DIR/icon.png" "$ICON_PATH"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Free Download Manager
Comment=FDM is a powerful modern download accelerator and organizer
Keywords=download;manager;free;fdm;
Exec=$BIN_PATH
Terminal=false
Type=Application
Icon=freedownloadmanager
Categories=Network;FileTransfer;P2P;
StartupNotify=true
StartupWMClass=fdm
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
fi

echo "Free Download Manager installed successfully."
