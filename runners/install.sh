#!/usr/bin/env bash

set -euo pipefail

REPO="actions/runner"
RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_ROOT="${RUNNER_DIR:-$HOME/.local/share/actions-runner}"
VERSION_PATH="$INSTALL_ROOT/version.txt"

URL="${RUNNER_URL:-}"
TOKEN="${RUNNER_TOKEN:-}"
NAME="${RUNNER_NAME:-}"
LABELS="${RUNNER_LABELS:-}"
REPLACE=0
INSTALL_SERVICE=1

info() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./runners/install.sh --url <github-url> --token <registration-token> [options]

Downloads the latest GitHub Actions runner into:
  ~/.local/share/actions-runner

Then registers it with GitHub and installs it as a systemd service by default.

Required:
  --url URL           Repository or organization URL (or RUNNER_URL)
  --token TOKEN       Registration token from GitHub (or RUNNER_TOKEN)
                      Create one under Settings → Actions → Runners → New self-hosted runner

Options:
  --name NAME         Runner name (default: machine hostname)
  --labels LABELS     Extra comma-separated labels
  --replace           Replace an existing runner with the same name
  --no-service        Configure only; do not install/start the systemd service
  --dir PATH          Install directory (default: ~/.local/share/actions-runner, or RUNNER_DIR)
  -h, --help          Show this help

Examples:
  ./runners/install.sh --url https://github.com/OWNER/REPO --token AAAA
  RUNNER_URL=https://github.com/OWNER/REPO RUNNER_TOKEN=AAAA ./runners/install.sh --labels desktop,linux
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

  error "curl or wget is required."
}

download_github_api_file() {
  local url="$1"
  local out="$2"

  if command -v curl >/dev/null 2>&1; then
    local headers=(
      -H "Accept: application/vnd.github+json"
      -H "X-GitHub-Api-Version: 2022-11-28"
    )
    [ -z "${GITHUB_RELEASES_TOKEN:-}" ] || headers+=(-H "Authorization: Bearer $GITHUB_RELEASES_TOKEN")
    curl -fsSL --retry 3 --retry-delay 2 "${headers[@]}" "$url" -o "$out"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    local headers=(
      --header="Accept: application/vnd.github+json"
      --header="X-GitHub-Api-Version: 2022-11-28"
    )
    [ -z "${GITHUB_RELEASES_TOKEN:-}" ] || headers+=(--header="Authorization: Bearer $GITHUB_RELEASES_TOKEN")
    wget -qO "$out" "${headers[@]}" "$url"
    return
  fi

  error "curl or wget is required."
}

require_tools() {
  command -v python3 >/dev/null 2>&1 || error "python3 is required to parse GitHub release metadata."
  command -v tar >/dev/null 2>&1 || error "tar is required to extract the runner archive."
}

resolve_asset_name() {
  local os arch

  case "$(uname -s)" in
    Linux) os="linux" ;;
    Darwin) os="osx" ;;
    *) error "Unsupported operating system: $(uname -s)." ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64) arch="x64" ;;
    arm64|aarch64) arch="arm64" ;;
    armv7l) arch="arm" ;;
    *) error "Unsupported architecture: $(uname -m)." ;;
  esac

  printf '%s\n' "actions-runner-${os}-${arch}"
}

resolve_release_metadata() {
  local metadata_path="$1"
  local asset_prefix="$2"

  download_github_api_file "$RELEASE_API_URL" "$metadata_path"

  python3 - "$metadata_path" "$asset_prefix" <<'PY'
import json
import sys

path = sys.argv[1]
asset_prefix = sys.argv[2]

with open(path, "r", encoding="utf-8") as fh:
    release = json.load(fh)

tag = release["tag_name"]
version = tag.removeprefix("v")
asset_name = f"{asset_prefix}-{version}.tar.gz"
assets = release.get("assets", [])
asset = next((a for a in assets if a.get("name") == asset_name), None)

if asset is None:
    print(f"Asset {asset_name} was not found in latest release.", file=sys.stderr)
    sys.exit(1)

print(tag)
print(version)
print(asset_name)
print(asset["browser_download_url"])
PY
}

runner_configured() {
  [ -f "$INSTALL_ROOT/.runner" ]
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --url)
        [ "$#" -ge 2 ] || error "--url requires a value."
        URL="$2"
        shift 2
        ;;
      --token)
        [ "$#" -ge 2 ] || error "--token requires a value."
        TOKEN="$2"
        shift 2
        ;;
      --name)
        [ "$#" -ge 2 ] || error "--name requires a value."
        NAME="$2"
        shift 2
        ;;
      --labels)
        [ "$#" -ge 2 ] || error "--labels requires a value."
        LABELS="$2"
        shift 2
        ;;
      --dir)
        [ "$#" -ge 2 ] || error "--dir requires a value."
        INSTALL_ROOT="$2"
        VERSION_PATH="$INSTALL_ROOT/version.txt"
        shift 2
        ;;
      --replace)
        REPLACE=1
        shift
        ;;
      --no-service)
        INSTALL_SERVICE=0
        shift
        ;;
      *)
        error "Unknown option: $1"
        ;;
    esac
  done
}

install_or_update_runner_app() {
  local asset_prefix tmp_dir metadata_path tag version asset_name archive_url archive_path current_version

  asset_prefix="$(resolve_asset_name)"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "'"$tmp_dir"'"' EXIT

  metadata_path="$tmp_dir/release.json"
  info "Resolving latest actions/runner release..."
  mapfile -t release_data < <(resolve_release_metadata "$metadata_path" "$asset_prefix")
  [ "${#release_data[@]}" -ge 4 ] || error "Could not resolve latest actions/runner release metadata."

  tag="${release_data[0]}"
  version="${release_data[1]}"
  asset_name="${release_data[2]}"
  archive_url="${release_data[3]}"

  current_version=""
  if [ -f "$VERSION_PATH" ]; then
    current_version="$(cat "$VERSION_PATH")"
  fi

  if [ "$current_version" = "$tag" ] && [ -x "$INSTALL_ROOT/config.sh" ] && [ -x "$INSTALL_ROOT/run.sh" ]; then
    info "Runner application is already up to date (${tag})."
    trap - EXIT
    rm -rf "$tmp_dir"
    return 0
  fi

  if runner_configured; then
    error "Runner is already configured at ${INSTALL_ROOT}. Uninstall first, or point --dir at a new path."
  fi

  info "Installing actions/runner ${tag} into ${INSTALL_ROOT}..."
  archive_path="$tmp_dir/$asset_name"
  download_file "$archive_url" "$archive_path" "progress"

  mkdir -p "$INSTALL_ROOT"
  tar xzf "$archive_path" -C "$INSTALL_ROOT"
  printf '%s\n' "$tag" > "$VERSION_PATH"

  if [ -x "$INSTALL_ROOT/bin/installdependencies.sh" ]; then
    info "Installing runner OS dependencies..."
    if ! sudo "$INSTALL_ROOT/bin/installdependencies.sh"; then
      if [ -f /etc/os-release ] && grep -qi '^ID=arch' /etc/os-release; then
        info "GitHub's dependency installer does not support Arch Linux; continuing with system packages."
        info "Ensure icu, openssl, krb5, and zlib are installed if the runner fails to start."
      else
        error "Failed to install runner OS dependencies."
      fi
    fi
  fi

  trap - EXIT
  rm -rf "$tmp_dir"
}

configure_runner() {
  local -a config_args

  [ -n "$URL" ] || error "Missing --url (or RUNNER_URL)."
  [ -n "$TOKEN" ] || error "Missing --token (or RUNNER_TOKEN)."

  if runner_configured; then
    info "Runner is already configured at ${INSTALL_ROOT}."
    return 0
  fi

  config_args=(--unattended --url "$URL" --token "$TOKEN")
  [ -z "$NAME" ] || config_args+=(--name "$NAME")
  [ -z "$LABELS" ] || config_args+=(--labels "$LABELS")
  [ "$REPLACE" -eq 0 ] || config_args+=(--replace)

  info "Registering runner with GitHub..."
  (
    cd "$INSTALL_ROOT"
    ./config.sh "${config_args[@]}"
  )
}

install_service() {
  if [ "$INSTALL_SERVICE" -eq 0 ]; then
    info "Skipping systemd service install (--no-service)."
    info "Start manually with: cd ${INSTALL_ROOT} && ./run.sh"
    return 0
  fi

  [ -x "$INSTALL_ROOT/svc.sh" ] || error "svc.sh was not found in ${INSTALL_ROOT}."

  info "Installing systemd service..."
  (
    cd "$INSTALL_ROOT"
    sudo ./svc.sh install "$(id -un)"
    sudo ./svc.sh start
    sudo ./svc.sh status || true
  )
}

main() {
  parse_args "$@"
  require_tools

  if [ "$(id -u)" -eq 0 ]; then
    error "Do not run this installer as root. config.sh refuses root unless RUNNER_ALLOW_RUNASROOT is set."
  fi

  install_or_update_runner_app
  configure_runner
  install_service

  info "Self-hosted runner ready."
  info "Install root: ${INSTALL_ROOT}"
  if [ -f "$VERSION_PATH" ]; then
    info "Version: $(cat "$VERSION_PATH")"
  fi
}

main "$@"
