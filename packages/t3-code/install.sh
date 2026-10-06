#!/usr/bin/env bash

set -euo pipefail

REPO="pingdotgg/t3code"
LATEST_STABLE_RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
RELEASES_API_URL="https://api.github.com/repos/${REPO}/releases?per_page=100"

# Stable and nightly share one install slot: upstream gives both channels the
# same Electron profile (~/.config/t3code-v2) and state dir (~/.t3), so running
# them side by side is unsafe. Installing one channel replaces the other.
INSTALL_DIR="$HOME/.local/share/t3-code"
APP_DIR="$INSTALL_DIR/app"
APP_RUN_PATH="$APP_DIR/AppRun"
LAUNCHER_PATH="$INSTALL_DIR/t3-code"
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
Usage: ./install.sh [--nightly]

Installs the latest T3 Code AppImage from GitHub Releases.

Options:
  --nightly   Install the latest nightly build instead of the latest stable release.
              Replaces any installed stable build (and vice versa).
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

# Prints the release tag, AppImage URL, and AppImage name on separate lines.
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

  python3 -I - "$metadata_path" "$release_channel" <<'PY'
import json
import sys

path, channel = sys.argv[1], sys.argv[2]

with open(path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)

if channel == "stable":
    release = payload
else:
    # Nightly tags look like v0.0.46-nightly.20261006.2735; the API lists newest first.
    release = next(
        (r for r in payload if "-nightly." in r.get("tag_name", "") and not r.get("draft", False)),
        None,
    )

if release is None:
    print(f"Could not find a {channel} release in GitHub metadata.", file=sys.stderr)
    sys.exit(1)

asset = next(
    (
        a for a in release.get("assets", [])
        if a.get("name", "").endswith("-x86_64.AppImage")
    ),
    None,
)
if asset is None:
    print(f"No x86_64 AppImage found for release {release.get('tag_name', '<unknown>')}.", file=sys.stderr)
    sys.exit(1)

print(release["tag_name"])
print(asset["browser_download_url"])
print(asset["name"])
PY
}

write_launcher() {
  # T3 Code registers its t3code:// URL handler against $APPIMAGE, so point it
  # at the extracted AppRun instead of a FUSE-mounted AppImage path.
  cat > "$LAUNCHER_PATH" <<EOF
#!/bin/sh
export APPDIR="$APP_DIR"
export APPIMAGE="$APP_RUN_PATH"
exec "$APP_RUN_PATH" "\$@"
EOF

  chmod +x "$LAUNCHER_PATH"
}

write_desktop_file() {
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
StartupWMClass=com.t3tools.T3Code
EOF

  chmod +x "$DESKTOP_FILE"
}

# The AppImage ships the channel-specific icon (nightly has its own artwork).
install_icon() {
  local icon_source="$APP_DIR/.DirIcon"

  if [ -e "$icon_source" ]; then
    cp -L "$icon_source" "$ICON_PATH"
  else
    warn "AppImage has no .DirIcon; skipping icon install."
  fi
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
  local release_channel tmp_dir metadata_path tmp_appimage tag appimage_url asset_name current_version
  local -a release_data

  release_channel="stable"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --nightly)
        release_channel="nightly"
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
  # Expand now: tmp_dir is local and gone by the time the EXIT trap runs.
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" EXIT

  metadata_path="$tmp_dir/release.json"

  info "Resolving latest T3 Code ${release_channel} release..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$release_channel")

  if [ "${#release_data[@]}" -lt 3 ]; then
    error "Could not resolve the latest ${release_channel} T3 Code AppImage asset."
  fi

  tag="${release_data[0]}"
  appimage_url="${release_data[1]}"
  asset_name="${release_data[2]}"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ -x "$BIN_PATH" ]; then
    info "T3 Code is already up to date (${tag})."
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

  mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" "$BIN_DIR" "$ICON_DIR"

  rm -rf "$APP_DIR"
  mv "$tmp_dir/squashfs-root" "$APP_DIR"
  write_launcher
  printf '%s\n' "$tag" > "$VERSION_PATH"

  install_icon
  write_desktop_file
  ln -sf "$LAUNCHER_PATH" "$BIN_PATH"
  refresh_desktop_caches

  info "T3 Code ${tag} (${release_channel}) installed."
  info "Run 't3-code' or launch it from your application menu."
}

main "$@"
