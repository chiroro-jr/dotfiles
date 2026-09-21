#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="${RUNNER_DIR:-$HOME/.local/share/actions-runner}"
TOKEN="${RUNNER_TOKEN:-}"
LOCAL_ONLY=0

info() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./runners/uninstall.sh [options]

Stops the runner service, deregisters it from GitHub when possible, and removes
the local install directory.

Options:
  --token TOKEN   Removal token from GitHub (or RUNNER_TOKEN)
  --local         Only remove local service/files; do not contact GitHub
  --dir PATH      Install directory (default: ~/.local/share/actions-runner, or RUNNER_DIR)
  -h, --help      Show this help

Examples:
  ./runners/uninstall.sh --token AAAA
  ./runners/uninstall.sh --local
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --token)
        [ "$#" -ge 2 ] || error "--token requires a value."
        TOKEN="$2"
        shift 2
        ;;
      --dir)
        [ "$#" -ge 2 ] || error "--dir requires a value."
        INSTALL_ROOT="$2"
        shift 2
        ;;
      --local)
        LOCAL_ONLY=1
        shift
        ;;
      *)
        error "Unknown option: $1"
        ;;
    esac
  done
}

stop_service() {
  if [ ! -x "$INSTALL_ROOT/svc.sh" ]; then
    return 0
  fi

  info "Stopping and uninstalling systemd service..."
  (
    cd "$INSTALL_ROOT"
    sudo ./svc.sh stop || true
    sudo ./svc.sh uninstall || true
  )
}

deregister_runner() {
  if [ ! -x "$INSTALL_ROOT/config.sh" ]; then
    return 0
  fi

  if [ ! -f "$INSTALL_ROOT/.runner" ]; then
    info "Runner is not configured locally."
    return 0
  fi

  if [ "$LOCAL_ONLY" -eq 1 ]; then
    info "Removing local runner configuration only..."
    (
      cd "$INSTALL_ROOT"
      ./config.sh remove --unattended --local
    )
    return 0
  fi

  if [ -z "$TOKEN" ]; then
    error "Missing --token (or RUNNER_TOKEN). Pass --local to remove files without deregistering on GitHub."
  fi

  info "Deregistering runner from GitHub..."
  (
    cd "$INSTALL_ROOT"
    ./config.sh remove --unattended --token "$TOKEN"
  )
}

remove_install_root() {
  if [ ! -e "$INSTALL_ROOT" ]; then
    info "Install directory not found: ${INSTALL_ROOT}"
    return 0
  fi

  info "Removing ${INSTALL_ROOT}..."
  rm -rf "$INSTALL_ROOT"
}

main() {
  parse_args "$@"

  if [ "$(id -u)" -eq 0 ]; then
    error "Do not run this uninstaller as root."
  fi

  if [ ! -d "$INSTALL_ROOT" ]; then
    info "Nothing to uninstall at ${INSTALL_ROOT}."
    exit 0
  fi

  stop_service
  deregister_runner
  remove_install_root

  info "Self-hosted runner uninstalled."
}

main "$@"
