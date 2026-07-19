#!/usr/bin/env bash

set -euo pipefail

REPO="VSCodium/vscodium"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"

INSTALL_DIR="$HOME/.local/share/vscodium"
APP_DIR="$INSTALL_DIR/app"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/codium.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/codium"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
EXTENSIONS_FILE="$SCRIPT_DIR/extensions.txt"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_PATH="$ICON_DIR/vscodium.png"

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

usage() {
  cat <<'EOF'
Usage: ./install-vscodium.sh

Downloads the latest VSCodium Linux tar.gz from GitHub Releases and installs it locally.

Installed paths:
  App:     ~/.local/share/vscodium/app
  CLI:     ~/.local/bin/codium
  Desktop: ~/.local/share/applications/codium.desktop
  Icon:    ~/.local/share/icons/hicolor/512x512/apps/vscodium.png

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

require_command() {
  command -v "$1" >/dev/null 2>&1 || error "$1 is required."
}

resolve_architecture() {
  case "$(uname -m)" in
    x86_64|amd64)
      VSCODIUM_ARCH="x64"
      ;;
    aarch64|arm64)
      VSCODIUM_ARCH="arm64"
      ;;
    armv7l|armhf)
      VSCODIUM_ARCH="armhf"
      ;;
    ppc64le)
      VSCODIUM_ARCH="ppc64le"
      ;;
    riscv64)
      VSCODIUM_ARCH="riscv64"
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

path = sys.argv[1]
arch = sys.argv[2]
asset_name_prefix = f"VSCodium-linux-{arch}-"

with open(path, "r", encoding="utf-8") as fh:
    release = json.load(fh)

if not isinstance(release, dict):
    print("Unexpected GitHub latest release response.", file=sys.stderr)
    sys.exit(1)

asset = None
sha_asset = None
for candidate in release.get("assets", []):
    name = candidate.get("name", "")
    if name.startswith(asset_name_prefix) and name.endswith(".tar.gz"):
        asset = candidate
        break

if asset is None:
    print(f"No VSCodium Linux tar.gz asset found for architecture {arch} in release {release.get('tag_name', '<unknown>')}.", file=sys.stderr)
    sys.exit(1)

sha_name = asset["name"] + ".sha256"
for candidate in release.get("assets", []):
    if candidate.get("name") == sha_name:
        sha_asset = candidate
        break

print(release["tag_name"])
print(asset["browser_download_url"])
print(asset["name"])
print(sha_asset["browser_download_url"] if sha_asset else "")
print(sha_name if sha_asset else "")
PY
}

verify_sha256() {
  local archive_dir="$1"
  local sha_file="$2"

  if [ ! -f "$sha_file" ]; then
    warn "No SHA256 file found; skipping checksum verification."
    return
  fi

  info "Verifying SHA256 checksum..."
  (cd "$archive_dir" && sha256sum -c "$(basename "$sha_file")")
}

write_desktop_file() {
  mkdir -p "$DESKTOP_DIR"

  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=VSCodium
GenericName=Text Editor
Comment=Code editing. Redefined.
Exec=$BIN_PATH --unity-launch %F
TryExec=$BIN_PATH
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Utility;TextEditor;Development;IDE;
MimeType=text/plain;inode/directory;application/x-codium-workspace;
StartupNotify=true
StartupWMClass=VSCodium
Keywords=vscodium;codium;code;editor;
Actions=new-empty-window;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=$BIN_PATH --new-window %F
EOF
}

refresh_desktop_caches() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

install_extensions() {
  local extension

  [ -f "$EXTENSIONS_FILE" ] || return

  while IFS= read -r extension || [ -n "$extension" ]; do
    [ -n "$extension" ] || continue
    "$BIN_PATH" --install-extension "$extension" ||
      warn "Could not install VSCodium extension: $extension"
  done < "$EXTENSIONS_FILE"
}

main() {
  local tmp_dir metadata_path tag archive_url archive_name sha_url sha_name current_version archive_path sha_path

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *) error "Unknown option: $1" ;;
  esac

  require_command python3
  require_command tar
  require_command sha256sum
  resolve_architecture

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  metadata_path="$tmp_dir/release.json"

  info "Resolving latest VSCodium release from ${RELEASE_API_URL} for linux-${VSCODIUM_ARCH}..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$VSCODIUM_ARCH")

  if [ "${#release_data[@]}" -lt 5 ]; then
    error "Could not resolve the latest VSCodium archive asset."
  fi

  tag="${release_data[0]}"
  archive_url="${release_data[1]}"
  archive_name="${release_data[2]}"
  sha_url="${release_data[3]}"
  sha_name="${release_data[4]}"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ -x "$BIN_PATH" ]; then
    info "VSCodium is already up to date (${tag}). Skipping installation."
    return 0
  fi

  info "Updating VSCodium from ${current_version:-not installed} to ${tag}."

  archive_path="$tmp_dir/$archive_name"
  sha_path="$tmp_dir/$sha_name"

  info "Downloading ${archive_name}..."
  download_file "$archive_url" "$archive_path" "progress"

  if [ -n "$sha_url" ]; then
    download_file "$sha_url" "$sha_path"
    verify_sha256 "$tmp_dir" "$sha_path"
  else
    warn "No SHA256 asset found for ${archive_name}."
  fi

  mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$ICON_DIR"
  rm -rf "$APP_DIR"
  mkdir -p "$APP_DIR"

  info "Extracting archive..."
  tar -xzf "$archive_path" -C "$APP_DIR"

  [ -x "$APP_DIR/codium" ] || error "Downloaded archive did not contain an executable codium binary."

  ln -sfn "$APP_DIR/codium" "$BIN_PATH"
  printf '%s\n' "$tag" > "$VERSION_PATH"

  if [ -f "$APP_DIR/resources/app/resources/linux/code.png" ]; then
    cp "$APP_DIR/resources/app/resources/linux/code.png" "$ICON_PATH"
  else
    warn "Could not find bundled VSCodium icon."
  fi

  write_desktop_file
  chmod +x "$DESKTOP_FILE"
  refresh_desktop_caches
  install_extensions

  info "Installed VSCodium ${tag}"
  info "Binary: $BIN_PATH"
}

main "$@"
