#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/zennotes"
APP_DIR="$INSTALL_DIR/app"
APPIMAGE_PATH="$INSTALL_DIR/ZenNotes.AppImage"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/zennotes.desktop"
BIN_PATH="$HOME/.local/bin/zennotes"
ICON_PATH="$HOME/.local/share/icons/hicolor/512x512/apps/zennotes.png"

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

usage() {
  cat <<'EOF'
Usage: ./uninstall-zennotes.sh

Removes the locally installed ZenNotes app, launcher, desktop file, and icon.
Leaves user configuration and notes data in place.
EOF
}

remove_path() {
  local path="$1"

  if [ -e "$path" ] || [ -L "$path" ]; then
    if rm -rf "$path"; then
      info "Removed: $path"
    else
      warn "Failed to remove: $path"
    fi
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
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      exit 1
      ;;
  esac

  info "Uninstalling ZenNotes..."

  remove_path "$APP_DIR"
  remove_path "$APPIMAGE_PATH"
  remove_path "$VERSION_PATH"
  remove_path "$DESKTOP_FILE"
  remove_path "$BIN_PATH"
  remove_path "$ICON_PATH"

  rmdir "$INSTALL_DIR" >/dev/null 2>&1 || true

  refresh_desktop_caches

  info "ZenNotes uninstalled."
  info "User configuration and notes data were left in place."
}

main "$@"
