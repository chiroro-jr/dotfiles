#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="$HOME/.local/share/herdr"
BIN_PATH="$HOME/.local/bin/herdr"

info() {
  echo "[INFO] $*"
}

usage() {
  cat <<'EOF'
Usage: ./packages/herdr/uninstall.sh

Removes Herdr installed by packages/herdr/install.sh.
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

  info "Uninstalling Herdr..."

  remove_path "$BIN_PATH"
  remove_path "$INSTALL_ROOT"

  info "Herdr uninstalled."
}

main "$@"
