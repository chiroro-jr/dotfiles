#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/zed-preview"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/dev.zed.Zed-Preview.desktop"
BIN_PATH="$HOME/.local/bin/zed-preview"
ICON_PATH="$HOME/.local/share/icons/hicolor/512x512/apps/zed-preview.png"

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

usage() {
  cat <<'EOF'
Usage: ./uninstall-zed-preview.sh

Removes the locally installed Zed Preview app, launcher, desktop file, and icon.
Shared user configuration is left in place:
  ~/.config/zed
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

  info "Uninstalling Zed Preview..."

  remove_path "$INSTALL_DIR"
  remove_path "$DESKTOP_FILE"
  remove_path "$BIN_PATH"
  remove_path "$ICON_PATH"

  refresh_desktop_caches

  info "Zed Preview uninstalled."
  info "Shared user configuration was left in place: $HOME/.config/zed"
}

main "$@"
