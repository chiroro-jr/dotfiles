#!/usr/bin/env bash

set -euo pipefail

# Wonder only ships macOS and Windows builds. It is an Electron app, so this
# runs the Windows build's app.asar on the official Linux Electron runtime and
# swaps in Linux builds of its native/bundled pieces (node-pty, git, gh).
INSTALLER_URL="https://download.wonder.so/windows/nsis/x64"
ICON_URL="https://wonder.design/favicon.png"

INSTALL_DIR="$HOME/.local/share/wonder"
APP_DIR="$INSTALL_DIR/app"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/wonder.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/wonder"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
ICON_PATH="$ICON_DIR/wonder.png"

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

  [ "$(uname -m)" = "x86_64" ] || error "Wonder only provides an x86_64 Windows build to repackage."

  for command in 7z curl file node npm npx python3 sha256sum strings tar unzip; do
    command -v "$command" >/dev/null 2>&1 || error "Required command is not installed: $command"
  done
}

download_file() {
  curl -fL --progress-bar --retry 3 --retry-delay 2 "$1" -o "$2"
}

# The download endpoint only names the version in its Content-Disposition
# header, e.g. "Wonder Setup 0.2.183 - x64.exe".
resolve_latest_version() {
  curl -fsSIL --retry 3 "$INSTALLER_URL" |
    sed -nE 's/^content-disposition:.*Wonder Setup ([0-9][^ ]*) .*/\1/Ip' |
    tail -n 1
}

download_verified() {
  local url="$1" sha256="$2" out="$3"

  download_file "$url" "$out"
  echo "$sha256  $out" | sha256sum -c --quiet - || error "Checksum mismatch for $url"
}

# Wonder lists Linux git and gh targets (with checksums) but marks them
# development-only. Prints: git release, git asset, git sha256, gh release,
# gh asset, gh archive prefix, gh sha256.
resolve_bundled_tools() {
  python3 -I - "$1" <<'PY'
import re
import sys

source = open(sys.argv[1], encoding="utf-8").read()
git = re.search(
    r"release:`(v[^`]+)`,gitVersion:.*?\{platform:`linux`,arch:`x64`,developmentOnly:!0,"
    r"asset:`([^`]+)`,sha256:`([0-9a-f]{64})`",
    source,
)
gh = re.search(
    r"\{platform:`linux`,arch:`x64`,developmentOnly:!0,"
    r"asset:`(gh_([0-9.]+)_[^`]+)`,prefix:`([^`]*)`,sha256:`([0-9a-f]{64})`",
    source,
)
if not git or not gh:
    sys.exit("Could not find Wonder's Linux git/gh targets; the app layout changed.")

print(git[1], git[2], git[3], "v" + gh[2], gh[1], gh[3], gh[4], sep="\n")
PY
}

build_app() {
  local work_dir="$1" stage_dir="$2"
  local win_dir="$work_dir/win" src_dir="$work_dir/asar-src" res_dir="$stage_dir/resources"
  local electron_version pty_version pty_tgz
  local -a tools

  info "Extracting Windows installer..."
  7z x -y -o"$work_dir/nsis" "$work_dir/wonder-setup.exe" '$PLUGINSDIR/app-64.7z' >/dev/null
  7z x -y -o"$win_dir" "$work_dir/nsis/\$PLUGINSDIR/app-64.7z" >/dev/null
  npx -y @electron/asar extract "$win_dir/resources/app.asar" "$src_dir"

  electron_version="$(strings "$win_dir/Wonder.exe" | grep -oE 'Electron/[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | cut -d/ -f2)"
  [ -n "$electron_version" ] || error "Could not detect the Electron version Wonder is built on."
  pty_version="$(node -p "require(process.argv[1]).version" "$src_dir/dist-electron/node-pty/package.json")"
  mapfile -t tools < <(resolve_bundled_tools "$src_dir/dist-electron/main.js")
  [ "${#tools[@]}" -eq 7 ] || error "Could not resolve Wonder's bundled git/gh versions."

  info "Downloading Electron ${electron_version} for Linux..."
  download_file \
    "https://github.com/electron/electron/releases/download/v${electron_version}/electron-v${electron_version}-linux-x64.zip" \
    "$work_dir/electron.zip"

  info "Downloading git ${tools[0]} and gh ${tools[3]}..."
  download_verified "https://github.com/desktop/dugite-native/releases/download/${tools[0]}/${tools[1]}" "${tools[2]}" "$work_dir/git.tar.gz"
  download_verified "https://github.com/cli/cli/releases/download/${tools[3]}/${tools[4]}" "${tools[6]}" "$work_dir/gh.tar.gz"

  info "Downloading node-pty ${pty_version} for Linux..."
  pty_tgz="$(cd "$work_dir" && npm pack "@lydell/node-pty-linux-x64@${pty_version}" --silent)"
  rm -rf "$src_dir/dist-electron/node-pty"
  mkdir -p "$src_dir/dist-electron/node-pty"
  tar -xzf "$work_dir/$pty_tgz" -C "$src_dir/dist-electron/node-pty" --strip-components=1

  # Let the packaged app accept the Linux git/gh bundles assembled below.
  sed -i 's/{platform:`linux`,arch:`x64`,developmentOnly:!0,/{platform:`linux`,arch:`x64`,/g' \
    "$src_dir/dist-electron/main.js"

  info "Assembling app..."
  unzip -q "$work_dir/electron.zip" -d "$stage_dir"
  mv "$stage_dir/electron" "$stage_dir/wonder"
  rm -f "$res_dir/default_app.asar"
  npx -y @electron/asar pack "$src_dir" "$res_dir/app.asar" --unpack '*.node'
  cp "$win_dir/resources/todesktop-runtime-config.json" "$res_dir/"

  # Wonder checks for its license files and shell init scripts next to git,
  # and for a bundle.json receipt matching the expected archive checksum.
  mkdir -p "$res_dir/git"
  tar -xzf "$work_dir/git.tar.gz" -C "$res_dir/git"
  (cd "$win_dir/resources/git" && cp -r wonder-shell ./*.txt ./*.md "$res_dir/git/")
  printf '{"platform":"linux","arch":"x64","asset":"%s","sha256":"%s"}\n' "${tools[1]}" "${tools[2]}" > "$res_dir/git/bundle.json"

  mkdir -p "$res_dir/gh"
  tar -xzf "$work_dir/gh.tar.gz" -C "$res_dir/gh" --strip-components=1 "${tools[5]}/bin/gh" "${tools[5]}/LICENSE"
  printf '{"platform":"linux","arch":"x64","asset":"%s","sha256":"%s"}\n' "${tools[4]}" "${tools[6]}" > "$res_dir/gh/bundle.json"
}

write_desktop_file() {
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=Wonder
Comment=Design, code and ship with AI agents
Exec=$APP_DIR/wonder %U
TryExec=$APP_DIR/wonder
Icon=wonder
Terminal=false
Type=Application
Categories=Graphics;Development;
StartupNotify=true
StartupWMClass=wonder
MimeType=x-scheme-handler/wonder;
EOF
}

# Wonder.exe embeds its app icon; the 256px entry is stored as a PNG.
install_icon() {
  local work_dir="$1" icon

  if 7z x -y -o"$work_dir/rsrc" "$work_dir/win/Wonder.exe" '.rsrc/*/ICON/*' >/dev/null 2>&1; then
    icon="$(file -F '|' "$work_dir"/rsrc/.rsrc/*/ICON/* | awk -F'|' '/PNG image data, 256 x 256/ { print $1; exit }')"
  fi

  if [ -n "${icon:-}" ]; then
    cp "$icon" "$ICON_PATH"
  elif download_file "$ICON_URL" "$work_dir/icon.png"; then
    warn "Wonder.exe has no 256px icon; using the website favicon."
    cp "$work_dir/icon.png" "$ICON_PATH"
  else
    warn "Could not find a Wonder icon; skipping icon install."
  fi
}

# A wrapper rather than a symlink keeps the app path in argv[0], which
# uninstall.sh and the update check match running processes against.
write_launcher() {
  cat > "$BIN_PATH" <<EOF
#!/bin/sh
exec "$APP_DIR/wonder" "\$@"
EOF

  chmod +x "$BIN_PATH"
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
  local tmp_dir latest_version current_version=""

  require_commands

  info "Resolving latest Wonder release..."
  latest_version="$(resolve_latest_version)"
  [ -n "$latest_version" ] || error "Could not resolve the latest Wonder version."

  [ -f "$VERSION_PATH" ] && current_version="$(cat "$VERSION_PATH")"
  if [ "$current_version" = "$latest_version" ] && [ -x "$APP_DIR/wonder" ]; then
    info "Wonder is already up to date (${latest_version})."
    return 0
  fi

  info "Updating Wonder from ${current_version:-not installed} to ${latest_version}."

  tmp_dir="$(mktemp -d)"
  # Expand now: tmp_dir is local and gone by the time the EXIT trap runs.
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" EXIT

  info "Downloading Wonder ${latest_version} for Windows..."
  download_file "$INSTALLER_URL" "$tmp_dir/wonder-setup.exe"
  build_app "$tmp_dir" "$tmp_dir/stage"
  [ -x "$tmp_dir/stage/wonder" ] || error "Assembled app has no wonder executable."

  if pgrep -f "^$APP_DIR/wonder" >/dev/null 2>&1; then
    warn "Wonder is running; restart it to use ${latest_version}."
  fi

  mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" "$BIN_DIR" "$ICON_DIR"
  rm -rf "$APP_DIR"
  mv "$tmp_dir/stage" "$APP_DIR"
  printf '%s\n' "$latest_version" > "$VERSION_PATH"

  install_icon "$tmp_dir"
  write_desktop_file
  write_launcher
  refresh_desktop_caches

  info "Wonder ${latest_version} installed."
  info "Run 'wonder' or launch it from your application menu."
}

main "$@"
