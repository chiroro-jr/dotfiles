#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/meiro"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/meiro.desktop"
BIN_PATH="$HOME/.local/bin/meiro"

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

main() {
  info "Uninstalling Meiro..."

  # Meiro installs no services; only the app itself may still be running.
  if pkill -f "^$INSTALL_DIR/meiro" 2>/dev/null; then
    info "Stopped running Meiro."
  fi

  remove_path "$INSTALL_DIR"
  remove_path "$DESKTOP_FILE"
  remove_path "$BIN_PATH"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi

  info "Meiro uninstalled. Settings and sign-in in ~/.config/Meiro and caches in ~/.cache/Meiro were kept."
}

main "$@"
