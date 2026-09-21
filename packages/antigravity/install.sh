#!/usr/bin/env bash

set -euo pipefail

RELEASES_API_URL="https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases"
DOWNLOAD_BASE_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub"
DOWNLOAD_URL="${DOWNLOAD_URL:-}"
ICON_URL="https://antigravity.google/assets/image/antigravity-logo.png"
INSTALL_DIR="$HOME/.local/share/antigravity"
APP_DIR="$INSTALL_DIR/Antigravity-x64"
APP_BIN_PATH="$APP_DIR/antigravity"
VERSION_PATH="$INSTALL_DIR/version.txt"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/antigravity"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/antigravity.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_PATH="$ICON_DIR/antigravity.png"
PLATFORM="linux-x64"

info() {
  echo "[INFO] $*" >&2
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || error "$1 is required."
}

download_file() {
  local url="$1"
  local out="$2"

  curl -fL --compressed --progress-bar --retry 3 --retry-delay 2 "$url" -o "$out"
}

latest_release_id() {
  python3 - "$RELEASES_API_URL" <<'PY'
import json
import sys
import urllib.request

api_url = sys.argv[1]
with urllib.request.urlopen(api_url, timeout=30) as response:
    releases = json.load(response)

if not isinstance(releases, list) or not releases:
    print("No Antigravity releases returned by the updater API.", file=sys.stderr)
    sys.exit(1)

release = releases[0]
version = str(release.get("version", "")).strip()
execution_id = str(release.get("execution_id", "")).strip().rstrip("/")
if not version or not execution_id:
    print("Updater API release is missing version or execution_id.", file=sys.stderr)
    sys.exit(1)

print(f"{version}-{execution_id}")
PY
}

latest_download_url() {
  local release_id

  release_id="$(latest_release_id)" || return 1
  printf '%s/%s/%s/Antigravity.tar.gz\n' "$DOWNLOAD_BASE_URL" "$release_id" "$PLATFORM"
}

resolve_download_url() {
  if [ -n "$DOWNLOAD_URL" ]; then
    printf '%s\n' "$DOWNLOAD_URL"
    return 0
  fi

  latest_download_url || error "Could not resolve latest Antigravity download URL from: $RELEASES_API_URL"
}

version_from_url() {
  printf '%s' "$1" | sed -n 's#.*/antigravity-hub/\([^/]*\)/linux-[^/]*/.*#\1#p'
}

running_antigravity_pids() {
  {
    pgrep -u "$(id -u)" -f "$APP_DIR/antigravity" 2>/dev/null || true
    pgrep -u "$(id -u)" -f "$BIN_PATH" 2>/dev/null || true
  } | sort -u | grep -v "^$$$" || true
}

stop_running_antigravity() {
  local pids

  pids="$(running_antigravity_pids)"
  [ -n "$pids" ] || return 0

  info "Stopping running Antigravity before replacing files..."
  kill $pids 2>/dev/null || true
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "$APP_BIN_PATH" >/dev/null 2>&1 || true
  fi

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pids="$(running_antigravity_pids)"
    [ -z "$pids" ] && return 0
    sleep 0.2
  done

  pids="$(running_antigravity_pids)"
  [ -z "$pids" ] || kill -9 $pids 2>/dev/null || true
}

write_bin_wrapper() {
  mkdir -p "$BIN_DIR"
  rm -f "$BIN_PATH"

  cat >"$BIN_PATH" <<EOF
#!/usr/bin/env bash
export ELECTRON_ENABLE_LOGGING="\${ELECTRON_ENABLE_LOGGING:-1}"
exec "$APP_BIN_PATH" "\$@"
EOF

  chmod +x "$BIN_PATH"
}

write_desktop_file() {
  mkdir -p "$DESKTOP_DIR"

  cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Antigravity
Comment=Google Antigravity
GenericName=Text Editor
Exec=$BIN_PATH %F
Icon=$ICON_PATH
Type=Application
StartupNotify=true
StartupWMClass=Antigravity
Categories=Development;IDE;TextEditor;
MimeType=text/plain;inode/directory;
Actions=new-empty-window;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=$BIN_PATH --new-window %F
EOF

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
}

refresh_icon_cache() {
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

usage() {
  cat <<EOF
Usage: ./install-antigravity.sh

Installs latest Google Antigravity from:
  $RELEASES_API_URL

Set DOWNLOAD_URL to install a specific tarball.
EOF
}

install_antigravity() {
  local version current_version tmp archive extracted_dir

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *) error "Unknown option: $1" ;;
  esac

  require_command curl
  require_command python3
  require_command sed
  require_command tar

  if [ "$(uname -m)" != "x86_64" ]; then
    error "This installer currently supports linux-x64 only. Current architecture: $(uname -m)"
  fi

  DOWNLOAD_URL="$(resolve_download_url)"
  version="$(version_from_url "$DOWNLOAD_URL")"
  [ -n "$version" ] || error "Could not parse Antigravity version from: $DOWNLOAD_URL"

  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
    if [ "$current_version" = "$version" ] && [ -x "$BIN_PATH" ]; then
      stop_running_antigravity
      mkdir -p "$ICON_DIR"
      write_bin_wrapper
      download_file "$ICON_URL" "$ICON_PATH"
      write_desktop_file
      refresh_icon_cache
      info "Antigravity $version is already installed. Refreshed desktop launcher."
      exit 0
    fi
  fi

  info "Installing Antigravity $version..."
  tmp="$(mktemp -d)"
  trap "rm -rf '$tmp'" EXIT

  archive="$tmp/antigravity.tar.gz"
  download_file "$DOWNLOAD_URL" "$archive"

  tar -xzf "$archive" -C "$tmp"
  extracted_dir="$tmp/Antigravity-x64"
  [ -d "$extracted_dir" ] || error "Downloaded archive did not contain the expected Antigravity-x64 directory."

  mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$ICON_DIR"
  stop_running_antigravity
  rm -rf "$APP_DIR"
  mv "$extracted_dir" "$APP_DIR"

  write_bin_wrapper
  printf '%s\n' "$version" >"$VERSION_PATH"

  download_file "$ICON_URL" "$ICON_PATH"
  write_desktop_file
  refresh_icon_cache

  info "Installed Antigravity $version"
  info "Binary: $BIN_PATH"
}

install_antigravity "$@"
