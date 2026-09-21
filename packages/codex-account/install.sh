#!/usr/bin/env bash

set -euo pipefail

REPO="webville-dev/codex-account"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_DIR="$HOME/.local/bin"
BIN_PATH="$INSTALL_DIR/codex-account"
VERSION_DIR="$HOME/.local/share/codex-account"
VERSION_PATH="$VERSION_DIR/version.txt"
FISH_FUNCTION_PATH="$HOME/.config/fish/functions/codex-account.fish"
FISH_HELPER_PATH="$HOME/.config/fish/functions/__codex_account.py"
FISH_COMPLETIONS_PATH="$HOME/.config/fish/completions/codex-account.fish"

info() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./packages/codex-account/install.sh

Installs the latest codex-account binary from GitHub Releases to
~/.local/bin/codex-account. Does not build from source.

Requires GITHUB_RELEASES_TOKEN because the repository is private.

Options:
  -h, --help  Show this help message.
EOF
}

require_token() {
  [ -n "${GITHUB_RELEASES_TOKEN:-}" ] || error \
    "GITHUB_RELEASES_TOKEN is required to download private releases of ${REPO}."
}

download_github_api_file() {
  local url="$1"
  local out="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 --retry-delay 2 \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Authorization: Bearer $GITHUB_RELEASES_TOKEN" \
      "$url" -o "$out"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$out" \
      --header="Accept: application/vnd.github+json" \
      --header="X-GitHub-Api-Version: 2022-11-28" \
      --header="Authorization: Bearer $GITHUB_RELEASES_TOKEN" \
      "$url"
    return
  fi

  error "curl or wget is required to download files."
}

download_github_asset() {
  local url="$1"
  local out="$2"
  local mode="${3:-quiet}"

  if command -v curl >/dev/null 2>&1; then
    if [ "$mode" = "progress" ]; then
      curl -fL --progress-bar --retry 3 --retry-delay 2 \
        -H "Accept: application/octet-stream" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Authorization: Bearer $GITHUB_RELEASES_TOKEN" \
        "$url" -o "$out"
    else
      curl -fsSL --retry 3 --retry-delay 2 \
        -H "Accept: application/octet-stream" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Authorization: Bearer $GITHUB_RELEASES_TOKEN" \
        "$url" -o "$out"
    fi
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    if [ "$mode" = "progress" ]; then
      wget --show-progress -O "$out" \
        --header="Accept: application/octet-stream" \
        --header="X-GitHub-Api-Version: 2022-11-28" \
        --header="Authorization: Bearer $GITHUB_RELEASES_TOKEN" \
        "$url"
    else
      wget -qO "$out" \
        --header="Accept: application/octet-stream" \
        --header="X-GitHub-Api-Version: 2022-11-28" \
        --header="Authorization: Bearer $GITHUB_RELEASES_TOKEN" \
        "$url"
    fi
    return
  fi

  error "curl or wget is required to download files."
}

require_tools() {
  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse GitHub release metadata."
  command -v sha256sum >/dev/null 2>&1 || error "sha256sum is required to verify the download."
  command -v tar >/dev/null 2>&1 || error "tar is required to extract the release archive."
}

resolve_linux_arch() {
  [ "$(uname -s)" = "Linux" ] || error "Unsupported operating system: $(uname -s)."

  case "$(uname -m)" in
    x86_64|amd64) printf '%s\n' "amd64" ;;
    aarch64|arm64) printf '%s\n' "arm64" ;;
    *) error "Unsupported architecture: $(uname -m)." ;;
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
version = tag.removeprefix("v")
archive_name = f"codex-account_{version}_linux_{arch}.tar.gz"
checksums_name = f"codex-account_{version}_SHA256SUMS"
assets = release.get("assets", [])
archive = next((item for item in assets if item.get("name") == archive_name), None)
checksums = next((item for item in assets if item.get("name") == checksums_name), None)

if archive is None or not archive.get("url"):
    print(f"Asset {archive_name} was not found in the latest release.", file=sys.stderr)
    sys.exit(1)
if checksums is None or not checksums.get("url"):
    print(f"Asset {checksums_name} was not found in the latest release.", file=sys.stderr)
    sys.exit(1)

print(tag)
print(archive_name)
print(archive["url"])
print(checksums_name)
print(checksums["url"])
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

remove_legacy_fish_cli() {
  local path
  for path in "$FISH_FUNCTION_PATH" "$FISH_HELPER_PATH"; do
    if [ -e "$path" ] || [ -L "$path" ]; then
      rm -f "$path"
      info "Removed leftover Fish CLI file: $path"
    fi
  done
}

install_fish_completions() {
  local tmp_completions="$1"

  mkdir -p "$(dirname "$FISH_COMPLETIONS_PATH")"
  "$BIN_PATH" completion fish >"$tmp_completions"
  rm -f "$FISH_COMPLETIONS_PATH"
  install -m 0644 "$tmp_completions" "$FISH_COMPLETIONS_PATH"
  info "Wrote Fish completions: $FISH_COMPLETIONS_PATH"
}

main() {
  local arch tmp_dir metadata_path archive_path checksums_path extract_dir extracted_path
  local tag archive_name archive_url checksums_name checksums_url current_version

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *) error "Unknown option: $1" ;;
  esac

  require_token
  require_tools
  arch="$(resolve_linux_arch)"

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT
  metadata_path="$tmp_dir/release.json"

  info "Resolving latest codex-account release from ${RELEASE_API_URL}..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$arch")
  [ "${#release_data[@]}" -ge 5 ] || error "Could not resolve latest codex-account release metadata."

  tag="${release_data[0]}"
  archive_name="${release_data[1]}"
  archive_url="${release_data[2]}"
  checksums_name="${release_data[3]}"
  checksums_url="${release_data[4]}"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  remove_legacy_fish_cli

  if [ "$current_version" = "$tag" ] && [ -x "$BIN_PATH" ]; then
    info "codex-account is already up to date (${tag}). Skipping download."
    install_fish_completions "$tmp_dir/codex-account.fish"
    return 0
  fi

  info "Updating codex-account from ${current_version:-not installed} to ${tag}."

  archive_path="$tmp_dir/$archive_name"
  checksums_path="$tmp_dir/$checksums_name"
  extract_dir="$tmp_dir/extract"

  info "Downloading ${archive_name}..."
  download_github_asset "$archive_url" "$archive_path" "progress"
  download_github_asset "$checksums_url" "$checksums_path"

  info "Verifying checksum..."
  verify_checksum "$checksums_path" "$archive_path" "$archive_name"

  mkdir -p "$extract_dir"
  tar -xzf "$archive_path" -C "$extract_dir"
  extracted_path="$(find "$extract_dir" -type f -name 'codex-account' | head -n 1)"
  [ -n "$extracted_path" ] || error "Release archive did not contain a codex-account binary."
  [ -x "$extracted_path" ] || chmod +x "$extracted_path"

  mkdir -p "$INSTALL_DIR" "$VERSION_DIR"
  install -m 0755 "$extracted_path" "$BIN_PATH"
  printf '%s\n' "$tag" >"$VERSION_PATH"
  install_fish_completions "$tmp_dir/codex-account.fish"

  info "codex-account installed successfully."
  info "Version: ${tag}"
  info "Path: ${BIN_PATH}"
}

main "$@"
