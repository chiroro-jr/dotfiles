#!/usr/bin/env bash

set -euo pipefail

RELEASE_URL="https://github.com/elianiva/meiro/releases/latest/download"
MANIFEST_URL="$RELEASE_URL/update-linux-amd64.json"
CHECKSUMS_URL="$RELEASE_URL/SHA256SUMS.txt"

# Meiro updates itself by replacing the folder its executable is in, so the
# app lives in its own writable folder and this script only installs it when
# missing or behind.
INSTALL_DIR="$HOME/.local/share/meiro"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/meiro.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/meiro"

# Runtime packages from upstream's README; all are in the official repos.
DEPENDENCIES=(
  gtk3
  libayatana-appindicator
  webkit2gtk-4.1
)

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

download_file() {
  curl -fL --progress-bar --retry 3 --retry-delay 2 "$1" -o "$2"
}

install_dependencies() {
  local -a missing

  mapfile -t missing < <(pacman -T "${DEPENDENCIES[@]}" || true)
  if [ "${#missing[@]}" -gt 0 ]; then
    info "Installing missing dependencies: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
  fi
}

# Prints the version and archive URL from the manifest Meiro's updater reads.
resolve_release() {
  curl -fsSL --retry 3 "$MANIFEST_URL" | python3 -I -c '
import json
import sys

manifest = json.load(sys.stdin)
print(manifest["version"])
print(manifest["url"])
'
}

# Meiro has no --version flag; the build embeds its version as a NUL-delimited
# string, which stays correct after the app updates itself.
is_installed_version() {
  [ -x "$INSTALL_DIR/meiro" ] || return 1
  python3 -I -c '
import sys

with open(sys.argv[1], "rb") as fh:
    sys.exit(0 if b"\0" + sys.argv[2].encode() + b"\0" in fh.read() else 1)
' "$INSTALL_DIR/meiro" "$1"
}

write_desktop_file() {
  sed \
    -e "s|^Exec=.*|Exec=$INSTALL_DIR/meiro %U|" \
    -e "s|^Icon=.*|Icon=$INSTALL_DIR/meiro.png|" \
    "$INSTALL_DIR/meiro.desktop" > "$DESKTOP_FILE"
}

main() {
  local tmp_dir version url archive sha256
  local -a release

  [ "$(uname -m)" = "x86_64" ] || error "This installer only supports x86_64."
  command -v python3 >/dev/null 2>&1 || error "python3 is required to read the release manifest."

  install_dependencies

  info "Resolving latest Meiro release..."
  mapfile -t release < <(resolve_release)
  [ "${#release[@]}" -eq 2 ] || error "Could not resolve the latest Meiro release."
  version="${release[0]}"
  url="${release[1]}"
  archive="${url##*/}"

  if is_installed_version "$version"; then
    info "Meiro is already up to date (${version})."
    return 0
  fi

  info "Installing Meiro ${version}."

  tmp_dir="$(mktemp -d)"
  # Expand now: tmp_dir is local and gone by the time the EXIT trap runs.
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" EXIT

  download_file "$url" "$tmp_dir/$archive"
  sha256="$(curl -fsSL --retry 3 "$CHECKSUMS_URL" | awk -v f="./$archive" '$2 == f { print $1 }')"
  [ -n "$sha256" ] || error "SHA256SUMS.txt has no entry for $archive."
  echo "$sha256  $tmp_dir/$archive" | sha256sum -c --quiet - || error "Checksum mismatch for $archive"

  mkdir -p "$tmp_dir/app"
  tar -xzf "$tmp_dir/$archive" -C "$tmp_dir/app"
  [ -x "$tmp_dir/app/meiro" ] || error "Archive has no meiro executable."

  if pgrep -f "^$INSTALL_DIR/meiro" >/dev/null 2>&1; then
    warn "Meiro is running; restart it to use ${version}."
  fi

  mkdir -p "$(dirname "$INSTALL_DIR")" "$DESKTOP_DIR" "$BIN_DIR"
  rm -rf "$INSTALL_DIR"
  mv "$tmp_dir/app" "$INSTALL_DIR"
  ln -sfn "$INSTALL_DIR/meiro" "$BIN_PATH"
  write_desktop_file

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi

  info "Meiro ${version} installed. Run 'meiro' or launch it from your application menu."
}

main "$@"
