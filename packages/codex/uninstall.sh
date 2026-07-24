#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="$HOME/.local/share/codex"
BIN_PATH="$HOME/.local/bin/codex"
LEGACY_PACKAGE="openai-codex-bin"

info() {
  echo "[INFO] $*"
}

usage() {
  cat <<'EOF'
Usage: ./packages/codex/uninstall.sh

Removes Codex installed by packages/codex/install.sh and any legacy AUR package.
EOF
}

remove_path() {
  local path="$1"

  if [ -e "$path" ] || [ -L "$path" ]; then
    rm -rf "$path"
    info "Removed: $path"
  fi
}

remove_legacy_package() {
  if ! command -v pacman >/dev/null 2>&1 || ! pacman -Q "$LEGACY_PACKAGE" >/dev/null 2>&1; then
    return
  fi

  info "Removing legacy Omarchy/AUR package ${LEGACY_PACKAGE}..."
  if command -v yay >/dev/null 2>&1; then
    yay -Rns --noconfirm "$LEGACY_PACKAGE"
  else
    sudo pacman -Rns --noconfirm "$LEGACY_PACKAGE"
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

  info "Uninstalling Codex..."

  remove_path "$BIN_PATH"
  remove_path "$INSTALL_ROOT"
  remove_legacy_package

  info "Codex uninstalled."
}

main "$@"
