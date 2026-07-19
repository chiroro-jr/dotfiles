#!/usr/bin/env bash

set -euo pipefail

REPO="rclone/rclone"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_ROOT="$HOME/.local/share/rclone"
INSTALL_BIN_DIR="$HOME/.local/bin"
BIN_PATH="$INSTALL_BIN_DIR/rclone"
VERSION_PATH="$INSTALL_ROOT/version.txt"

info() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./install-rclone.sh

Installs the latest rclone directly from GitHub Releases into:
  ~/.local/share/rclone

And symlinks:
  ~/.local/bin/rclone
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

  error "curl or wget is required."
}

download_github_api_file() {
  local url="$1"
  local out="$2"

  if command -v curl >/dev/null 2>&1; then
    local headers=(
      -H "Accept: application/vnd.github+json"
      -H "X-GitHub-Api-Version: 2022-11-28"
    )
    [ -z "${GITHUB_TOKEN:-}" ] || headers+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    curl -fsSL --retry 3 --retry-delay 2 "${headers[@]}" "$url" -o "$out"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    local headers=(
      --header="Accept: application/vnd.github+json"
      --header="X-GitHub-Api-Version: 2022-11-28"
    )
    [ -z "${GITHUB_TOKEN:-}" ] || headers+=(--header="Authorization: Bearer $GITHUB_TOKEN")
    wget -qO "$out" "${headers[@]}" "$url"
    return
  fi

  error "curl or wget is required."
}

require_tools() {
  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse GitHub release metadata."
  command -v sha256sum >/dev/null 2>&1 || error "sha256sum is required to verify downloads."
  command -v unzip >/dev/null 2>&1 || error "unzip is required to extract rclone."
}

resolve_asset_name() {
  case "$(uname -s):$(uname -m)" in
    Linux:x86_64|Linux:amd64)
      printf '%s\n' "linux-amd64"
      ;;
    Linux:aarch64|Linux:arm64)
      printf '%s\n' "linux-arm64"
      ;;
    Linux:i386|Linux:i686)
      printf '%s\n' "linux-386"
      ;;
    Linux:armv6l)
      printf '%s\n' "linux-arm-v6"
      ;;
    Linux:armv7l)
      printf '%s\n' "linux-arm-v7"
      ;;
    *)
      error "Unsupported platform: $(uname -s) $(uname -m)."
      ;;
  esac
}

resolve_release_metadata() {
  local metadata_path="$1"
  local platform="$2"

  download_github_api_file "$RELEASE_API_URL" "$metadata_path"

  python3 - "$metadata_path" "$platform" <<'PY'
import json
import sys

path = sys.argv[1]
platform = sys.argv[2]

with open(path, "r", encoding="utf-8") as fh:
    release = json.load(fh)

tag = release["tag_name"]
version = tag.removeprefix("v")
asset_name = f"rclone-v{version}-{platform}.zip"
assets = release.get("assets", [])
asset = next((a for a in assets if a.get("name") == asset_name), None)
checksums = next((a for a in assets if a.get("name") == "SHA256SUMS"), None)

if asset is None:
    print(f"Asset {asset_name} was not found in latest release.", file=sys.stderr)
    sys.exit(1)
if checksums is None:
    print("SHA256SUMS was not found in latest release.", file=sys.stderr)
    sys.exit(1)

print(tag)
print(asset_name)
print(asset["browser_download_url"])
print(checksums["browser_download_url"])
PY
}

verify_checksum() {
  local checksums_path="$1"
  local archive_path="$2"
  local asset_name="$3"
  local expected

  expected="$(awk -v name="$asset_name" '$2 == name {print $1}' "$checksums_path")"
  [ -n "$expected" ] || error "Could not find checksum for ${asset_name}."

  printf '%s  %s\n' "$expected" "$archive_path" | sha256sum -c - >/dev/null
}

main() {
  local platform tmp_dir metadata_path archive_path checksums_path tag asset_name archive_url checksums_url extract_dir extracted_dir current_version

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *) error "Unknown option: $1" ;;
  esac

  require_tools
  platform="$(resolve_asset_name)"

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  metadata_path="$tmp_dir/release.json"

  info "Resolving latest rclone release from ${RELEASE_API_URL}..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$platform")
  [ "${#release_data[@]}" -ge 4 ] || error "Could not resolve latest rclone release metadata."

  tag="${release_data[0]}"
  asset_name="${release_data[1]}"
  archive_url="${release_data[2]}"
  checksums_url="${release_data[3]}"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ -x "$BIN_PATH" ]; then
    info "rclone is already up to date (${tag}). Skipping installation."
    return 0
  fi

  info "Updating rclone from ${current_version:-not installed} to ${tag}."

  archive_path="$tmp_dir/$asset_name"
  checksums_path="$tmp_dir/SHA256SUMS"
  extract_dir="$tmp_dir/extract"

  info "Downloading ${asset_name}..."
  download_file "$archive_url" "$archive_path" "progress"
  download_file "$checksums_url" "$checksums_path"

  info "Verifying checksum..."
  verify_checksum "$checksums_path" "$archive_path" "$asset_name"

  mkdir -p "$extract_dir"
  unzip -q "$archive_path" -d "$extract_dir"
  extracted_dir="$(find "$extract_dir" -maxdepth 1 -type d -name 'rclone-*' | head -n 1)"
  [ -n "$extracted_dir" ] || error "Release archive did not contain an rclone directory."
  [ -x "$extracted_dir/rclone" ] || error "Release archive did not contain executable rclone."

  info "Installing rclone to ${INSTALL_ROOT}..."
  rm -rf "$INSTALL_ROOT/app"
  mkdir -p "$INSTALL_ROOT" "$INSTALL_BIN_DIR"
  mv "$extracted_dir" "$INSTALL_ROOT/app"
  printf '%s\n' "$tag" > "$VERSION_PATH"

  if [ -e "$BIN_PATH" ] || [ -L "$BIN_PATH" ]; then
    if [ -L "$BIN_PATH" ] && [ "$(readlink "$BIN_PATH")" = "$INSTALL_ROOT/app/rclone" ]; then
      rm -f "$BIN_PATH"
    else
      error "$BIN_PATH already exists and is not this installer's symlink. Remove it manually first."
    fi
  fi

  ln -s "$INSTALL_ROOT/app/rclone" "$BIN_PATH"

  info "rclone installed successfully."
  info "Version: ${tag}"
  info "Path: ${BIN_PATH}"
  "$BIN_PATH" version | head -n 1
}

main "$@"
