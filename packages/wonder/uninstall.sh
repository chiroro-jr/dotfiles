#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/wonder"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/wonder.desktop"
BIN_PATH="$HOME/.local/bin/wonder"
ICON_PATH="$HOME/.local/share/icons/hicolor/256x256/apps/wonder.png"

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
  info "Uninstalling Wonder..."

  # Wonder installs no services; only the app itself may still be running.
  if pkill -f "^$INSTALL_DIR/app/wonder" 2>/dev/null; then
    info "Stopped running Wonder."
  fi

  remove_path "$INSTALL_DIR"
  remove_path "$DESKTOP_FILE"
  remove_path "$BIN_PATH"
  remove_path "$ICON_PATH"

  refresh_desktop_caches

  info "Wonder uninstalled. Settings and sign-in in ~/.config/Wonder were kept."
}

main "$@"
