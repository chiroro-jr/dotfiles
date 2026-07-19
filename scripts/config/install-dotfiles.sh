#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
STOW_DIR="$REPO_ROOT/stow"
STOW_PACKAGES=(
  agents
  fish
  git
  gram
  mise
  opencode
  pi
  vscode
  vscodium
  worktrunk
  zed
  zennotes
)

command -v stow >/dev/null 2>&1 || {
  echo "[ERROR] GNU Stow is required. Run packages/stow/install.sh first." >&2
  exit 1
}

BACKUP_ROOT="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
backed_up=false

backup_conflicts() {
  local package="$1"
  local source relative target backup source_real target_real

  while IFS= read -r -d '' source; do
    relative="${source#"$STOW_DIR/$package/"}"
    target="$HOME/$relative"

    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
      continue
    fi

    if [ -L "$target" ]; then
      source_real="$(readlink -f -- "$source" || true)"
      target_real="$(readlink -f -- "$target" || true)"
      if [ -n "$source_real" ] && [ "$source_real" = "$target_real" ]; then
        continue
      fi
    elif [ -d "$target" ]; then
      echo "[ERROR] Refusing to replace directory with managed file: $target" >&2
      exit 1
    fi

    backup="$BACKUP_ROOT/$relative"
    mkdir -p "$(dirname -- "$backup")"
    mv -- "$target" "$backup"
    backed_up=true
    echo "[INFO] Backed up $target"
  done < <(find "$STOW_DIR/$package" \( -type f -o -type l \) -print0)
}

for package in "${STOW_PACKAGES[@]}"; do
  [ -d "$STOW_DIR/$package" ] || {
    echo "[ERROR] Missing Stow package: $package" >&2
    exit 1
  }
  backup_conflicts "$package"
done

if [ "$backed_up" = true ]; then
  echo "[INFO] Existing configuration backed up to $BACKUP_ROOT"
fi

for package in "${STOW_PACKAGES[@]}"; do
  echo "[INFO] Stowing $package"
  stow --dir "$STOW_DIR" --target "$HOME" --no-folding --restow "$package"
done

# Pi loads global instructions from ~/.pi/agent/AGENTS.md and discovers
# ~/.agents/skills directly, so only the instruction file needs a bridge.
mkdir -p "$HOME/.pi/agent"
ln -sfn "$HOME/.agents/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"
