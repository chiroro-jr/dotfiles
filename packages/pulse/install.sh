#!/bin/sh

set -eu

INSTALLER_URL="https://github.com/egoist/pulse-feedback/releases/latest/download/install.sh"
APP_PATH="$HOME/.local/pulse.app/pulse"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
trap 'exit 1' HUP INT TERM

# Pulse renders through WebKitGTK, which upstream's installer only warns about.
# yay asks for sudo even with --needed, so skip it when already installed.
if ! pacman -Q webkit2gtk-4.1 >/dev/null 2>&1; then
    yay -S --noconfirm --needed webkit2gtk-4.1
fi

# Upstream's installer owns the layout (~/.local/pulse.app plus its desktop
# entry) that Pulse's built-in updater expects.
curl --fail --silent --show-error --location --retry 3 \
    "$INSTALLER_URL" -o "$TMP_DIR/install.sh"

# Upstream's installer always reinstalls, so skip it when the build info Go
# embeds in the binary already matches the version the installer ships.
latest_version="$(sed -n "s/^version='\(.*\)'$/\1/p" "$TMP_DIR/install.sh")"
installed_version=""
if [ -f "$APP_PATH" ]; then
    installed_version="$(LC_ALL=C grep -ao "$(printf 'mod\tpulse\tv')[0-9.]*" "$APP_PATH" |
        head -n 1 | cut -f 3 | sed 's/^v//')"
fi
if [ -n "$latest_version" ] && [ "$installed_version" = "$latest_version" ]; then
    echo "Pulse $installed_version is already up to date."
    exit 0
fi

sh "$TMP_DIR/install.sh"
