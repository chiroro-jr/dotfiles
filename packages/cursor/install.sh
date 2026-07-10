#!/usr/bin/env bash

set -euo pipefail

DOWNLOAD_PAGE_URL="https://cursor.com/download"
ICON_URL="https://cursor.com/marketing-static/icon-512x512.png"

INSTALL_DIR="$HOME/.local/share/cursor"
APPIMAGE_PATH="$INSTALL_DIR/Cursor.AppImage"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/cursor.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/cursor"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_PATH="$ICON_DIR/cursor.png"

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
Usage: ./install-cursor.sh [--print-url]

Downloads the latest Cursor AppImage directly from cursor.com and installs it locally.

Options:
  --print-url  Print the resolved latest AppImage URL for this architecture and exit.
  -h, --help   Show this help message.
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

require_python() {
  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse Cursor download metadata."
}

resolve_architecture() {
  case "$(uname -m)" in
    x86_64|amd64)
      CURSOR_ARCH_LABEL="Linux AppImage (x64)"
      CURSOR_ARCH_SLUG="linux-x64"
      ;;
    aarch64|arm64)
      CURSOR_ARCH_LABEL="Linux AppImage (ARM64)"
      CURSOR_ARCH_SLUG="linux-arm64"
      ;;
    *)
      error "Unsupported architecture: $(uname -m)."
      ;;
  esac
}

resolve_release_metadata() {
  local html_path="$1"
  local arch_label="$2"

  download_file "$DOWNLOAD_PAGE_URL" "$html_path"

  python3 - "$html_path" "$arch_label" <<'PY'
import re
import sys

path = sys.argv[1]
arch_label = sys.argv[2]

with open(path, "r", encoding="utf-8") as fh:
    html = fh.read()

normalized = html.replace('\\"', '"')

version_match = re.search(r'"latestVersion":\{"versionNumber":"([^"]+)"', normalized)
if not version_match:
    print("Could not find Cursor version metadata on the download page.", file=sys.stderr)
    sys.exit(1)

label_pattern = re.escape(arch_label)
url_match = re.search(r'"label":"' + label_pattern + r'","downloadUrl":"([^"]+)"', normalized)
if not url_match:
    print(f"Could not find a download URL for {arch_label} on the Cursor download page.", file=sys.stderr)
    sys.exit(1)

print(version_match.group(1))
print(url_match.group(1))
PY
}

resolve_final_download_url() {
  local url="$1"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSIL -o /dev/null -w '%{url_effective}' "$url"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget --max-redirect=20 --server-response --spider "$url" 2>&1 \
      | awk '/^  Location: / {print $2}' \
      | tr -d '\r' \
      | tail -n 1
    return
  fi

  error "curl or wget is required to resolve Cursor download redirects."
}

extract_version_from_asset_name() {
  local asset_name="$1"
  local fallback_version="$2"

  if [[ "$asset_name" =~ ^Cursor-([0-9][A-Za-z0-9._-]*)-.*\.AppImage$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return
  fi

  printf '%s\n' "$fallback_version"
}

write_desktop_file() {
  mkdir -p "$DESKTOP_DIR"

  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=Cursor
Comment=The AI-first code editor
Exec=$APPIMAGE_PATH %U
TryExec=$APPIMAGE_PATH
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;IDE;TextEditor;
StartupNotify=true
StartupWMClass=cursor
EOF
}

main() {
  local print_url_only tmp_dir html_path page_version download_endpoint final_download_url asset_name resolved_version current_version tmp_appimage

  print_url_only="false"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --print-url)
        print_url_only="true"
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
  resolve_architecture

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  html_path="$tmp_dir/cursor-download.html"

  info "Resolving latest Cursor release from ${DOWNLOAD_PAGE_URL} for ${CURSOR_ARCH_LABEL}..."
  mapfile -t release_data < <(resolve_release_metadata "$html_path" "$CURSOR_ARCH_LABEL")

  if [ "${#release_data[@]}" -lt 2 ]; then
    error "Could not resolve the latest Cursor download URL."
  fi

  page_version="${release_data[0]}"
  download_endpoint="${release_data[1]}"
  final_download_url="$(resolve_final_download_url "$download_endpoint")"

  [ -n "$final_download_url" ] || error "Could not resolve the final Cursor AppImage URL."

  if [ "$print_url_only" = "true" ]; then
    printf '%s\n' "$final_download_url"
    exit 0
  fi

  asset_name="${final_download_url##*/}"
  resolved_version="$(extract_version_from_asset_name "$asset_name" "$page_version")"

  mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" "$BIN_DIR" "$ICON_DIR"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$resolved_version" ]; then
    info "Installed version already matches latest release (${resolved_version}). Reinstalling to refresh local files."
  else
    info "Updating Cursor from ${current_version:-not installed} to ${resolved_version}."
  fi

  tmp_appimage="$tmp_dir/$asset_name"

  info "Downloading ${asset_name}..."
  download_file "$final_download_url" "$tmp_appimage" "progress"

  mv "$tmp_appimage" "$APPIMAGE_PATH"
  chmod +x "$APPIMAGE_PATH"
  printf '%s\n' "$resolved_version" > "$VERSION_PATH"

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

  for package_name in cursor cursor-bin; do
    if pacman -Q "$package_name" >/dev/null 2>&1; then
      warn "A pacman-managed ${package_name} package is also installed. ~/.local/bin/cursor should take precedence, but consider removing the package to avoid confusion."
    fi
  done

  info "Cursor installed successfully."
  info "Architecture: ${CURSOR_ARCH_SLUG}"
  info "Version: ${resolved_version}"
  info "Source page version: ${page_version}"
  info "Source: ${final_download_url}"
  info "Run 'cursor' or launch it from your application menu."
}

main "$@"
