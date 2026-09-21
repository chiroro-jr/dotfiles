#!/usr/bin/env bash

set -euo pipefail

REPO="Nimblesite/Deslop"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"

INSTALL_ROOT="$HOME/.local/share/deslop"
VERSION_PATH="$INSTALL_ROOT/version.txt"
APP_DIR="$INSTALL_ROOT/app"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/deslop"
LSP_PATH="$BIN_DIR/deslop-lsp"
MCP_PATH="$BIN_DIR/deslop-mcp"

info() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./packages/deslop/install.sh

Installs the latest Deslop Linux binaries from GitHub Releases.

Installed paths:
  CLI:   ~/.local/bin/deslop
  LSP:   ~/.local/bin/deslop-lsp
  MCP:   ~/.local/bin/deslop-mcp
  Data:  ~/.local/share/deslop

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
    [ -z "${GITHUB_RELEASES_TOKEN:-}" ] || headers+=( -H "Authorization: Bearer $GITHUB_RELEASES_TOKEN" )
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

  error "curl or wget is required to download release metadata."
}

require_tools() {
  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse GitHub release metadata."
  command -v sha256sum >/dev/null 2>&1 || error "sha256sum is required to verify downloads."
  command -v tar >/dev/null 2>&1 || error "tar is required to extract the release archive."
}

resolve_arch() {
  [ "$(uname -s)" = "Linux" ] || error "Unsupported operating system: $(uname -s)."

  case "$(uname -m)" in
    x86_64|amd64)
      printf '%s\n' "x64"
      ;;
    aarch64|arm64)
      printf '%s\n' "arm64"
      ;;
    *)
      error "Unsupported architecture: $(uname -m)."
      ;;
  esac
}

resolve_release_metadata() {
  local metadata_path="$1"
  local arch="$2"

  download_github_api_file "$RELEASE_API_URL" "$metadata_path"

  python3 - "$metadata_path" "$arch" <<'PY'
import json
import sys

path, arch = sys.argv[1:]

with open(path, "r", encoding="utf-8") as fh:
    release = json.load(fh)

tag = release["tag_name"]

assets = release.get("assets", [])
archive_name = None
archive_url = None
checksum_name = None
checksum_url = None

for asset in assets:
    name = asset.get("name", "")
    if not name.endswith(f"-linux-{arch}.tar.gz"):
        continue
    if not name.startswith("deslop-"):
        continue
    if name.count("-") < 2:
        continue
    archive_name = name
    archive_url = asset.get("browser_download_url")
    break

if archive_name is None:
    print(f"No Deslop Linux {arch} tarball found in latest release.", file=sys.stderr)
    sys.exit(1)

checksum_name = f"{archive_name}.sha256"
checksum = next((a for a in assets if a.get("name") == checksum_name), None)
if checksum is None:
    print(f"Checksum file not found for {archive_name} in latest release.", file=sys.stderr)
    sys.exit(1)
checksum_url = checksum.get("browser_download_url")

if not archive_url or not checksum_url:
    print("Found release assets are missing download URLs.", file=sys.stderr)
    sys.exit(1)

print(tag)
print(archive_name)
print(archive_url)
print(checksum_name)
print(checksum_url)
PY
}

verify_checksum() {
  local checksums_path="$1"
  local archive_path="$2"
  local archive_name="$3"
  local expected

  expected="$(awk -v name="$archive_name" '$1 ~ /^[0-9a-fA-F]{64}$/ && $2 == name {print $1}' "$checksums_path")"
  [ -n "$expected" ] || error "Could not find checksum for ${archive_name}."

  printf '%s  %s\n' "$expected" "$archive_path" | sha256sum -c - >/dev/null
}

install_binary() {
  local src="$1"
  local dst="$2"

  [ -f "$src" ] || error "Expected binary is missing: $src"
  install -m 0755 "$src" "$dst.tmp"
  mv -f "$dst.tmp" "$dst"
}

main() {
  local arch tmp_dir metadata_path current_version release_data tag
  local archive_name archive_url checksum_name checksum_url
  local tmp_archive tmp_checksum deslop_archive_dir

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "")
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac

  require_tools
  arch="$(resolve_arch)"

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT
  metadata_path="$tmp_dir/release.json"

  info "Resolving latest Deslop release from ${RELEASE_API_URL}..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$arch")
  [ "${#release_data[@]}" -ge 5 ] || error "Could not resolve latest Deslop release metadata."

  tag="${release_data[0]}"
  archive_name="${release_data[1]}"
  archive_url="${release_data[2]}"
  checksum_name="${release_data[3]}"
  checksum_url="${release_data[4]}"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ -x "$BIN_PATH" ] && [ -x "$LSP_PATH" ] && [ -x "$MCP_PATH" ]; then
    info "Deslop is already up to date (${tag}). Skipping installation."
    return 0
  fi

  tmp_archive="$tmp_dir/$archive_name"
  tmp_checksum="$tmp_dir/$checksum_name"

  info "Downloading ${archive_name}..."
  download_file "$archive_url" "$tmp_archive" progress
  download_file "$checksum_url" "$tmp_checksum"

  info "Verifying checksum..."
  verify_checksum "$tmp_checksum" "$tmp_archive" "$archive_name"

  mkdir -p "$tmp_dir/extracted"
  tar -xzf "$tmp_archive" -C "$tmp_dir/extracted"

  deslop_archive_dir="$(find "$tmp_dir/extracted" -maxdepth 1 -mindepth 1 -type d -name "deslop-*linux-${arch}" -print -quit)"
  if [ -z "$deslop_archive_dir" ]; then
    error "Release archive did not contain an extracted Deslop directory."
  fi

  mkdir -p "$APP_DIR"
  rm -rf "$APP_DIR"
  mv "$deslop_archive_dir" "$APP_DIR"

  mkdir -p "$BIN_DIR"
  install_binary "$APP_DIR/deslop" "$BIN_PATH"
  install_binary "$APP_DIR/deslop-lsp" "$LSP_PATH"
  install_binary "$APP_DIR/deslop-mcp" "$MCP_PATH"
  printf '%s\n' "$tag" > "$VERSION_PATH"

  info "Deslop installed successfully."
  info "Version: ${tag}"
  info "Binary: ${BIN_PATH}"
  info "LSP: ${LSP_PATH}"
  info "MCP: ${MCP_PATH}"
}

main "$@"
