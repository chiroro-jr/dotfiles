#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="$HOME/.local/share/hunk"
BIN_PATH="$HOME/.local/bin/hunk"

info() {
  echo "[INFO] $*"
}

usage() {
  cat <<'EOF'
Usage: ./packages/hunk/uninstall.sh

Removes Hunk installed by packages/hunk/install.sh.
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

  info "Uninstalling Hunk..."

  remove_path "$BIN_PATH"
  remove_path "$INSTALL_ROOT"

  info "Hunk uninstalled."
}

main "$@"
