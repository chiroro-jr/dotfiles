#!/usr/bin/env bash

set -euo pipefail

BIN_PATH="$HOME/.local/bin/crit"
VERSION_DIR="$HOME/.local/share/crit"
VERSION_PATH="$VERSION_DIR/version.txt"

info() {
  echo "[INFO] $*"
}

usage() {
  cat <<'EOF'
Usage: ./uninstall-crit.sh

Removes the locally installed crit binary and version marker.
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

  info "Uninstalling crit..."

  remove_path "$BIN_PATH"
  remove_path "$VERSION_PATH"
  rmdir "$VERSION_DIR" >/dev/null 2>&1 || true

  info "crit uninstalled."
}

main "$@"
