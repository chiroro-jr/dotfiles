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
  vscode
  vscodium
  worktrunk
  zed
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

    source_real="$(readlink -f -- "$source" || true)"
    target_real="$(readlink -f -- "$target" || true)"
    # Also matches files reached through a folded directory symlink.
    if [ -n "$source_real" ] && [ "$source_real" = "$target_real" ]; then
      continue
    fi

    if [ -d "$target" ] && [ ! -L "$target" ]; then
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

# Codex follows skill-directory symlinks but skips SKILL.md file symlinks
# created by `stow --no-folding`. Fold each managed skill into a directory
# symlink unless the destination has extra local files.
skill_dir_is_stow_tree() {
  local src="$1"
  local dest="$2"
  local path rel target expected

  while IFS= read -r -d '' path; do
    rel="${path#"$dest/"}"
    if [ ! -L "$path" ]; then
      return 1
    fi
    target="$(readlink -f -- "$path" || true)"
    expected="$(readlink -f -- "$src/$rel" || true)"
    if [ -z "$target" ] || [ "$target" != "$expected" ]; then
      return 1
    fi
  done < <(find "$dest" \( -type f -o -type l \) -print0)

  return 0
}

fold_agent_skill_directories() {
  local src_skills="$STOW_DIR/agents/.agents/skills"
  local dest_skills="$HOME/.agents/skills"
  local skill dest name

  [ -d "$src_skills" ] || return 0
  mkdir -p "$dest_skills"

  for skill in "$src_skills"/*; do
    [ -d "$skill" ] || continue
    name="$(basename -- "$skill")"
    dest="$dest_skills/$name"
    skill="$(readlink -f -- "$skill")"

    if [ -L "$dest" ]; then
      ln -sfn --relative "$skill" "$dest"
      continue
    fi

    if [ -e "$dest" ]; then
      if ! skill_dir_is_stow_tree "$skill" "$dest"; then
        echo "[INFO] Leaving mixed skill directory in place: $dest"
        continue
      fi
      rm -rf -- "$dest"
    fi

    ln -sfn --relative "$skill" "$dest"
    echo "[INFO] Folded skill directory $dest"
  done
}

# Remove previous directory-symlink folds so `stow --no-folding` can
# recreate file trees without treating those links as foreign targets.
unfold_agent_skill_directories() {
  local src_skills="$STOW_DIR/agents/.agents/skills"
  local dest_skills="$HOME/.agents/skills"
  local skill dest name target expected

  [ -d "$src_skills" ] || return 0
  [ -d "$dest_skills" ] || return 0

  for skill in "$src_skills"/*; do
    [ -d "$skill" ] || continue
    name="$(basename -- "$skill")"
    dest="$dest_skills/$name"
    [ -L "$dest" ] || continue
    target="$(readlink -f -- "$dest" || true)"
    expected="$(readlink -f -- "$skill" || true)"
    if [ -n "$target" ] && [ "$target" = "$expected" ]; then
      rm -- "$dest"
    fi
  done
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
  if [ "$package" = agents ]; then
    mkdir -p "$HOME/.agents/skills"
    if [ -L "$HOME/.agents" ] || [ -L "$HOME/.agents/skills" ]; then
      echo "[ERROR] ~/.agents and ~/.agents/skills must be real directories so local skills can sit beside Stow-managed ones." >&2
      exit 1
    fi
    # File-level SKILL.md links from --no-folding are invisible to Codex.
    # Unfold previous directory links, restow the file tree, then fold
    # each skill into a relative directory symlink.
    unfold_agent_skill_directories
    stow --dir "$STOW_DIR" --target "$HOME" --no-folding --restow "$package"
    fold_agent_skill_directories
  else
    stow --dir "$STOW_DIR" --target "$HOME" --no-folding --restow "$package"
  fi
done

# Claude Code reads AGENTS.md per project only; global instructions must
# live at ~/.claude/CLAUDE.md.
mkdir -p "$HOME/.claude"
ln -sfn "$HOME/.agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"

# Claude Code discovers skills only in ~/.claude/skills. Link each global
# skill there, leaving existing entries (including reserved `synced`) alone.
mkdir -p "$HOME/.claude/skills"
for skill in "$HOME/.agents/skills"/*/; do
  name="$(basename -- "$skill")"
  dest="$HOME/.claude/skills/$name"
  [ -f "$skill/SKILL.md" ] || continue
  [ "$name" != synced ] || continue
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    continue
  fi
  ln -s "$HOME/.agents/skills/$name" "$dest"
  echo "[INFO] Linked Claude skill $dest"
done
