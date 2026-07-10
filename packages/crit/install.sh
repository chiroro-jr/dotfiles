#!/usr/bin/env bash

set -euo pipefail

REPO="tomasz-tomczyk/crit"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_DIR="$HOME/.local/bin"
BIN_PATH="$INSTALL_DIR/crit"
VERSION_DIR="$HOME/.local/share/crit"
VERSION_PATH="$VERSION_DIR/version.txt"

info() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./install-crit.sh

Installs the latest crit binary from GitHub Releases to ~/.local/bin/crit.

Options:
  -h, --help  Show this help message.
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
  command -v sha256sum >/dev/null 2>&1 || error "sha256sum is required to verify the downloaded binary."
}

resolve_asset_name() {
  case "$(uname -m)" in
    x86_64|amd64)
      printf '%s\n' "crit-linux-amd64"
      ;;
    aarch64|arm64)
      printf '%s\n' "crit-linux-arm64"
      ;;
    *)
      error "Unsupported architecture: $(uname -m)."
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
checksums = next((a for a in assets if a.get("name") == "checksums.txt"), None)

if asset is None:
    print(f"Asset {asset_name} was not found in latest release.", file=sys.stderr)
    sys.exit(1)
if checksums is None:
    print("checksums.txt was not found in latest release.", file=sys.stderr)
    sys.exit(1)

print(release["tag_name"])
print(asset["browser_download_url"])
print(checksums["browser_download_url"])
PY
}

verify_checksum() {
  local checksums_path="$1"
  local binary_path="$2"
  local asset_name="$3"
  local expected

  expected="$(awk -v name="$asset_name" '$2 == name {print $1}' "$checksums_path")"
  [ -n "$expected" ] || error "Could not find checksum for ${asset_name}."

  printf '%s  %s\n' "$expected" "$binary_path" | sha256sum -c - >/dev/null
}

main() {
  local asset_name tmp_dir metadata_path tmp_binary checksums_path tag binary_url checksums_url current_version

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

  info "Resolving latest crit release from ${RELEASE_API_URL}..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$asset_name")

  [ "${#release_data[@]}" -ge 3 ] || error "Could not resolve latest crit release metadata."

  tag="${release_data[0]}"
  binary_url="${release_data[1]}"
  checksums_url="${release_data[2]}"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ -x "$BIN_PATH" ]; then
    info "Installed version already matches latest release (${tag}). Reinstalling to refresh local files."
  else
    info "Updating crit from ${current_version:-not installed} to ${tag}."
  fi

  tmp_binary="$tmp_dir/$asset_name"
  checksums_path="$tmp_dir/checksums.txt"

  info "Downloading ${asset_name}..."
  download_file "$binary_url" "$tmp_binary" "progress"
  download_file "$checksums_url" "$checksums_path"

  info "Verifying checksum..."
  verify_checksum "$checksums_path" "$tmp_binary" "$asset_name"

  mkdir -p "$INSTALL_DIR" "$VERSION_DIR"
  install -m 0755 "$tmp_binary" "$BIN_PATH"
  printf '%s\n' "$tag" > "$VERSION_PATH"

  info "crit installed successfully."
  info "Version: ${tag}"
  info "Path: ${BIN_PATH}"
}

main "$@"
