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
  for script in "$ROOT/install.sh" "$ROOT/uninstall.sh"; do
    if ! bash -n "$script"; then
      fail "Invalid shell syntax: ${script#"$ROOT/"}"
    fi
  done

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

check_bootstrap_order() {
  local before="$1"
  local after="$2"
  local before_index=-1
  local after_index=-1
  local index

  for index in "${!INSTALLERS[@]}"; do
    [ "${INSTALLERS[$index]}" != "$before" ] || before_index="$index"
    [ "${INSTALLERS[$index]}" != "$after" ] || after_index="$index"
  done

  if [ "$before_index" -lt 0 ] || [ "$after_index" -lt 0 ]; then
    fail "Cannot verify bootstrap order: $before -> $after"
  elif [ "$before_index" -ge "$after_index" ]; then
    fail "Bootstrap order requires $before before $after"
  fi
}

check_bootstrap_sequence() {
  local installer
  local -A seen=()

  for installer in "${INSTALLERS[@]}"; do
    if [ -n "${seen[$installer]:-}" ]; then
      fail "Duplicate bootstrap target: $installer"
    fi
    seen[$installer]=1
  done

  check_bootstrap_order "scripts/system/install-build-dependencies.sh" "packages/stow/install.sh"
  check_bootstrap_order "packages/stow/install.sh" "scripts/config/install-dotfiles.sh"
  check_bootstrap_order "scripts/config/install-dotfiles.sh" "packages/mise/install.sh"
  check_bootstrap_order "packages/mise/install.sh" "packages/nodejs/install.sh"
  check_bootstrap_order "packages/mise/install.sh" "packages/pnpm/install.sh"
  check_bootstrap_order "packages/mise/install.sh" "packages/bun/install.sh"
  check_bootstrap_order "packages/codex/install.sh" "packages/worktrunk/install.sh"
  check_bootstrap_order "packages/fish/install.sh" "scripts/system/change-shell.sh"
  check_bootstrap_order "packages/hitch/install.sh" "scripts/system/change-shell.sh"
  check_bootstrap_order "scripts/config/install-dotfiles.sh" "scripts/config/install-hyprland-overrides.sh"
  check_bootstrap_order "scripts/system/uninstall-unwanted-programs.sh" "scripts/system/remove-orphans.sh"
  check_bootstrap_order "scripts/system/remove-orphans.sh" "scripts/system/change-shell.sh"
}

check_layout() {
  local package_dir

  if compgen -G "$ROOT/install-*.sh" >/dev/null || compgen -G "$ROOT/uninstall-*.sh" >/dev/null; then
    fail "Installer scripts must not live at repository root."
  fi

  if [ -e "$ROOT/docs" ]; then
    fail "docs/ should not exist; its former Waydroid instructions were intentionally removed."
  fi

  local entrypoint
  for entrypoint in install.sh uninstall.sh; do
    if [ ! -x "$ROOT/$entrypoint" ]; then
      fail "Missing or non-executable package entrypoint: $entrypoint"
    fi
  done

  if [ ! -f "$ROOT/config/hyprland-overrides.conf" ]; then
    fail "Missing config/hyprland-overrides.conf"
  fi

  local stow_package
  for stow_package in \
    agents fish git gram mise opencode pi vscode vscodium worktrunk zed \
    zennotes; do
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
check_bootstrap_sequence
check_layout

if [ "$failures" -gt 0 ]; then
  echo "[ERROR] Static verification failed: $failures issue(s)." >&2
  exit 1
fi

echo "[INFO] Static verification passed; no installer was run."
