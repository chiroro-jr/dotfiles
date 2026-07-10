#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/opencode-desktop"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/opencode-desktop.desktop"
BIN_PATH="$HOME/.local/bin/opencode-desktop"
ICON_PATH="$HOME/.local/share/icons/hicolor/512x512/apps/opencode-desktop.png"

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
  info "Uninstalling OpenCode Desktop..."

  remove_path "$INSTALL_DIR"
  remove_path "$DESKTOP_FILE"
  remove_path "$BIN_PATH"
  remove_path "$ICON_PATH"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi

  info "OpenCode Desktop uninstalled."
}

main "$@"
