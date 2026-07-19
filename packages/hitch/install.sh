#!/usr/bin/env bash

set -euo pipefail

REPO="maxktz/hitch"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_DIR="$HOME/.local/bin"
BIN_PATH="$INSTALL_DIR/hitch"
VERSION_DIR="$HOME/.local/share/hitch"
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
Usage: ./packages/hitch/install.sh

Installs the latest Hitch binary from GitHub Releases to ~/.local/bin/hitch.

Options:
  -h, --help  Show this help message.
EOF
}

download_file() {
  local url="$1"
  local out="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fL --progress-bar --retry 3 --retry-delay 2 "$url" -o "$out"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget --show-progress -O "$out" "$url"
    return
  fi

  error "curl or wget is required to download Hitch."
}

download_release_metadata() {
  local out="$1"

  if command -v curl >/dev/null 2>&1; then
    local headers=(
      -H "Accept: application/vnd.github+json"
      -H "X-GitHub-Api-Version: 2022-11-28"
    )
    [ -z "${GITHUB_TOKEN:-}" ] || headers+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    curl -fsSL --retry 3 --retry-delay 2 "${headers[@]}" "$RELEASE_API_URL" -o "$out"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$out" \
      --header="Accept: application/vnd.github+json" \
      --header="X-GitHub-Api-Version: 2022-11-28" \
      "$RELEASE_API_URL"
    return
  fi

  error "curl or wget is required to resolve the latest Hitch release."
}

resolve_asset_name() {
  case "$(uname -m)" in
    x86_64|amd64) printf '%s\n' "hitch-linux-x64" ;;
    aarch64|arm64) printf '%s\n' "hitch-linux-arm64" ;;
    *) error "Unsupported architecture: $(uname -m)." ;;
  esac
}

resolve_release_metadata() {
  local metadata_path="$1"
  local asset_name="$2"

  python3 - "$metadata_path" "$asset_name" <<'PY'
import json
import sys

path, asset_name = sys.argv[1:]
with open(path, "r", encoding="utf-8") as fh:
    release = json.load(fh)

asset = next((item for item in release.get("assets", []) if item.get("name") == asset_name), None)
if asset is None:
    print(f"Asset {asset_name} was not found in the latest release.", file=sys.stderr)
    sys.exit(1)

digest = asset.get("digest", "")
if not digest.startswith("sha256:"):
    print(f"Release asset {asset_name} has no SHA-256 digest.", file=sys.stderr)
    sys.exit(1)

print(release["tag_name"])
print(asset["browser_download_url"])
print(digest.removeprefix("sha256:"))
PY
}

main() {
  local asset_name tmp_dir metadata_path tmp_binary tag binary_url expected actual current_version

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *) error "Unknown option: $1" ;;
  esac

  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse release metadata."
  command -v sha256sum >/dev/null 2>&1 || error "sha256sum is required to verify Hitch."

  asset_name="$(resolve_asset_name)"
  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT
  metadata_path="$tmp_dir/release.json"
  tmp_binary="$tmp_dir/$asset_name"

  info "Resolving latest Hitch release..."
  download_release_metadata "$metadata_path"
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$asset_name")
  [ "${#release_data[@]}" -eq 3 ] || error "Could not resolve Hitch release metadata."

  tag="${release_data[0]}"
  binary_url="${release_data[1]}"
  expected="${release_data[2]}"
  current_version=""
  [ ! -f "$VERSION_PATH" ] || current_version="$(cat "$VERSION_PATH")"

  if [ "$current_version" = "$tag" ] && [ -x "$BIN_PATH" ]; then
    info "Hitch is already up to date (${tag}). Skipping installation."
    return 0
  fi

  info "Downloading ${asset_name} (${tag})..."
  download_file "$binary_url" "$tmp_binary"

  actual="$(sha256sum "$tmp_binary" | awk '{print $1}')"
  [ "$actual" = "$expected" ] || error "SHA-256 verification failed for ${asset_name}."

  mkdir -p "$INSTALL_DIR" "$VERSION_DIR"
  install -m 0755 "$tmp_binary" "$BIN_PATH"
  printf '%s\n' "$tag" > "$VERSION_PATH"

  info "Hitch installed successfully."
  info "Version: ${tag}${current_version:+ (previously ${current_version})}"
  info "Path: ${BIN_PATH}"
}

main "$@"
