#!/usr/bin/env bash

set -euo pipefail

BIN_PATH="$HOME/.local/bin/hitch"
VERSION_DIR="$HOME/.local/share/hitch"

case "${1:-}" in
  -h|--help)
    echo "Usage: ./packages/hitch/uninstall.sh"
    exit 0
    ;;
  "") ;;
  *)
    echo "[ERROR] Unknown option: $1" >&2
    exit 1
    ;;
esac

rm -f "$BIN_PATH"
rm -rf "$VERSION_DIR"
echo "[INFO] Hitch uninstalled."
