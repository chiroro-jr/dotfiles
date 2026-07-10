#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
STOW_DIR="$REPO_ROOT/stow"
STOW_PACKAGES=(fish git zed)

command -v stow >/dev/null 2>&1 || {
  echo "[ERROR] GNU Stow is required. Run packages/stow/install.sh first." >&2
  exit 1
}

for package in "${STOW_PACKAGES[@]}"; do
  [ -d "$STOW_DIR/$package" ] || {
    echo "[ERROR] Missing Stow package: $package" >&2
    exit 1
  }

  echo "[INFO] Stowing $package"
  stow --dir "$STOW_DIR" --target "$HOME" --restow "$package"
done
