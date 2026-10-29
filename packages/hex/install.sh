#!/usr/bin/env bash

set -euo pipefail

RELEASE_URL="https://anoma.ly/release/hex/desktop"
INSTALLER_URL="https://anoma.ly/hex/files/install-linux.sh"
BIN_PATH="$HOME/.local/bin/hex"

# Runtime packages from upstream's Linux guide (docs/linux.md), plus the GTK
# libraries the release binary links against that the guide does not list.
DEPENDENCIES=(
  alsa-lib
  cairo
  curl
  glib2
  gtk-layer-shell
  gtk3
  jq
  libxkbcommon
  libxkbcommon-x11
  libx11
  libxcb
  openblas
  openssl
  util-linux
  vulkan-icd-loader
  wl-clipboard
  wtype
  xxd
)

info() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

install_dependencies() {
  local -a missing

  # yay asks for sudo even with --needed, so only call it for missing packages.
  mapfile -t missing < <(pacman -T "${DEPENDENCIES[@]}" || true)
  if [ "${#missing[@]}" -gt 0 ]; then
    info "Installing missing dependencies: ${missing[*]}"
    yay -S --noconfirm --needed "${missing[@]}"
  fi
}

# Mirrors upstream's installer: the stable channel once Hex publishes one,
# the dev channel until then.
latest_version() {
  local manifest

  manifest="$(curl -fsSL --retry 3 "$RELEASE_URL/stable.json" 2>/dev/null ||
    curl -fsSL --retry 3 "$RELEASE_URL/dev.json")" || return 1
  jq -er .release.version <<<"$manifest"
}

installed_version() {
  [ -x "$BIN_PATH" ] || return 0
  "$BIN_PATH" --version 2>/dev/null | awk 'NF { value=$NF } END { print value }' || true
}

main() {
  local tmp_dir version current_version

  [ "$(uname -m)" = "x86_64" ] || error "This installer only supports x86_64."

  install_dependencies

  info "Resolving latest Hex release..."
  version="$(latest_version)" || error "Could not resolve the latest Hex release."

  # Hex updates itself after the first install, so only install when missing
  # or behind (for example after a failed self-update).
  current_version="$(installed_version)"
  if [ "$current_version" = "$version" ]; then
    info "Hex is already up to date (${version})."
    return 0
  fi

  info "Updating Hex from ${current_version:-not installed} to ${version}."

  tmp_dir="$(mktemp -d)"
  # Expand now: tmp_dir is local and gone by the time the EXIT trap runs.
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" EXIT

  # Upstream's installer verifies the signed release, and owns the layout
  # Hex's updater expects: ~/.local/share/hex, ~/.local/bin/hex, the desktop
  # and autostart entries, and the hex.service user unit.
  curl -fsSL --retry 3 "$INSTALLER_URL" -o "$tmp_dir/install-linux.sh"
  sh "$tmp_dir/install-linux.sh"

  if systemctl --user is-active --quiet hex.service 2>/dev/null; then
    info "Restarting the running Hex service on ${version}..."
    "$BIN_PATH" restart
  fi

  info "Hex ${version} installed. Run 'hex model install' once, then 'hex'."
}

main "$@"
