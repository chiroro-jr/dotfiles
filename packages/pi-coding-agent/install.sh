#!/usr/bin/env bash

set -euo pipefail

REPO="earendil-works/pi"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_ROOT="$HOME/.local/share/pi-coding-agent"
APP_DIR="$INSTALL_ROOT/pi"
VERSION_PATH="$INSTALL_ROOT/version.txt"
INSTALL_BIN_DIR="$HOME/.local/bin"
BIN_PATH="$INSTALL_BIN_DIR/pi"

info() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./install-pi-coding-agent.sh

Installs the latest Pi Coding Agent directly from GitHub Releases.
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

  error "curl or wget is required to download files."
}

require_tools() {
  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse GitHub release metadata."
  command -v sha256sum >/dev/null 2>&1 || error "sha256sum is required to verify downloads."
  command -v tar >/dev/null 2>&1 || error "tar is required to extract Pi."
}

resolve_asset_name() {
  case "$(uname -s):$(uname -m)" in
    Linux:x86_64|Linux:amd64)
      printf '%s\n' "pi-linux-x64.tar.gz"
      ;;
    Linux:aarch64|Linux:arm64)
      printf '%s\n' "pi-linux-arm64.tar.gz"
      ;;
    *)
      error "Unsupported platform: $(uname -s) $(uname -m)."
      ;;
  esac
}

resolve_release_metadata() {
  local metadata_path="$1"
  local asset_name="$2"

  download_github_api_file "$RELEASE_API_URL" "$metadata_path"

  python3 - "$metadata_path" "$asset_name" <<'PY'
import json
import sys

path = sys.argv[1]
asset_name = sys.argv[2]

with open(path, "r", encoding="utf-8") as fh:
    release = json.load(fh)

assets = release.get("assets", [])
asset = next((a for a in assets if a.get("name") == asset_name), None)
checksums = next((a for a in assets if a.get("name") == "SHA256SUMS"), None)

if asset is None:
    print(f"Asset {asset_name} was not found in latest release.", file=sys.stderr)
    sys.exit(1)
if checksums is None:
    print("SHA256SUMS was not found in latest release.", file=sys.stderr)
    sys.exit(1)

print(release["tag_name"])
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
  local asset_name tmp_dir metadata_path archive_path checksums_path tag archive_url checksums_url current_version

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *) error "Unknown option: $1" ;;
  esac

  require_tools
  asset_name="$(resolve_asset_name)"

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  metadata_path="$tmp_dir/release.json"

  info "Resolving latest Pi release from ${RELEASE_API_URL}..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$asset_name")

  [ "${#release_data[@]}" -ge 3 ] || error "Could not resolve latest Pi release metadata."

  tag="${release_data[0]}"
  archive_url="${release_data[1]}"
  checksums_url="${release_data[2]}"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ -x "$BIN_PATH" ]; then
    info "Pi is already up to date (${tag}). Skipping installation."
    return 0
  fi

  info "Updating Pi from ${current_version:-not installed} to ${tag}."

  archive_path="$tmp_dir/$asset_name"
  checksums_path="$tmp_dir/SHA256SUMS"

  info "Downloading ${asset_name}..."
  download_file "$archive_url" "$archive_path" "progress"
  download_file "$checksums_url" "$checksums_path"

  info "Verifying checksum..."
  verify_checksum "$checksums_path" "$archive_path" "$asset_name"

  info "Installing Pi to ${APP_DIR}..."
  rm -rf "$APP_DIR"
  mkdir -p "$INSTALL_ROOT" "$INSTALL_BIN_DIR"
  tar -xzf "$archive_path" -C "$INSTALL_ROOT"
  [ -x "$APP_DIR/pi" ] || error "Release archive did not contain executable pi/pi."
  rm -f "$BIN_PATH"
  ln -s "$APP_DIR/pi" "$BIN_PATH"
  printf '%s\n' "$tag" > "$VERSION_PATH"

  info "Pi installed successfully."
  info "Version: ${tag}"
  info "Path: ${BIN_PATH}"
}

main "$@"
