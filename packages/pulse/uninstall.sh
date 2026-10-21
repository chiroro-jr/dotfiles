#!/bin/sh

set -eu

INSTALLER_URL="https://github.com/egoist/pulse-feedback/releases/latest/download/install.sh"

if [ ! -d "$HOME/.local/pulse.app" ]; then
    echo "Pulse is not installed."
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
trap 'exit 1' HUP INT TERM

pkill -TERM -x pulse || true

# Leaves settings in ~/.config/Pulse.
curl --fail --silent --show-error --location --retry 3 \
    "$INSTALLER_URL" -o "$TMP_DIR/install.sh"
sh "$TMP_DIR/install.sh" --uninstall
