#!/usr/bin/env bash

set -euo pipefail

# Fountible only ships a macOS build. Its app code is plain Electron with no
# native Node modules, so this runs the macOS build's resources on the official
# Linux Electron runtime.
RELEASES_URL="https://github.com/mofactor/fountible-releases/releases/latest/download"

INSTALL_DIR="$HOME/.local/share/fountible"
APP_DIR="$INSTALL_DIR/app"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/fountible.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/fountible"

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

require_commands() {
  local command

  [ "$(uname -m)" = "x86_64" ] || error "This installer only supports x86_64."

  for command in base64 curl python3 sha512sum unzip; do
    command -v "$command" >/dev/null 2>&1 || error "Required command is not installed: $command"
  done
}

download_file() {
  curl -fL --progress-bar --retry 3 --retry-delay 2 "$1" -o "$2"
}

# Prints the version, zip asset name and base64 sha512 from electron-builder's
# macOS update manifest.
resolve_release() {
  curl -fsSL --retry 3 "$RELEASES_URL/latest-mac.yml" | python3 -I -c '
import re
import sys

manifest = sys.stdin.read()
version = re.search(r"^version: (\S+)$", manifest, re.M)
asset = re.search(r"^  - url: (\S+-mac\.zip)\n    sha512: (\S+)$", manifest, re.M)
if not version or not asset:
    sys.exit("Could not parse latest-mac.yml.")
print(version[1], asset[1], asset[2], sep="\n")
'
}

# CFBundleVersion of the bundled Electron Framework is the Electron release.
electron_version() {
  python3 -I -c '
import plistlib
import sys

with open(sys.argv[1], "rb") as fh:
    print(plistlib.load(fh)["CFBundleVersion"])
' "$1"
}

# The bundled ghostscript and poppler are macOS binaries. Fountible's EPS import
# needs gs and pdftocairo at fixed paths, and sets GS_LIB to
# share/ghostscript/Resource/Init beside them, so point all of that at the
# system ghostscript and poppler.
link_eps_tools() {
  local eps_dir="$1/app.asar.unpacked/dist-native/eps" tool

  rm -rf "$eps_dir"
  mkdir -p "$eps_dir/bin" "$eps_dir/share"
  ln -s /usr/share/ghostscript "$eps_dir/share/ghostscript"

  for tool in gs pdftocairo; do
    if command -v "$tool" >/dev/null 2>&1; then
      ln -s "$(command -v "$tool")" "$eps_dir/bin/$tool"
    else
      warn "$tool is not installed; EPS and Illustrator import will not work (install ghostscript and poppler)."
    fi
  done
}

build_app() {
  local work_dir="$1" zip_path="$2" stage_dir="$3"
  local contents="$work_dir/mac/Fountible.app/Contents" res_dir="$stage_dir/resources" version

  info "Extracting macOS app resources..."
  unzip -q "$zip_path" \
    'Fountible.app/Contents/Resources/*' \
    'Fountible.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist' \
    -d "$work_dir/mac"

  version="$(electron_version "$contents/Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist")"
  [ -n "$version" ] || error "Could not detect the Electron version Fountible is built on."

  info "Downloading Electron ${version} for Linux..."
  download_file \
    "https://github.com/electron/electron/releases/download/v${version}/electron-v${version}-linux-x64.zip" \
    "$work_dir/electron.zip"

  info "Assembling app..."
  unzip -q "$work_dir/electron.zip" -d "$stage_dir"
  mv "$stage_dir/electron" "$stage_dir/fountible"
  rm -f "$res_dir/default_app.asar"

  rm -rf "$contents/Resources/"*.lproj "$contents/Resources/icon.icns"
  cp -a "$contents/Resources/." "$res_dir/"

  # Alpha-video export needs macOS' encoders; without the binary Fountible
  # reports that export as unavailable instead of failing to exec a Mach-O file.
  rm -f "$res_dir/app.asar.unpacked/dist-native/fountible-alpha-encoder"
  link_eps_tools "$res_dir"
}

write_launcher() {
  # A wrapper rather than a symlink keeps the app path in argv[0], which
  # uninstall.sh and the update check match running processes against.
  cat > "$BIN_PATH" <<EOF
#!/bin/sh
exec "$APP_DIR/fountible" "\$@"
EOF

  chmod +x "$BIN_PATH"
}

write_desktop_file() {
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=Fountible
Comment=Design with your coding agents
Exec=$APP_DIR/fountible %U
TryExec=$APP_DIR/fountible
Icon=$APP_DIR/resources/icons/icon-light.png
Terminal=false
Type=Application
Categories=Graphics;Development;
StartupNotify=true
StartupWMClass=fountible
MimeType=x-scheme-handler/fountible;
EOF
}

refresh_desktop_caches() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
}

main() {
  local tmp_dir version asset sha512 current_version=""
  local -a release

  require_commands

  info "Resolving latest Fountible release..."
  mapfile -t release < <(resolve_release)
  [ "${#release[@]}" -eq 3 ] || error "Could not resolve the latest Fountible release."
  version="${release[0]}"
  asset="${release[1]}"
  sha512="${release[2]}"

  [ -f "$VERSION_PATH" ] && current_version="$(cat "$VERSION_PATH")"
  if [ "$current_version" = "$version" ] && [ -x "$APP_DIR/fountible" ]; then
    info "Fountible is already up to date (${version})."
    return 0
  fi

  info "Updating Fountible from ${current_version:-not installed} to ${version}."

  tmp_dir="$(mktemp -d)"
  # Expand now: tmp_dir is local and gone by the time the EXIT trap runs.
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" EXIT

  info "Downloading Fountible ${version} for macOS..."
  download_file "$RELEASES_URL/$asset" "$tmp_dir/fountible.zip"
  echo "$(base64 -d <<<"$sha512" | od -An -vtx1 | tr -d ' \n')  $tmp_dir/fountible.zip" |
    sha512sum -c --quiet - || error "Checksum mismatch for $asset"

  build_app "$tmp_dir" "$tmp_dir/fountible.zip" "$tmp_dir/stage"
  [ -x "$tmp_dir/stage/fountible" ] || error "Assembled app has no fountible executable."

  if pgrep -f "^$APP_DIR/fountible" >/dev/null 2>&1; then
    warn "Fountible is running; restart it to use ${version}."
  fi

  mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" "$BIN_DIR"
  rm -rf "$APP_DIR"
  mv "$tmp_dir/stage" "$APP_DIR"
  printf '%s\n' "$version" > "$VERSION_PATH"

  write_launcher
  write_desktop_file
  refresh_desktop_caches

  info "Fountible ${version} installed."
  info "Run 'fountible' or launch it from your application menu."
}

main "$@"
