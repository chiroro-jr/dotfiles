#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="$HOME/.local/share/fastpotify"
BIN_PATH="$HOME/.local/bin/fastpotify"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/fastpotify.desktop"
ICON_PATH="$HOME/.local/share/icons/hicolor/scalable/apps/fastpotify.svg"

info() {
  echo "[INFO] $*"
}

usage() {
  cat <<'EOF'
Usage: ./packages/fastpotify/uninstall.sh

Removes Fastpotify installed by packages/fastpotify/install.sh.
EOF
}

remove_path() {
  local path="$1"

  if [ -e "$path" ] || [ -L "$path" ]; then
    rm -rf "$path"
    info "Removed: $path"
  fi
}

main() {
  if [ "$#" -gt 1 ]; then
    echo "[ERROR] Expected no arguments or --help." >&2
    exit 1
  fi

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

  info "Uninstalling Fastpotify..."

  remove_path "$BIN_PATH"
  remove_path "$INSTALL_ROOT/version.txt"
  rmdir "$INSTALL_ROOT" >/dev/null 2>&1 || true
  remove_path "$DESKTOP_FILE"
  remove_path "$ICON_PATH"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi

  info "Fastpotify uninstalled."
}

main "$@"
