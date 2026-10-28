#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/fountible"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/fountible.desktop"
BIN_PATH="$HOME/.local/bin/fountible"

info() {
  echo "[INFO] $*"
}

remove_path() {
  local path="$1"

  if [ -e "$path" ] || [ -L "$path" ]; then
    rm -rf "$path"
    info "Removed: $path"
  fi
}

refresh_desktop_caches() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
}

main() {
  info "Uninstalling Fountible..."

  # Fountible installs no services; only the app itself may still be running.
  if pkill -f "^$INSTALL_DIR/app/fountible" 2>/dev/null; then
    info "Stopped running Fountible."
  fi

  remove_path "$INSTALL_DIR"
  remove_path "$DESKTOP_FILE"
  remove_path "$BIN_PATH"

  refresh_desktop_caches

  info "Fountible uninstalled. Settings and sign-in in ~/.config/Fountible were kept."
}

main "$@"
