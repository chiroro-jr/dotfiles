#!/usr/bin/env bash
# Resolve a repository into the Sourcerer cache, ready to read, and print its path.
#
# The cache lives in a folder the OS prunes by itself (/var/tmp on Linux,
# $TMPDIR on macOS), so files in long-unused repos can disappear one at a time.
# This script repairs that on every use: it restores deleted files from git,
# and re-clones when git's own data is damaged.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: repo.sh <repo> [ref]

  repo  https://host/owner/repo[.git], git@host:owner/repo[.git], or owner/repo (GitHub)
  ref   optional branch, tag, or commit; checked out in its own folder (<repo>@<ref>)
        so different refs never disturb each other. Default: the remote's default branch.

Prints the absolute path of the ready-to-read checkout on stdout.

Environment:
  SOURCERER_REPOS  Override the cache root
EOF
}

cache_root() {
  if [[ -n "${SOURCERER_REPOS:-}" ]]; then
    echo "$SOURCERER_REPOS"
  elif [[ "$OSTYPE" == darwin* ]]; then
    echo "${TMPDIR%/}/sourcerer"
  else
    echo /var/tmp/sourcerer
  fi
}

# Prints "<clone-url> <host>/<owner>/<repo>".
parse_repo() {
  local input="$1" host path
  case "$input" in
    https://* | http://*)
      input="${input#*://}"
      host="${input%%/*}"
      path="${input#*/}"
      ;;
    git@*:*)
      input="${input#git@}"
      host="${input%%:*}"
      path="${input#*:}"
      ;;
    */*)
      host=github.com
      path="$input"
      ;;
    *)
      echo "Unrecognized repository: $1" >&2
      return 1
      ;;
  esac
  path="${path%/}"
  path="${path%.git}"
  # Keep only owner/repo so deep links like .../tree/main/src still resolve.
  path="$(cut -d/ -f1-2 <<<"$path")"
  if [[ "$path" != */* ]]; then
    echo "Unrecognized repository: $1" >&2
    return 1
  fi
  echo "https://$host/$path.git $host/$path"
}

# Clones into a temp folder first so a concurrent caller never sees a partial clone.
clone() {
  local url="$1" dir="$2" tmp
  mkdir -p "$(dirname "$dir")"
  tmp="$(mktemp -d "$dir.clone.XXXXXX")"
  # No background maintenance: it would keep writing into $tmp after the move.
  if ! git -c maintenance.auto=false -c gc.auto=0 clone --quiet --filter=blob:none "$url" "$tmp"; then
    rm -rf "$tmp"
    echo "Clone failed: $url" >&2
    return 1
  fi
  # Another caller may have finished first; keep theirs.
  if [[ -e "$dir" ]]; then
    rm -rf "$tmp"
  else
    mv "$tmp" "$dir"
  fi
}

fetch_or_warn() {
  # A network failure is not damage: warn and keep using the cached state.
  if ! git -C "$1" fetch --quiet --tags --prune --force origin; then
    echo "Warning: fetch failed; using cached state of $1" >&2
  fi
}

# Resets the base checkout to the remote default branch. Returns 1 when it is unusable.
refresh_base() {
  local dir="$1" default
  git -C "$dir" rev-parse --verify --quiet HEAD >/dev/null 2>&1 || return 1
  fetch_or_warn "$dir"
  default="$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" || {
    git -C "$dir" remote set-head origin --auto >/dev/null 2>&1 || true
    default="$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD)" || return 1
  }
  # The cache is read-only reference material, so reset to the remote tip.
  git -C "$dir" checkout --quiet --force -B "${default#origin/}" "$default" || return 1
  # Bring back tracked files the OS pruned.
  git -C "$dir" restore --worktree --source=HEAD -- . || return 1
}

# Prints the commit a ref names, preferring the remote's branch of that name.
resolve_ref() {
  local dir="$1" ref="$2"
  git -C "$dir" rev-parse --verify --quiet "origin/$ref^{commit}" ||
    git -C "$dir" rev-parse --verify --quiet "$ref^{commit}"
}

# Each ref gets its own worktree beside the base checkout, so callers reading
# different refs of one repo never switch files under each other.
checkout_ref() {
  local base="$1" ref="$2" commit wt
  commit="$(resolve_ref "$base" "$ref")" || {
    echo "Ref not found: $ref" >&2
    return 1
  }
  wt="$base@${ref//\//__}"
  if git -C "$wt" rev-parse --verify --quiet HEAD >/dev/null 2>&1 &&
    git -C "$wt" checkout --quiet --force --detach "$commit" 2>/dev/null &&
    git -C "$wt" restore --worktree --source=HEAD -- . 2>/dev/null; then
    echo "$wt"
    return
  fi
  # Missing or damaged: recreate it.
  rm -rf "$wt"
  git -C "$base" worktree prune
  if ! git -C "$base" worktree add --quiet --force --detach "$wt" "$commit" 2>/dev/null; then
    # A concurrent caller may have just created it.
    git -C "$wt" rev-parse --verify --quiet HEAD >/dev/null 2>&1 || {
      echo "Could not create worktree for $ref at $wt" >&2
      return 1
    }
  fi
  echo "$wt"
}

main() {
  if [[ $# -lt 1 || $# -gt 2 || "$1" == -h || "$1" == --help ]]; then
    usage >&2
    exit 2
  fi
  local ref="${2:-}" parsed url rel dir
  parsed="$(parse_repo "$1")"
  url="${parsed% *}"
  rel="${parsed#* }"
  dir="$(cache_root)/$rel"

  # Serialize callers per repo: a concurrent git operation would otherwise fail
  # on git's own lock files and be mistaken for damage, triggering a re-clone.
  # flock is missing on stock macOS; there, callers run unserialized.
  mkdir -p "$(dirname "$dir")"
  if command -v flock >/dev/null; then
    exec 9>"$dir.lock"
    flock 9
  fi

  if ! { [[ -e "$dir" ]] && refresh_base "$dir"; }; then
    # Missing, or too damaged to repair: start over.
    rm -rf "$dir"
    clone "$url" "$dir"
    refresh_base "$dir" || {
      echo "Could not check out the default branch in $dir" >&2
      exit 1
    }
  fi

  if [[ -n "$ref" ]]; then
    checkout_ref "$dir" "$ref" || exit 1
  else
    echo "$dir"
  fi
}

main "$@"
