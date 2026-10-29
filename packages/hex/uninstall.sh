#!/usr/bin/env bash

set -euo pipefail

INSTALLER_URL="https://anoma.ly/hex/files/install-linux.sh"
BIN_PATH="$HOME/.local/bin/hex"

info() {
  echo "[INFO] $*"
}

main() {
  local tmp_dir

  if [ ! -e "$BIN_PATH" ] && [ ! -e "$HOME/.config/systemd/user/hex.service" ]; then
    info "Hex is not installed."
    return 0
  fi

  tmp_dir="$(mktemp -d)"
  # Expand now: tmp_dir is local and gone by the time the EXIT trap runs.
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" EXIT

  # Upstream's uninstall stops hex.service, but not a Hex started outside it.
  if [ -x "$BIN_PATH" ] && "$BIN_PATH" quit >/dev/null 2>&1; then
    info "Stopped running Hex."
  fi

  # Removes hex.service, the desktop and autostart entries, ~/.local/bin/hex
  # and the installed versions. Leaves models, logs and settings in
  # ~/.local/share/hex.
  curl -fsSL --retry 3 "$INSTALLER_URL" -o "$tmp_dir/install-linux.sh"
  sh "$tmp_dir/install-linux.sh" uninstall
}

main "$@"
