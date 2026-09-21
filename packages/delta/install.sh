#!/usr/bin/env bash

set -euo pipefail

ASSET_API_URL="${ASSET_API_URL:-https://delta.dev/api/releases/nightly/latest/asset}"
DOWNLOAD_URL="${DOWNLOAD_URL:-}"
COOKIE_FILE="${DELTA_COOKIE_FILE:-$HOME/.config/delta/cookies.txt}"

INSTALL_DIR="$HOME/.local/share/delta"
APP_DIR="$INSTALL_DIR/delta.app"
VERSION_PATH="$INSTALL_DIR/version.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/dev.zed.Delta.desktop"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/delta"
ICON_NAME="dev.zed.Delta"
HICOLOR_DIR="$HOME/.local/share/icons/hicolor"
ICON_DIR="$HICOLOR_DIR/512x512/apps"
ICON_PATH="$ICON_DIR/${ICON_NAME}.png"
FAVICON_URL="https://delta.dev/favicon.svg"
FALLBACK_ICON_DIR="$HICOLOR_DIR/scalable/apps"
FALLBACK_ICON_PATH="$FALLBACK_ICON_DIR/${ICON_NAME}.svg"

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
Usage: ./packages/delta/install.sh

Installs or updates the latest Delta Linux nightly from:
  https://delta.dev/download

Installed paths:
  App:     ~/.local/share/delta/delta.app
  CLI:     ~/.local/bin/delta
  Desktop: ~/.local/share/applications/dev.zed.Delta.desktop
  Icon:    ~/.local/share/icons/hicolor/*/apps/dev.zed.Delta.png

Re-running this script skips the download when the installed version already
matches the version returned for the current download URL.

Options:
  -h, --help  Show this help message.

Environment:
  DOWNLOAD_URL         Optional direct tarball URL. Skips the release API.
  DELTA_VERSION        Optional version identity used with DOWNLOAD_URL.
  DELTA_COOKIE         Optional Cookie header for delta.dev (signed-in session).
  DELTA_SESSION        Optional delta.session cookie value.
  CF_CLEARANCE         Optional Cloudflare cf_clearance cookie value.
  CF_BM                Optional Cloudflare __cf_bm cookie value.
  DELTA_COOKIE_FILE    Netscape cookie jar used for delta.dev API requests.
                       Defaults to ~/.config/delta/cookies.txt.

Delta's download API is session-gated and behind Cloudflare. A delta.session
cookie alone is not enough; include cf_clearance (and usually __cf_bm) from a
signed-in browser, or keep a Netscape jar at ~/.config/delta/cookies.txt.
If that jar is missing, the installer will try Firefox/Zen cookies for delta.dev.
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || error "$1 is required."
}

write_env_cookie_jar() {
  local out="$1"

  python3 - "$out" <<'PY'
import os
import sys
from pathlib import Path

out = Path(sys.argv[1])
pairs = [
    ("delta.dev", "FALSE", "/", "delta.session", os.environ.get("DELTA_SESSION", "")),
    (".delta.dev", "TRUE", "/", "cf_clearance", os.environ.get("CF_CLEARANCE", "")),
    (".delta.dev", "TRUE", "/", "__cf_bm", os.environ.get("CF_BM", "")),
]
lines = ["# Netscape HTTP Cookie File"]
expiry = "1788000000"
for host, flag, path, name, value in pairs:
    value = (value or "").strip()
    if not value:
        continue
    lines.append(f"{host}\t{flag}\t{path}\tTRUE\t{expiry}\t{name}\t{value}")
if len(lines) == 1:
    raise SystemExit(1)
out.write_text("\n".join(lines) + "\n")
PY
}

import_browser_cookie_jar() {
  local out="$1"

  python3 - "$out" <<'PY'
import sqlite3
import sys
import tempfile
from pathlib import Path

out = Path(sys.argv[1])
home = Path.home()
candidates = []
for pattern in [
    ".config/zen/*/cookies.sqlite",
    ".zen/*/cookies.sqlite",
    ".mozilla/firefox/*.default*/cookies.sqlite",
    ".mozilla/firefox/*.default-release/cookies.sqlite",
]:
    candidates.extend(home.glob(pattern))

seen = set()
lines = ["# Netscape HTTP Cookie File"]
for src in candidates:
    if not src.is_file():
        continue
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        db = tmp_path / "cookies.sqlite"
        db.write_bytes(src.read_bytes())
        for extra in ("-wal", "-shm"):
            extra_src = Path(str(src) + extra)
            if extra_src.exists():
                (tmp_path / f"cookies.sqlite{extra}").write_bytes(extra_src.read_bytes())
        try:
            con = sqlite3.connect(db)
            rows = con.execute(
                """
                SELECT host, name, path, expiry, isSecure, value
                FROM moz_cookies
                WHERE host = 'delta.dev' OR host LIKE '%.delta.dev'
                """
            ).fetchall()
            con.close()
        except sqlite3.Error:
            continue
        for host, name, path, expiry, is_secure, value in rows:
            key = (host, name, path)
            if key in seen or not value:
                continue
            seen.add(key)
            exp = int(expiry / 1000) if expiry > 10_000_000_000 else int(expiry)
            include_sub = "TRUE" if host.startswith(".") else "FALSE"
            secure = "TRUE" if is_secure else "FALSE"
            lines.append(
                f"{host}\t{include_sub}\t{path}\t{secure}\t{exp}\t{name}\t{value}"
            )

if len(lines) == 1:
    raise SystemExit(1)
out.write_text("\n".join(lines) + "\n")
PY
}

append_auth_args() {
  local -n target="$1"
  local cookie_file="${2:-}"

  [ -z "${DELTA_COOKIE:-}" ] || target+=(-H "Cookie: $DELTA_COOKIE")
  if [ -n "$cookie_file" ] && [ -f "$cookie_file" ]; then
    target+=(-b "$cookie_file")
  elif [ -f "$COOKIE_FILE" ]; then
    target+=(-b "$COOKIE_FILE")
  fi
}

download_file() {
  local url="$1"
  local out="$2"
  local mode="${3:-quiet}"

  if [ "$mode" = "progress" ]; then
    curl -fL --progress-bar --retry 3 --retry-delay 2 "$url" -o "$out"
  else
    curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$out"
  fi
}

resolve_architecture() {
  [ "$(uname -s)" = "Linux" ] || error "Unsupported operating system: $(uname -s)."

  case "$(uname -m)" in
    x86_64|amd64)
      printf '%s\n' "x86_64"
      ;;
    aarch64|arm64)
      printf '%s\n' "aarch64"
      ;;
    *)
      error "Unsupported architecture: $(uname -m)."
      ;;
  esac
}

version_from_url() {
  python3 - "$1" <<'PY'
import re
import sys
from urllib.parse import unquote, urlparse

url = sys.argv[1]
path = unquote(urlparse(url).path)

match = re.search(r"/(v?\d+\.\d+\.\d+(?:[+-][A-Za-z0-9._-]+)?)/", path)
if match:
    print(match.group(1))
    raise SystemExit(0)

match = re.search(r"/releases/[^/]+/([^/]+)/", path)
if match:
    print(match.group(1))
    raise SystemExit(0)

name = path.rsplit("/", 1)[-1]
print(name or url)
PY
}

parse_release_metadata() {
  python3 - "$1" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    payload = json.load(fh)

version = str(payload.get("version", "")).strip()
url = str(payload.get("url", "")).strip()
if not version or not url:
    print("Delta release API did not return both version and url.", file=sys.stderr)
    sys.exit(1)

print(version)
print(url)
PY
}

fetch_release_metadata() {
  local api_url="$1"
  local metadata_path="$2"
  local cookie_jar="${3:-}"
  local curl_args=(
    -sS
    --retry 3
    --retry-delay 2
    -H "Accept: application/json"
    -H "Referer: https://delta.dev/download"
    -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:142.0) Gecko/20100101 Firefox/142.0"
    -o "$metadata_path"
    -w "%{http_code}"
  )

  append_auth_args curl_args "$cookie_jar"
  curl "${curl_args[@]}" "$api_url" || true
}

resolve_release_metadata() {
  local arch="$1"
  local metadata_path="$2"
  local api_url http_code
  local work_dir cookie_jar="" env_jar browser_jar

  work_dir="$(dirname "$metadata_path")"
  api_url="${ASSET_API_URL}?asset=delta&os=linux&arch=${arch}"

  if [ -n "${DELTA_SESSION:-}${CF_CLEARANCE:-}${CF_BM:-}" ]; then
    env_jar="$work_dir/env-cookies.txt"
    if write_env_cookie_jar "$env_jar"; then
      cookie_jar="$env_jar"
    fi
  fi

  http_code="$(fetch_release_metadata "$api_url" "$metadata_path" "$cookie_jar")"

  if [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
    browser_jar="$work_dir/browser-cookies.txt"
    if import_browser_cookie_jar "$browser_jar"; then
      info "Retrying Delta download API with cookies from the local Firefox/Zen profile..."
      cookie_jar="$browser_jar"
      http_code="$(fetch_release_metadata "$api_url" "$metadata_path" "$cookie_jar")"
    fi
  fi

  case "$http_code" in
    200)
      parse_release_metadata "$metadata_path"
      ;;
    401|403)
      error "Delta Linux downloads require a signed-in browser session from https://delta.dev/download.
Cloudflare clearance is required in addition to delta.session. Then either:
  - save Netscape cookies to ${COOKIE_FILE}
  - set DELTA_SESSION, CF_CLEARANCE, and CF_BM
  - or set DOWNLOAD_URL to the tarball URL from the download page"
      ;;
    *)
      error "Delta release API returned HTTP ${http_code:-000}."
      ;;
  esac
}

find_extracted_app_dir() {
  local root="$1"
  local binary

  if [ -x "$root/Delta/bin/delta" ]; then
    printf '%s\n' "$root/Delta"
    return
  fi

  if [ -x "$root/delta.app/bin/delta" ]; then
    printf '%s\n' "$root/delta.app"
    return
  fi

  binary="$(find "$root" -type f -path '*/bin/delta' | head -n 1)"
  [ -n "$binary" ] || error "Downloaded archive did not contain bin/delta."
  dirname "$(dirname "$binary")"
}

running_delta_pids() {
  {
    pgrep -u "$(id -u)" -f "$APP_DIR/bin/delta" 2>/dev/null || true
    pgrep -u "$(id -u)" -f "$BIN_PATH" 2>/dev/null || true
  } | sort -u | grep -v "^$$$" || true
}

stop_running_delta() {
  local pids

  pids="$(running_delta_pids)"
  [ -n "$pids" ] || return 0

  info "Stopping running Delta before replacing files..."
  # shellcheck disable=SC2086
  kill $pids 2>/dev/null || true

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pids="$(running_delta_pids)"
    [ -z "$pids" ] && return 0
    sleep 0.2
  done

  pids="$(running_delta_pids)"
  # shellcheck disable=SC2086
  [ -z "$pids" ] || kill -9 $pids 2>/dev/null || true
}

install_icon() {
  local src dest size found=false

  mkdir -p "$ICON_DIR" "$FALLBACK_ICON_DIR"

  if [ -d "$APP_DIR/share/icons/hicolor" ]; then
    for src in "$APP_DIR/share/icons/hicolor/"*/apps/*.{png,svg}; do
      [ -e "$src" ] || continue
      size="$(basename "$(dirname "$(dirname "$src")")")"
      mkdir -p "$HICOLOR_DIR/$size/apps"
      dest="$HICOLOR_DIR/$size/apps/$(basename "$src")"
      cp "$src" "$dest"
      found=true
    done
  fi

  if [ "$found" = true ]; then
    rm -f "$HICOLOR_DIR/512x512/apps/delta.png" "$HICOLOR_DIR/scalable/apps/delta.svg"
    return
  fi

  if download_file "$FAVICON_URL" "$FALLBACK_ICON_PATH"; then
    warn "No Delta icons were in the archive; installed the site favicon instead."
    return
  fi

  warn "Could not install a Delta icon."
}

write_desktop_file() {
  local source_desktop=""

  mkdir -p "$DESKTOP_DIR"

  if [ -d "$APP_DIR/share/applications" ]; then
    source_desktop="$(find "$APP_DIR/share/applications" -name '*.desktop' | head -n 1 || true)"
  fi

  if [ -n "$source_desktop" ]; then
    sed \
      -e "s|^TryExec=.*|TryExec=$BIN_PATH|" \
      -e "s|^Exec=delta|Exec=$BIN_PATH|" \
      -e "s|^Icon=.*|Icon=$ICON_PATH|" \
      "$source_desktop" > "$DESKTOP_FILE"
  else
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Delta
GenericName=Agent Workspace
Comment=A multiplayer environment for coding with agents.
TryExec=$BIN_PATH
StartupNotify=true
Exec=$BIN_PATH %U
Icon=$ICON_PATH
Categories=Utility;TextEditor;Development;IDE;
Keywords=delta;zed;agent;
MimeType=text/plain;application/x-zerosize;x-scheme-handler/delta;
EOF
  fi

  chmod +x "$DESKTOP_FILE"
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
  local arch tmp_dir metadata_path archive_path extracted_dir
  local version archive_url current_version asset_name
  local release_data=()

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
  require_command tar
  arch="$(resolve_architecture)"

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT
  metadata_path="$tmp_dir/release.json"

  if [ -n "$DOWNLOAD_URL" ]; then
    archive_url="$DOWNLOAD_URL"
    version="${DELTA_VERSION:-$(version_from_url "$archive_url")}"
    [ -n "$version" ] || error "Could not determine a version identity from DOWNLOAD_URL."
    info "Using DOWNLOAD_URL for Delta ${version}."
  else
    info "Resolving latest Delta nightly for linux-${arch}..."
    mapfile -t release_data < <(resolve_release_metadata "$arch" "$metadata_path")
    [ "${#release_data[@]}" -ge 2 ] || error "Could not resolve the latest Delta download."
    version="${release_data[0]}"
    archive_url="${release_data[1]}"
  fi

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$version" ] && [ -x "$BIN_PATH" ] && [ -x "$APP_DIR/bin/delta" ]; then
    info "Delta is already up to date (${version}). Skipping download."
    info "Binary: ${BIN_PATH}"
    return 0
  fi

  info "Updating Delta from ${current_version:-not installed} to ${version}."
  asset_name="delta-linux-${arch}.tar.gz"
  archive_path="$tmp_dir/$asset_name"

  info "Downloading ${asset_name}..."
  download_file "$archive_url" "$archive_path" progress

  tar -xzf "$archive_path" -C "$tmp_dir"
  extracted_dir="$(find_extracted_app_dir "$tmp_dir")"
  [ -x "$extracted_dir/bin/delta" ] || error "Extracted archive did not contain an executable bin/delta."

  mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"
  stop_running_delta
  rm -rf "$APP_DIR"
  mv "$extracted_dir" "$APP_DIR"
  chmod +x "$APP_DIR/bin/delta"
  ln -sfn "$APP_DIR/bin/delta" "$BIN_PATH"
  printf '%s\n' "$version" > "$VERSION_PATH"

  install_icon
  write_desktop_file
  refresh_desktop_caches

  if command -v pacman >/dev/null 2>&1 && pacman -Q git-delta >/dev/null 2>&1; then
    warn "git-delta is also installed. ~/.local/bin/delta should take precedence for the Delta editor."
  fi

  if [ -e "$HOME/.local/delta.app" ]; then
    warn "An official ~/.local/delta.app install is also present. This script uses ~/.local/share/delta/delta.app."
  fi

  info "Delta installed successfully."
  info "Version: ${version}"
  info "Source: ${archive_url}"
  info "Binary: ${BIN_PATH}"
  info "Run 'delta' or launch it from your application menu."
}

main "$@"
