#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/delta"
APP_DIR="$INSTALL_DIR/delta.app"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/dev.zed.Delta.desktop"
BIN_PATH="$HOME/.local/bin/delta"
ICON_NAME="dev.zed.Delta"
HICOLOR_DIR="$HOME/.local/share/icons/hicolor"
ICON_PATH="$HICOLOR_DIR/512x512/apps/${ICON_NAME}.png"
LEGACY_ICON_PATH="$HICOLOR_DIR/512x512/apps/delta.png"
FALLBACK_ICON_PATH="$HICOLOR_DIR/scalable/apps/${ICON_NAME}.svg"
LEGACY_FALLBACK_ICON_PATH="$HICOLOR_DIR/scalable/apps/delta.svg"

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./packages/delta/uninstall.sh

Removes Delta installed by packages/delta/install.sh.
Leaves user configuration and data in place:
  ~/.config/delta
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
    *) error "Unknown option: $1" ;;
  esac

  info "Uninstalling Delta..."

  remove_path "$APP_DIR"
  remove_path "$VERSION_PATH"
  remove_path "$DESKTOP_FILE"
  remove_path "$BIN_PATH"
  remove_path "$ICON_PATH"
  remove_path "$FALLBACK_ICON_PATH"
  remove_path "$LEGACY_ICON_PATH"
  remove_path "$LEGACY_FALLBACK_ICON_PATH"

  find "$HICOLOR_DIR" -name "${ICON_NAME}.*" -delete 2>/dev/null || true

  rmdir "$INSTALL_DIR" >/dev/null 2>&1 || true

  refresh_desktop_caches

  info "Delta uninstalled."
  info "User configuration and data were left in place."
}

main "$@"
