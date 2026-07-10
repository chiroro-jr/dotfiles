#!/usr/bin/env bash

set -euo pipefail

REPO="anomalyco/opencode"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
ICON_URL="https://raw.githubusercontent.com/anomalyco/opencode/dev/packages/desktop-electron/icons/prod/icon.png"

INSTALL_DIR="$HOME/.local/share/opencode-desktop"
APPIMAGE_PATH="$INSTALL_DIR/OpenCode-Desktop.AppImage"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/opencode-desktop.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/opencode-desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_PATH="$ICON_DIR/opencode-desktop.png"

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
    print("No AppImage asset found in the latest release.", file=sys.stderr)
    sys.exit(1)

preferred = None

# Prefer desktop AppImage naming if present.
for asset in appimages:
    name = asset.get("name", "").lower()
    if ("opencode-electron" in name or "desktop" in name) and ("x86_64" in name or "amd64" in name):
        preferred = asset
        break

if preferred is None:
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
Name=OpenCode Desktop
Comment=OpenCode desktop app
Exec=$APPIMAGE_PATH %U
TryExec=$APPIMAGE_PATH
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;IDE;
StartupNotify=true
EOF
}

main() {
  local tmp_dir metadata_path tmp_appimage tag appimage_url asset_name current_version

  require_python

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  metadata_path="$tmp_dir/release.json"

  info "Resolving latest OpenCode release from ${RELEASE_API_URL}..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path")

  if [ "${#release_data[@]}" -lt 3 ]; then
    error "Could not resolve the latest OpenCode AppImage asset."
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
    info "Updating OpenCode Desktop from ${current_version:-not installed} to ${tag}."
  fi

  tmp_appimage="$tmp_dir/$asset_name"

  info "Downloading ${asset_name}..."
  download_file "$appimage_url" "$tmp_appimage" "progress"

  mv "$tmp_appimage" "$APPIMAGE_PATH"
  chmod +x "$APPIMAGE_PATH"
  printf '%s\n' "$tag" > "$VERSION_PATH"

  if download_file "$ICON_URL" "$ICON_PATH"; then
    :
  else
    warn "Could not download icon from ${ICON_URL}."
  fi

  write_desktop_file
  chmod +x "$DESKTOP_FILE"
  ln -sf "$APPIMAGE_PATH" "$BIN_PATH"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi

  info "OpenCode Desktop installed successfully."
  info "Version: ${tag}"
  info "Source: ${appimage_url}"
  info "Run 'opencode-desktop' or launch it from your application menu."
}

main "$@"
