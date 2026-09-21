#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="$HOME/.local/share/deslop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/deslop"
LSP_PATH="$BIN_DIR/deslop-lsp"
MCP_PATH="$BIN_DIR/deslop-mcp"
VERSION_PATH="$INSTALL_ROOT/version.txt"

info() {
  echo "[INFO] $*"
}

usage() {
  cat <<'EOF'
Usage: ./packages/deslop/uninstall.sh

Removes Deslop CLI, LSP, and MCP binaries, and their install data directory.
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
    "")
      ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      exit 1
      ;;
  esac

  info "Uninstalling Deslop..."

  remove_path "$BIN_PATH"
  remove_path "$LSP_PATH"
  remove_path "$MCP_PATH"
  remove_path "$VERSION_PATH"
  remove_path "$INSTALL_ROOT"

  info "Deslop uninstalled."
}

main "$@"
