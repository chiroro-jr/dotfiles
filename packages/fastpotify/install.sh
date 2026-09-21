#!/usr/bin/env bash

set -euo pipefail

REPO="crmne/fastpotify"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_ROOT="$HOME/.local/share/fastpotify"
VERSION_PATH="$INSTALL_ROOT/version.txt"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/fastpotify"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/fastpotify.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
ICON_PATH="$ICON_DIR/fastpotify.svg"

info() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./packages/fastpotify/install.sh

Installs the latest Fastpotify binary directly from GitHub Releases.
EOF
}

download_file() {
  local url="$1"
  local out="$2"
  local mode="${3:-quiet}"

  if command -v curl >/dev/null 2>&1; then
    if [ "$mode" = "progress" ]; then
      curl -fL --progress-bar --retry 3 --retry-delay 2 "$url" -o "$out"
    else
      curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$out"
    fi
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    if [ "$mode" = "progress" ]; then
      wget --show-progress -O "$out" "$url"
    else
      wget -qO "$out" "$url"
    fi
    return
  fi

  error "curl or wget is required to download files."
}

download_github_api_file() {
  local url="$1"
  local out="$2"

  if command -v curl >/dev/null 2>&1; then
    local headers=(
      -H "Accept: application/vnd.github+json"
      -H "X-GitHub-Api-Version: 2022-11-28"
    )
    [ -z "${GITHUB_RELEASES_TOKEN:-}" ] || headers+=(-H "Authorization: Bearer $GITHUB_RELEASES_TOKEN")
    curl -fsSL --retry 3 --retry-delay 2 "${headers[@]}" "$url" -o "$out"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    local headers=(
      --header="Accept: application/vnd.github+json"
      --header="X-GitHub-Api-Version: 2022-11-28"
    )
    [ -z "${GITHUB_RELEASES_TOKEN:-}" ] || headers+=(--header="Authorization: Bearer $GITHUB_RELEASES_TOKEN")
    wget -qO "$out" "${headers[@]}" "$url"
    return
  fi

  error "curl or wget is required to download files."
}

require_tools() {
  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse GitHub release metadata."
  command -v sha256sum >/dev/null 2>&1 || error "sha256sum is required to verify the download."
  command -v tar >/dev/null 2>&1 || error "tar is required to extract Fastpotify."
}

resolve_target() {
  [ "$(uname -s)" = "Linux" ] || error "Unsupported operating system: $(uname -s)."

  case "$(uname -m)" in
    x86_64|amd64)
      printf '%s\n' "x86_64-unknown-linux-gnu"
      ;;
    aarch64|arm64)
      printf '%s\n' "aarch64-unknown-linux-gnu"
      ;;
    *)
      error "Unsupported architecture: $(uname -m)."
      ;;
  esac
}

resolve_release_metadata() {
  local metadata_path="$1"
  local target="$2"

  download_github_api_file "$RELEASE_API_URL" "$metadata_path"

  python3 - "$metadata_path" "$target" <<'PY'
import json
import sys

path = sys.argv[1]
target = sys.argv[2]

with open(path, "r", encoding="utf-8") as fh:
    release = json.load(fh)

asset_name = f"fastpotify-{release['tag_name']}-{target}.tar.gz"

asset = next(
    (item for item in release.get("assets", []) if item.get("name") == asset_name),
    None,
)
if asset is None:
    print(f"Asset {asset_name} was not found in the latest release.", file=sys.stderr)
    sys.exit(1)

digest = asset.get("digest") or ""
if not digest.startswith("sha256:") or len(digest) != 71:
    print(f"GitHub did not provide a SHA-256 digest for {asset_name}.", file=sys.stderr)
    sys.exit(1)

print(release["tag_name"])
print(asset["browser_download_url"])
print(digest.removeprefix("sha256:"))
print(asset_name)
PY
}

verify_checksum() {
  local archive_path="$1"
  local expected="$2"
  local actual

  actual="$(sha256sum "$archive_path" | awk '{print $1}')"
  [ "$actual" = "$expected" ] || error "Downloaded Fastpotify archive checksum did not match GitHub's digest."
}

main() {
  local target asset_name archive_dir tmp_dir metadata_path archive_path extracted_path
  local tag archive_url expected_checksum current_version
  local -a release_data

  [ "$#" -le 1 ] || error "Expected no arguments or --help."

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *) error "Unknown option: $1" ;;
  esac

  require_tools
  target="$(resolve_target)"

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT
  metadata_path="$tmp_dir/release.json"

  info "Resolving latest Fastpotify release from GitHub..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$target")
  [ "${#release_data[@]}" -eq 4 ] || error "Could not resolve latest Fastpotify release metadata."

  tag="${release_data[0]}"
  archive_url="${release_data[1]}"
  expected_checksum="${release_data[2]}"
  asset_name="${release_data[3]}"
  archive_dir="${asset_name%.tar.gz}"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ -f "$BIN_PATH" ] && [ -x "$BIN_PATH" ] && [ ! -L "$BIN_PATH" ] && [ -f "$DESKTOP_FILE" ] && [ -f "$ICON_PATH" ]; then
    info "Fastpotify is already up to date (${tag})."
    info "Binary: ${BIN_PATH}"
    return 0
  fi

  info "Updating Fastpotify from ${current_version:-not installed} to ${tag}."
  archive_path="$tmp_dir/$asset_name"

  info "Downloading ${asset_name}..."
  download_file "$archive_url" "$archive_path" progress

  info "Verifying checksum..."
  verify_checksum "$archive_path" "$expected_checksum"

  tar -xzf "$archive_path" -C "$tmp_dir"
  extracted_path="$tmp_dir/$archive_dir/fastpotify"
  [ -f "$extracted_path" ] || error "Release archive did not contain ${archive_dir}/fastpotify."
  [ -f "$tmp_dir/$archive_dir/packaging/icons/fastpotify.svg" ] || error "Release archive did not contain the Fastpotify icon."
  [ -f "$tmp_dir/$archive_dir/packaging/applications/fastpotify.desktop" ] || error "Release archive did not contain the desktop entry."

  info "Installing binary to ${BIN_PATH}..."
  mkdir -p "$INSTALL_ROOT" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"
  install -m 0755 "$extracted_path" "$BIN_PATH.tmp"
  mv -f "$BIN_PATH.tmp" "$BIN_PATH"
  install -m 0644 "$tmp_dir/$archive_dir/packaging/icons/fastpotify.svg" "$ICON_PATH"
  python3 - "$tmp_dir/$archive_dir/packaging/applications/fastpotify.desktop" "$DESKTOP_FILE" "$BIN_PATH" <<'PY'
from pathlib import Path
import sys

source, destination, binary = sys.argv[1:]
# Escape Exec arguments, then escape the desktop-entry string itself.
quoted = ''.join('\\' + char if char in '\\"`$' else char for char in binary)
quoted = quoted.replace('\\', '\\\\').replace('%', '%%')
lines = Path(source).read_text().splitlines()
Path(destination).write_text('\n'.join(
    f'Exec="{quoted}" %u' if line.startswith('Exec=') else line
    for line in lines
) + '\n')
PY
  printf '%s\n' "$tag" > "$VERSION_PATH"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi

  info "Fastpotify installed successfully."
  info "Version: ${tag}"
  info "Binary: ${BIN_PATH}"
}

main "$@"
