#!/usr/bin/env bash

set -euo pipefail

REPO="pingdotgg/t3code"
LATEST_STABLE_RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
RELEASES_API_URL="https://api.github.com/repos/${REPO}/releases?per_page=100"
ICON_URL="https://raw.githubusercontent.com/pingdotgg/t3code/main/apps/desktop/resources/icon.png"

INSTALL_DIR="$HOME/.local/share/t3-code"
APP_DIR="$INSTALL_DIR/app"
APP_RUN_PATH="$APP_DIR/AppRun"
LAUNCHER_PATH="$INSTALL_DIR/t3-code"
APPIMAGE_PATH="$INSTALL_DIR/T3-Code.AppImage"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/t3-code.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/t3-code"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_PATH="$ICON_DIR/t3-code.png"

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
Usage: ./install-t3-code.sh [--channel stable|nightly] [--nightly|--stable]

Options:
  --channel   Select release channel explicitly (stable or nightly).
  --nightly   Shortcut for --channel nightly.
  --stable    Shortcut for --channel stable (default if omitted).
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
  local release_channel="$2"
  local api_url

  if [ "$release_channel" = "nightly" ]; then
    api_url="$RELEASES_API_URL"
  else
    api_url="$LATEST_STABLE_RELEASE_API_URL"
  fi

  download_github_api_file "$api_url" "$metadata_path"

  python3 - "$metadata_path" "$release_channel" <<'PY'
import json
import sys

path = sys.argv[1]
release_channel = sys.argv[2]

with open(path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)


def pick_appimage_asset(release):
    assets = release.get("assets", [])
    appimages = [
        asset for asset in assets
        if asset.get("name", "").endswith(".AppImage")
    ]

    preferred = None
    for asset in appimages:
        name = asset.get("name", "").lower()
        if "x86_64" in name or "amd64" in name:
            preferred = asset
            break

    if preferred is None and appimages:
        preferred = appimages[0]

    return preferred


def resolve_release_for_channel(channel, data):
    if channel == "stable":
        if isinstance(data, dict):
            return data

        if isinstance(data, list):
            for release in data:
                if not release.get("prerelease", False):
                    return release

        return None

    if not isinstance(data, list):
        return None

    nightly_releases = [
        release for release in data
        if release.get("tag_name", "").startswith("nightly-")
    ]

    if nightly_releases:
        return nightly_releases[0]

    fallback_nightly_releases = [
        release for release in data
        if release.get("prerelease", False)
        and "nightly" in release.get("tag_name", "").lower()
    ]

    if fallback_nightly_releases:
        return fallback_nightly_releases[0]

    return None


release = resolve_release_for_channel(release_channel, payload)
if release is None:
    print(f"Could not find a {release_channel} release in GitHub metadata.", file=sys.stderr)
    sys.exit(1)

asset = pick_appimage_asset(release)
if asset is None:
    print(f"No AppImage asset found for release {release.get('tag_name', '<unknown>')}.", file=sys.stderr)
    sys.exit(1)

print(release["tag_name"])
print(asset["browser_download_url"])
print(asset["name"])
PY
}

write_launcher() {
  cat > "$LAUNCHER_PATH" <<EOF
#!/bin/sh
export APPDIR="$APP_DIR"
export APPIMAGE="$APP_RUN_PATH"
exec "$APP_RUN_PATH" "\$@"
EOF

  chmod +x "$LAUNCHER_PATH"
}

write_desktop_file() {
  mkdir -p "$DESKTOP_DIR"

  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=T3 Code
Comment=T3 Code desktop app
Exec=$LAUNCHER_PATH %U
TryExec=$LAUNCHER_PATH
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;IDE;
StartupNotify=true
EOF
}

main() {
  local release_channel tmp_dir metadata_path tmp_appimage tag appimage_url asset_name current_version

  release_channel="stable"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --channel)
        if [ "$#" -lt 2 ]; then
          error "--channel requires a value: stable or nightly"
        fi

        case "$2" in
          stable|nightly)
            release_channel="$2"
            ;;
          *)
            error "Invalid --channel value: $2 (expected: stable or nightly)"
            ;;
        esac
        shift
        ;;
      --nightly)
        release_channel="nightly"
        ;;
      --stable)
        release_channel="stable"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        ;;
    esac
    shift
  done

  require_python

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  metadata_path="$tmp_dir/release.json"

  if [ "$release_channel" = "nightly" ]; then
    info "Resolving latest T3 Code nightly release from ${RELEASES_API_URL}..."
  else
    info "Resolving latest T3 Code stable release from ${LATEST_STABLE_RELEASE_API_URL}..."
  fi

  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$release_channel")

  if [ "${#release_data[@]}" -lt 3 ]; then
    error "Could not resolve the latest ${release_channel} T3 Code AppImage asset."
  fi

  tag="${release_data[0]}"
  appimage_url="${release_data[1]}"
  asset_name="${release_data[2]}"

  mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" "$BIN_DIR" "$ICON_DIR"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ -x "$BIN_PATH" ]; then
    info "T3 Code is already up to date (${tag}). Skipping installation."
    return 0
  fi

  info "Updating T3 Code from ${current_version:-not installed} to ${tag}."

  tmp_appimage="$tmp_dir/$asset_name"

  info "Downloading ${asset_name}..."
  download_file "$appimage_url" "$tmp_appimage" "progress"

  chmod +x "$tmp_appimage"

  info "Extracting AppImage for FUSE-free execution..."
  (
    cd "$tmp_dir"
    "$tmp_appimage" --appimage-extract >/dev/null
  )

  [ -x "$tmp_dir/squashfs-root/AppRun" ] || error "AppImage extraction did not produce an executable AppRun."

  rm -rf "$APP_DIR" "$APPIMAGE_PATH"
  mv "$tmp_dir/squashfs-root" "$APP_DIR"
  chmod +x "$APP_RUN_PATH"
  write_launcher
  printf '%s\n' "$tag" > "$VERSION_PATH"

  if download_file "$ICON_URL" "$ICON_PATH"; then
    :
  else
    warn "Could not download icon from ${ICON_URL}."
  fi

  write_desktop_file
  chmod +x "$DESKTOP_FILE"
  ln -sf "$LAUNCHER_PATH" "$BIN_PATH"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi

  info "T3 Code installed successfully."
  info "Channel: ${release_channel}"
  info "Version: ${tag}"
  info "Source: ${appimage_url}"
  info "Run 't3-code' or launch it from your application menu."
}

main "$@"
