#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="$HOME/.local/share/pi-coding-agent"
BIN_PATH="$HOME/.local/bin/pi"

info() {
  echo "[INFO] $*"
}

usage() {
  cat <<'EOF'
Usage: ./uninstall-pi-coding-agent.sh

Removes Pi Coding Agent installed from GitHub Releases.
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

  info "Uninstalling Pi Coding Agent..."

  remove_path "$BIN_PATH"
  remove_path "$INSTALL_ROOT"

  info "Pi Coding Agent uninstalled."
}

main "$@"
