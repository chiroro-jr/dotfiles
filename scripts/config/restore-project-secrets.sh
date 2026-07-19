#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="$HOME/.config"
PROJECTS_DIR="$CONFIG_DIR/projects"
OP_VAULT="${OP_VAULT:-Personal}"
OP_PROJECT_SECRETS_DOCUMENT="${OP_PROJECT_SECRETS_DOCUMENT:-Project Secrets Archive}"

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

command -v op >/dev/null 2>&1 || error "1Password CLI (op) is required."
command -v tar >/dev/null 2>&1 || error "tar is required."

mkdir -p "$CONFIG_DIR"
tmp_dir="$(mktemp -d)"
trap "rm -rf '$tmp_dir'" EXIT
archive_path="$tmp_dir/projects.tar.gz"

op document get "$OP_PROJECT_SECRETS_DOCUMENT" \
  --vault "$OP_VAULT" \
  --out-file "$archive_path" \
  --file-mode 0600

while IFS= read -r entry; do
  case "$entry" in
    projects|projects/*) ;;
    *) error "Archive contains an unexpected path: $entry" ;;
  esac
done < <(tar -tzf "$archive_path")

if [ -e "$PROJECTS_DIR" ]; then
  backup_path="$CONFIG_DIR/projects.backup-$(date +%Y%m%d-%H%M%S)"
  mv -- "$PROJECTS_DIR" "$backup_path"
  echo "[INFO] Existing project secrets moved to $backup_path"
fi

tar -xzf "$archive_path" -C "$CONFIG_DIR"
chmod 700 "$PROJECTS_DIR"
find "$PROJECTS_DIR" -type d -exec chmod 700 {} +
find "$PROJECTS_DIR" -type f -exec chmod 600 {} +

echo "[INFO] Restored project secrets to $PROJECTS_DIR"
