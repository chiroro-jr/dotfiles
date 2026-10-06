#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/t3-code"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/t3-code.desktop"
BIN_PATH="$HOME/.local/bin/t3-code"
ICON_PATH="$HOME/.local/share/icons/hicolor/512x512/apps/t3-code.png"

# T3 Code writes its own hidden t3code:// URL handler entry and icon on launch;
# t3code-url-handler.desktop is the name older releases used.
URL_HANDLER_FILES=(
  "$DESKTOP_DIR/com.t3tools.T3Code.desktop"
  "$DESKTOP_DIR/t3code-url-handler.desktop"
  "$HOME/.local/share/icons/com.t3tools.T3Code.desktop.png"
)

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
  local path

  info "Uninstalling T3 Code..."

  remove_path "$INSTALL_DIR"
  remove_path "$DESKTOP_FILE"
  remove_path "$BIN_PATH"
  remove_path "$ICON_PATH"

  for path in "${URL_HANDLER_FILES[@]}"; do
    remove_path "$path"
  done

  refresh_desktop_caches

  info "T3 Code uninstalled. Settings and threads in ~/.t3 and ~/.config/t3code-v2 were kept."
}

main "$@"
