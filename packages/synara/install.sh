#!/usr/bin/env bash

set -euo pipefail

REPO="Emanuele-web04/synara"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
ICON_URL="https://raw.githubusercontent.com/${REPO}/main/apps/desktop/resources/icon.png"

INSTALL_DIR="$HOME/.local/share/synara"
APP_DIR="$INSTALL_DIR/app"
APP_RUN_PATH="$APP_DIR/AppRun"
APPIMAGE_PATH="$INSTALL_DIR/Synara.AppImage"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/synara.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/synara"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_PATH="$ICON_DIR/synara.png"

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
Usage: ./install-synara.sh

Installs the latest Synara Linux x86_64 AppImage from GitHub Releases.
The AppImage is extracted once to avoid slower AppImage/FUSE startup.

Installed paths:
  App:      ~/.local/share/synara/app
  CLI:      ~/.local/bin/synara
  Desktop:  ~/.local/share/applications/synara.desktop
  Icon:     ~/.local/share/icons/hicolor/512x512/apps/synara.png

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

require_python() {
  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse GitHub release metadata."
}

resolve_release_metadata() {
  local metadata_path="$1"

  download_github_api_file "$RELEASE_API_URL" "$metadata_path"

  python3 - "$metadata_path" <<'PY'
import json
import sys

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as fh:
    release = json.load(fh)

assets = release.get("assets", [])
appimages = [asset for asset in assets if asset.get("name", "").endswith(".AppImage")]

if not appimages:
    print("No AppImage asset found in the latest Synara release.", file=sys.stderr)
    sys.exit(1)

preferred = None
for asset in appimages:
    name = asset.get("name", "").lower()
    if "x86_64" in name or "amd64" in name:
        preferred = asset
        break

if preferred is None:
    preferred = appimages[0]

print(release["tag_name"])
print(preferred["browser_download_url"])
print(preferred["name"])
PY
}

write_desktop_file() {
  mkdir -p "$DESKTOP_DIR"

  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=Synara
Comment=AI coding agent desktop app
Exec=$APP_RUN_PATH %U
TryExec=$APP_RUN_PATH
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;IDE;
StartupNotify=true
StartupWMClass=Synara
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

main() {
  local tmp_dir metadata_path tmp_appimage tag appimage_url asset_name current_version

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *) error "Unknown option: $1" ;;
  esac

  require_python

  if [ "$(uname -m)" != "x86_64" ]; then
    error "Synara GitHub Releases currently provide a Linux x86_64 AppImage only. Current architecture: $(uname -m)"
  fi

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  metadata_path="$tmp_dir/release.json"

  info "Resolving latest Synara release from ${RELEASE_API_URL}..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path")

  if [ "${#release_data[@]}" -lt 3 ]; then
    error "Could not resolve the latest Synara AppImage asset."
  fi

  tag="${release_data[0]}"
  appimage_url="${release_data[1]}"
  asset_name="${release_data[2]}"

  mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" "$BIN_DIR" "$ICON_DIR"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ]; then
    info "Installed version already matches latest release (${tag}). Reinstalling to refresh local files."
  else
    info "Updating Synara from ${current_version:-not installed} to ${tag}."
  fi

  tmp_appimage="$tmp_dir/$asset_name"

  info "Downloading ${asset_name}..."
  download_file "$appimage_url" "$tmp_appimage" "progress"

  chmod +x "$tmp_appimage"

  info "Extracting AppImage for faster startup..."
  (
    cd "$tmp_dir"
    "$tmp_appimage" --appimage-extract >/dev/null
  )

  [ -x "$tmp_dir/squashfs-root/AppRun" ] || error "Expected AppRun was not found after AppImage extraction."

  rm -rf "$APP_DIR" "$APPIMAGE_PATH"
  mv "$tmp_dir/squashfs-root" "$APP_DIR"
  chmod +x "$APP_RUN_PATH" "$APP_DIR/synara" 2>/dev/null || true
  printf '%s\n' "$tag" > "$VERSION_PATH"

  if [ -f "$APP_DIR/usr/share/icons/hicolor/512x512/apps/synara.png" ]; then
    cp "$APP_DIR/usr/share/icons/hicolor/512x512/apps/synara.png" "$ICON_PATH"
  elif [ -f "$APP_DIR/synara.png" ]; then
    cp "$APP_DIR/synara.png" "$ICON_PATH"
  elif [ -f "$APP_DIR/.DirIcon" ]; then
    cp "$APP_DIR/.DirIcon" "$ICON_PATH"
  elif ! download_file "$ICON_URL" "$ICON_PATH"; then
    warn "Could not install icon from extracted app or ${ICON_URL}."
  fi

  write_desktop_file
  chmod +x "$DESKTOP_FILE"
  ln -sf "$APP_RUN_PATH" "$BIN_PATH"

  refresh_desktop_caches

  info "Synara installed successfully."
  info "Version: ${tag}"
  info "Source: ${appimage_url}"
  info "Run 'synara' or launch it from your application menu."
}

main "$@"
