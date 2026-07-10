#!/usr/bin/env bash

set -euo pipefail

REPO="zed-industries/zed"
RELEASES_API_URL="https://api.github.com/repos/${REPO}/releases?per_page=100"
ASSET_NAME="zed-linux-x86_64.tar.gz"

INSTALL_DIR="$HOME/.local/share/zed-preview"
APP_DIR="$INSTALL_DIR/zed-preview.app"
VERSION_PATH="$INSTALL_DIR/version.txt"
CHANNEL_PATH="$INSTALL_DIR/channel.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/dev.zed.Zed-Preview.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/zed-preview"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_PATH="$ICON_DIR/zed-preview.png"

RUNTIME_PACKAGES=(
  alsa-lib
  curl
  fontconfig
  glib2
  libgit2
  libxcb
  libx11
  libxkbcommon
  libxkbcommon-x11
  openbsd-netcat
  nodejs
  npm
  sqlite
  vulkan-driver
  vulkan-icd-loader
  vulkan-tools
  wayland
  zlib
  zstd
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

usage() {
  cat <<'EOF'
Usage: ./install-zed-preview.sh

Installs the latest Zed Preview release side-by-side with stable Zed.

Installed paths:
  App:     ~/.local/share/zed-preview/zed-preview.app
  CLI:     ~/.local/bin/zed-preview
  Desktop: ~/.local/share/applications/dev.zed.Zed-Preview.desktop
  Icon:    ~/.local/share/icons/hicolor/512x512/apps/zed-preview.png

Configuration is shared with stable Zed by default:
  ~/.config/zed
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

require_python() {
  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse GitHub release metadata."
}

ensure_runtime_dependencies() {
  local missing_packages=()
  local pkg

  for pkg in "${RUNTIME_PACKAGES[@]}"; do
    if ! pacman -T "$pkg" >/dev/null 2>&1; then
      missing_packages+=("$pkg")
    fi
  done

  if [ "${#missing_packages[@]}" -eq 0 ]; then
    info "All required runtime packages are already installed."
    return
  fi

  info "Installing required runtime packages: ${missing_packages[*]}"

  if command -v yay >/dev/null 2>&1; then
    yay -S --noconfirm --needed "${missing_packages[@]}"
    return
  fi

  if command -v omarchy >/dev/null 2>&1; then
    omarchy pkg install "${missing_packages[@]}"
    return
  fi

  error "Missing runtime packages and neither yay nor omarchy is available to install them."
}

resolve_preview_release_metadata() {
  local metadata_path="$1"

  download_github_api_file "$RELEASES_API_URL" "$metadata_path"

  python3 - "$metadata_path" "$ASSET_NAME" <<'PY'
import json
import sys

path = sys.argv[1]
asset_name = sys.argv[2]

with open(path, "r", encoding="utf-8") as fh:
    releases = json.load(fh)

if not isinstance(releases, list):
    print("Unexpected GitHub releases response.", file=sys.stderr)
    sys.exit(1)

release = None
for candidate in releases:
    tag = candidate.get("tag_name", "")
    if candidate.get("prerelease", False) and tag.endswith("-pre"):
        release = candidate
        break

if release is None:
    for candidate in releases:
        if candidate.get("prerelease", False):
            release = candidate
            break

if release is None:
    print("Could not find a Zed Preview release in GitHub metadata.", file=sys.stderr)
    sys.exit(1)

asset = None
for candidate in release.get("assets", []):
    if candidate.get("name") == asset_name:
        asset = candidate
        break

if asset is None:
    print(f"Asset {asset_name} was not found for release {release.get('tag_name', '<unknown>')}.", file=sys.stderr)
    sys.exit(1)

print(release["tag_name"])
print(asset["browser_download_url"])
print(asset["name"])
PY
}

write_desktop_file() {
  mkdir -p "$DESKTOP_DIR"

  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Zed Preview
GenericName=Text Editor
Comment=A high-performance, multiplayer code editor.
TryExec=$BIN_PATH
StartupNotify=true
Exec=$BIN_PATH %U
Icon=zed-preview
Categories=Utility;TextEditor;Development;IDE;
Keywords=zed;preview;
MimeType=text/plain;application/x-zerosize;x-scheme-handler/zed;
Actions=NewWorkspace;

[Desktop Action NewWorkspace]
Exec=$BIN_PATH --new %U
Name=Open a new workspace
EOF
}

main() {
  local tmp_dir metadata_path tmp_archive tag archive_url archive_name current_version current_channel extracted_app_dir

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *) error "Unknown option: $1" ;;
  esac

  require_python
  ensure_runtime_dependencies

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  metadata_path="$tmp_dir/release.json"

  info "Resolving latest Zed Preview release from ${RELEASES_API_URL}..."
  mapfile -t release_data < <(resolve_preview_release_metadata "$metadata_path")

  if [ "${#release_data[@]}" -lt 3 ]; then
    error "Could not resolve the latest Zed Preview archive asset."
  fi

  tag="${release_data[0]}"
  archive_url="${release_data[1]}"
  archive_name="${release_data[2]}"

  mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" "$BIN_DIR" "$ICON_DIR"

  current_version=""
  current_channel=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi
  if [ -f "$CHANNEL_PATH" ]; then
    current_channel="$(cat "$CHANNEL_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ "$current_channel" = "preview" ]; then
    info "Installed version already matches selected release (${tag}, preview). Reinstalling to refresh local files."
  else
    info "Updating Zed Preview from ${current_version:-not installed}${current_channel:+ (${current_channel})} to ${tag}."
  fi

  tmp_archive="$tmp_dir/$archive_name"

  info "Downloading ${archive_name}..."
  download_file "$archive_url" "$tmp_archive" "progress"

  rm -rf "$APP_DIR"
  tar -xzf "$tmp_archive" -C "$INSTALL_DIR"

  extracted_app_dir="$APP_DIR"
  if [ ! -d "$extracted_app_dir" ] && [ -d "$INSTALL_DIR/zed.app" ]; then
    # Older/changed preview archives may unpack as zed.app. Keep our on-disk
    # layout side-by-side friendly regardless of the archive root name.
    mv "$INSTALL_DIR/zed.app" "$APP_DIR"
  fi

  [ -x "$APP_DIR/bin/zed" ] || error "Expected Zed Preview binary was not found at $APP_DIR/bin/zed after extraction."
  [ -f "$APP_DIR/share/icons/hicolor/512x512/apps/zed.png" ] || warn "Expected Zed Preview icon was not found in the extracted archive."

  printf '%s\n' "$tag" > "$VERSION_PATH"
  printf '%s\n' "preview" > "$CHANNEL_PATH"

  if [ -f "$APP_DIR/share/icons/hicolor/512x512/apps/zed.png" ]; then
    cp "$APP_DIR/share/icons/hicolor/512x512/apps/zed.png" "$ICON_PATH"
  fi

  chmod +x "$APP_DIR/bin/zed"
  ln -sf "$APP_DIR/bin/zed" "$BIN_PATH"
  write_desktop_file
  chmod +x "$DESKTOP_FILE"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi

  if pacman -Q zed-preview >/dev/null 2>&1; then
    warn "A pacman-managed zed-preview package is also installed. ~/.local/bin/zed-preview should take precedence, but consider removing the repo/AUR package to avoid confusion."
  fi

  info "Zed Preview installed successfully."
  info "Version: ${tag}"
  info "Source: ${archive_url}"
  info "Run 'zed-preview' or launch 'Zed Preview' from your application menu."
}

main "$@"
