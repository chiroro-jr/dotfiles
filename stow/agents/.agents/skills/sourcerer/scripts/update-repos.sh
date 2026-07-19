#!/usr/bin/env bash
set -u

ROOT="${SOURCERER_REPOS:-$HOME/.sourcerer/repos}"
MODE="pull"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: update-repos.sh [--root PATH] [--fetch-only] [--pull] [--dry-run]

Safely update Sourcerer cached repositories.

Default behavior:
  - find git repos under ~/.sourcerer/repos
  - skip dirty worktrees
  - fetch all remotes, tags, and prune deleted refs
  - pull --ff-only only when on a branch with an upstream
  - fetch only for detached HEAD or branches without upstream

Environment:
  SOURCERER_REPOS  Override repo cache root
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="${2:-}"
      shift 2
      ;;
    --fetch-only)
      MODE="fetch"
      shift
      ;;
    --pull)
      MODE="pull"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
  echo "Sourcerer repo root not found: $ROOT" >&2
  exit 1
fi

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '    dry-run: %q' "$1"
    shift
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

updated=0
fetched=0
skipped_dirty=0
skipped_nonbranch=0
failed=0
seen=0

while IFS= read -r -d '' gitdir; do
  repo="${gitdir%/.git}"
  rel="${repo#$ROOT/}"
  seen=$((seen + 1))
  echo "==> $rel"

  if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "    failed: not a worktree"
    failed=$((failed + 1))
    continue
  fi

  if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    echo "    skipped: dirty worktree"
    skipped_dirty=$((skipped_dirty + 1))
    continue
  fi

  if ! run "fetch" git -C "$repo" fetch --all --tags --prune; then
    echo "    failed: fetch"
    failed=$((failed + 1))
    continue
  fi

  if [[ "$MODE" == "fetch" ]]; then
    echo "    fetched"
    fetched=$((fetched + 1))
    continue
  fi

  branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -z "$branch" ]]; then
    echo "    fetched only: detached HEAD"
    skipped_nonbranch=$((skipped_nonbranch + 1))
    continue
  fi

  upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  if [[ -z "$upstream" ]]; then
    echo "    fetched only: branch '$branch' has no upstream"
    skipped_nonbranch=$((skipped_nonbranch + 1))
    continue
  fi

  if run "pull" git -C "$repo" pull --ff-only; then
    echo "    updated: $branch <- $upstream"
    updated=$((updated + 1))
  else
    echo "    failed: pull --ff-only"
    failed=$((failed + 1))
  fi
done < <(find "$ROOT" -type d -name .git -prune -print0 | sort -z)

echo
echo "Summary"
echo "  repos seen:        $seen"
echo "  updated:           $updated"
echo "  fetched only:      $fetched"
echo "  skipped nonbranch: $skipped_nonbranch"
echo "  skipped dirty:     $skipped_dirty"
echo "  failed:            $failed"

if [[ "$failed" -gt 0 ]]; then
  exit 1
fi
