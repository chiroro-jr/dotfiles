#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="$HOME/.local/share/rclone"
BIN_PATH="$HOME/.local/bin/rclone"

info() {
  echo "[INFO] $*"
}

usage() {
  cat <<'EOF'
Usage: ./uninstall-rclone.sh

Removes rclone installed by packages/install-rclone.sh.
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

  info "Uninstalling rclone..."

  if [ -L "$BIN_PATH" ]; then
    target="$(readlink "$BIN_PATH")"
    case "$target" in
      "$INSTALL_ROOT"/*)
        remove_path "$BIN_PATH"
        ;;
      *)
        info "Skipped $BIN_PATH; it points outside this install: $target"
        ;;
    esac
  elif [ -e "$BIN_PATH" ]; then
    info "Skipped $BIN_PATH; it is not a symlink created by this installer."
  fi

  remove_path "$INSTALL_ROOT"

  info "rclone uninstalled."
}

main "$@"
