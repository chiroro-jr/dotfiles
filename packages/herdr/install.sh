#!/usr/bin/env bash

set -euo pipefail

REPO="ogulcancelik/herdr"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_ROOT="$HOME/.local/share/herdr"
VERSION_PATH="$INSTALL_ROOT/version.txt"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/herdr"

info() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./packages/herdr/install.sh

Installs the latest Herdr binary directly from GitHub Releases.
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
  command -v sha256sum >/dev/null 2>&1 || error "sha256sum is required to verify the download."
}

resolve_asset_name() {
  [ "$(uname -s)" = "Linux" ] || error "Unsupported operating system: $(uname -s)."

  case "$(uname -m)" in
    x86_64|amd64)
      printf '%s\n' "herdr-linux-x86_64"
      ;;
    aarch64|arm64)
      printf '%s\n' "herdr-linux-aarch64"
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

asset = next(
    (item for item in release.get("assets", []) if item.get("name") == asset_name),
    None,
)
if asset is None:
    print(f"Asset {asset_name} was not found in the latest release.", file=sys.stderr)
    sys.exit(1)

digest = asset.get("digest", "")
if not digest.startswith("sha256:") or len(digest) != 71:
    print(f"GitHub did not provide a SHA-256 digest for {asset_name}.", file=sys.stderr)
    sys.exit(1)

print(release["tag_name"])
print(asset["browser_download_url"])
print(digest.removeprefix("sha256:"))
PY
}

verify_checksum() {
  local binary_path="$1"
  local expected="$2"
  local actual

  actual="$(sha256sum "$binary_path" | awk '{print $1}')"
  [ "$actual" = "$expected" ] || error "Downloaded Herdr binary checksum did not match GitHub's digest."
}

main() {
  local asset_name tmp_dir metadata_path tmp_binary tag binary_url expected_checksum current_version

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

  info "Resolving latest Herdr release from GitHub..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$asset_name")
  [ "${#release_data[@]}" -ge 3 ] || error "Could not resolve latest Herdr release metadata."

  tag="${release_data[0]}"
  binary_url="${release_data[1]}"
  expected_checksum="${release_data[2]}"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ -f "$BIN_PATH" ] && [ -x "$BIN_PATH" ] && [ ! -L "$BIN_PATH" ]; then
    info "Herdr is already up to date (${tag})."
    info "Binary: ${BIN_PATH}"
    return 0
  fi

  info "Updating Herdr from ${current_version:-not installed} to ${tag}."
  tmp_binary="$tmp_dir/$asset_name"

  info "Downloading ${asset_name}..."
  download_file "$binary_url" "$tmp_binary" progress

  info "Verifying checksum..."
  verify_checksum "$tmp_binary" "$expected_checksum"

  info "Installing binary to ${BIN_PATH}..."
  mkdir -p "$INSTALL_ROOT" "$BIN_DIR"
  install -m 0755 "$tmp_binary" "$BIN_PATH.tmp"
  mv -f "$BIN_PATH.tmp" "$BIN_PATH"
  printf '%s\n' "$tag" > "$VERSION_PATH"

  "$BIN_PATH" --version >/dev/null || error "Installed Herdr binary failed its version check."

  info "Herdr installed successfully."
  info "Version: ${tag}"
  info "Binary: ${BIN_PATH}"
}

main "$@"
