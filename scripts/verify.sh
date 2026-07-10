#!/usr/bin/env bash

# Static repository verification only: this script never runs installers.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

fail() {
  echo "[ERROR] $*" >&2
  failures=$((failures + 1))
}

check_shell_syntax() {
  local script
  while IFS= read -r -d '' script; do
    if ! bash -n "$script"; then
      fail "Invalid shell syntax: ${script#"$ROOT/"}"
    fi
  done < <(find "$ROOT/packages" "$ROOT/scripts" -type f -name '*.sh' -print0)
}

check_bootstrap_paths() {
  local installer

  # shellcheck source=bootstrap.sh
  source "$ROOT/scripts/bootstrap.sh"

  for installer in "${INSTALLERS[@]}"; do
    if [ ! -x "$ROOT/$installer" ]; then
      fail "Bootstrap target is missing or non-executable: $installer"
    fi
  done
}

check_layout() {
  local package_dir

  if compgen -G "$ROOT/install-*.sh" >/dev/null || compgen -G "$ROOT/uninstall-*.sh" >/dev/null; then
    fail "Installer scripts must not live at repository root."
  fi

  if [ -e "$ROOT/docs" ]; then
    fail "docs/ should not exist; its former Waydroid instructions were intentionally removed."
  fi

  if [ ! -f "$ROOT/config/hyprland-overrides.conf" ]; then
    fail "Missing config/hyprland-overrides.conf"
  fi

  local stow_package
  for stow_package in fish git zed vscode vscode-insiders; do
    if [ ! -d "$ROOT/stow/$stow_package" ]; then
      fail "Missing Stow package: stow/$stow_package"
    fi
  done

  while IFS= read -r -d '' package_dir; do
    if [ ! -f "$package_dir/install.sh" ] && [ ! -f "$package_dir/uninstall.sh" ]; then
      fail "Package directory has no install.sh or uninstall.sh: ${package_dir#"$ROOT/"}"
    fi
  done < <(find "$ROOT/packages" -mindepth 1 -maxdepth 1 -type d -print0)
}

check_shell_syntax
check_bootstrap_paths
check_layout

if [ "$failures" -gt 0 ]; then
  echo "[ERROR] Static verification failed: $failures issue(s)." >&2
  exit 1
fi

echo "[INFO] Static verification passed; no installer was run."
