#!/usr/bin/env bash

set -euo pipefail

RELEASE_API_URL="https://codeberg.org/api/v1/repos/GramEditor/gram/releases/latest"

INSTALL_DIR="$HOME/.local/share/gram"
APP_DIR="$INSTALL_DIR/gram.app"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/gram.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/gram"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
ICON_PATH="$ICON_DIR/app.liten.Gram.svg"
SYMBOLIC_ICON_DIR="$HOME/.local/share/icons/hicolor/symbolic/apps"
SYMBOLIC_ICON_PATH="$SYMBOLIC_ICON_DIR/app.liten.Gram-symbolic.svg"

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
Usage: ./install-gram.sh

Installs the latest Gram Linux tarball from Codeberg Releases.

Installed paths:
  App:      ~/.local/share/gram/gram.app
  CLI:      ~/.local/bin/gram
  Desktop:  ~/.local/share/applications/gram.desktop
  Icon:     ~/.local/share/icons/hicolor/scalable/apps/app.liten.Gram.svg

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

require_python() {
  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse Codeberg release metadata."
}

linux_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *) error "Unsupported architecture: $(uname -m). Gram releases provide x86_64 and aarch64 Linux tarballs." ;;
  esac
}

resolve_release_metadata() {
  local metadata_path="$1"
  local arch="$2"

  download_file "$RELEASE_API_URL" "$metadata_path"

  python3 - "$metadata_path" "$arch" <<'PY'
import json
import sys

path = sys.argv[1]
arch = sys.argv[2]

with open(path, "r", encoding="utf-8") as fh:
    release = json.load(fh)

assets = release.get("assets", [])
needle = f"gram-linux-{arch}-"
candidates = [
    asset for asset in assets
    if asset.get("name", "").startswith(needle) and asset.get("name", "").endswith(".tar.gz")
]

if not candidates:
    print(f"No Gram Linux {arch} tarball found in latest Codeberg release.", file=sys.stderr)
    sys.exit(1)

asset = candidates[0]
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
Name=Gram
GenericName=Text Editor
Comment=A code editor for humanoid apes and grumpy toads
TryExec=$BIN_PATH
StartupNotify=true
Exec=$BIN_PATH %U
Icon=app.liten.Gram
Categories=Utility;TextEditor;Development;IDE;
Keywords=gram;
MimeType=text/plain;application/x-zerosize;x-scheme-handler/gram;
Actions=NewWorkspace;
StartupWMClass=app.liten.Gram

[Desktop Action NewWorkspace]
Exec=$BIN_PATH --new %U
Name=Open a new workspace
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
  local tmp_dir metadata_path arch tag tarball_url asset_name current_version tmp_tarball

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    *) error "Unknown option: $1" ;;
  esac

  require_python
  arch="$(linux_arch)"

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  metadata_path="$tmp_dir/release.json"

  info "Resolving latest Gram release from ${RELEASE_API_URL}..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$arch")

  if [ "${#release_data[@]}" -lt 3 ]; then
    error "Could not resolve the latest Gram tarball asset."
  fi

  tag="${release_data[0]}"
  tarball_url="${release_data[1]}"
  asset_name="${release_data[2]}"

  mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" "$BIN_DIR" "$ICON_DIR" "$SYMBOLIC_ICON_DIR"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ]; then
    info "Installed version already matches latest release (${tag}). Reinstalling to refresh local files."
  else
    info "Updating Gram from ${current_version:-not installed} to ${tag}."
  fi

  tmp_tarball="$tmp_dir/$asset_name"

  info "Downloading ${asset_name}..."
  download_file "$tarball_url" "$tmp_tarball" "progress"

  info "Extracting..."
  tar -xzf "$tmp_tarball" -C "$tmp_dir"

  [ -x "$tmp_dir/gram.app/bin/gram" ] || error "Expected gram.app/bin/gram was not found after extraction."

  rm -rf "$APP_DIR"
  mv "$tmp_dir/gram.app" "$APP_DIR"
  chmod +x "$APP_DIR/bin/gram" "$APP_DIR/libexec/gram-editor" 2>/dev/null || true
  printf '%s\n' "$tag" > "$VERSION_PATH"

  if [ -f "$APP_DIR/share/icons/hicolor/scalable/apps/app.liten.Gram.svg" ]; then
    cp "$APP_DIR/share/icons/hicolor/scalable/apps/app.liten.Gram.svg" "$ICON_PATH"
  else
    warn "Could not find Gram scalable icon in extracted app."
  fi

  if [ -f "$APP_DIR/share/icons/hicolor/symbolic/apps/app.liten.Gram-symbolic.svg" ]; then
    cp "$APP_DIR/share/icons/hicolor/symbolic/apps/app.liten.Gram-symbolic.svg" "$SYMBOLIC_ICON_PATH"
  fi

  write_desktop_file
  chmod +x "$DESKTOP_FILE"
  ln -sf "$APP_DIR/bin/gram" "$BIN_PATH"

  refresh_desktop_caches

  info "Gram installed successfully."
  info "Version: ${tag}"
  info "Source: ${tarball_url}"
  info "Run 'gram' or launch it from your application menu."
}

main "$@"
