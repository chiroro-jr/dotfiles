#!/usr/bin/env bash

set -euo pipefail

BIN_PATH="$HOME/.local/bin/codex-account"
VERSION_DIR="$HOME/.local/share/codex-account"
VERSION_PATH="$VERSION_DIR/version.txt"
FISH_FUNCTION_PATH="$HOME/.config/fish/functions/codex-account.fish"
FISH_HELPER_PATH="$HOME/.config/fish/functions/__codex_account.py"
FISH_COMPLETIONS_PATH="$HOME/.config/fish/completions/codex-account.fish"

info() {
  echo "[INFO] $*"
}

usage() {
  cat <<'EOF'
Usage: ./packages/codex-account/uninstall.sh

Removes the locally installed codex-account binary, version marker, and
generated Fish completions. Saved accounts in ~/.config/codex-account/ are
left in place.
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

  info "Uninstalling codex-account..."

  remove_path "$BIN_PATH"
  remove_path "$VERSION_PATH"
  rmdir "$VERSION_DIR" >/dev/null 2>&1 || true
  remove_path "$FISH_FUNCTION_PATH"
  remove_path "$FISH_HELPER_PATH"
  remove_path "$FISH_COMPLETIONS_PATH"

  info "codex-account uninstalled."
}

main "$@"
