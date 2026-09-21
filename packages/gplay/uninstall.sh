#!/usr/bin/env bash

set -euo pipefail

BIN_PATH="$HOME/.local/bin/gplay"
VERSION_DIR="$HOME/.local/share/gplay"
VERSION_PATH="$VERSION_DIR/version.txt"

info() {
  echo "[INFO] $*"
}

usage() {
  cat <<'EOF'
Usage: ./packages/gplay/uninstall.sh

Removes the locally installed gplay binary and version marker.
Leaves user configuration and credentials in place.
EOF
}

remove_path() {
  local path="$1"

  if [ -e "$path" ] || [ -L "$path" ]; then
    rm -f "$path"
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

  info "Uninstalling gplay..."

  remove_path "$BIN_PATH"
  remove_path "$VERSION_PATH"
  rmdir "$VERSION_DIR" >/dev/null 2>&1 || true

  info "gplay uninstalled."
}

main "$@"
