#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/antigravity"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/antigravity.desktop"
BIN_PATH="$HOME/.local/bin/antigravity"
ICON_PATH="$HOME/.local/share/icons/hicolor/1024x1024/apps/antigravity.png"
OLD_ICON_PATH="$HOME/.local/share/icons/hicolor/scalable/apps/antigravity.svg"

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

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

main() {
  info "Uninstalling Antigravity..."

  remove_path "$INSTALL_DIR"
  remove_path "$DESKTOP_FILE"
  remove_path "$BIN_PATH"
  remove_path "$ICON_PATH"
  remove_path "$OLD_ICON_PATH"

  refresh_desktop_caches

  info "Antigravity uninstalled."
}

main "$@"
