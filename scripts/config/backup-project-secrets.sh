#!/usr/bin/env bash

set -euo pipefail

PROJECTS_DIR="$HOME/.config/projects"
OP_VAULT="${OP_VAULT:-Personal}"
OP_PROJECT_SECRETS_DOCUMENT="${OP_PROJECT_SECRETS_DOCUMENT:-Project Secrets Archive}"
ARCHIVE_NAME="projects.tar.gz"

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

command -v op >/dev/null 2>&1 || error "1Password CLI (op) is required."
command -v jq >/dev/null 2>&1 || error "jq is required."
command -v tar >/dev/null 2>&1 || error "tar is required."
[ -d "$PROJECTS_DIR" ] || error "Project secrets directory does not exist: $PROJECTS_DIR"

documents="$(op document list --vault "$OP_VAULT" --format json)"
if jq -e --arg title "$OP_PROJECT_SECRETS_DOCUMENT" \
  'any(.[]; .title == $title)' <<< "$documents" >/dev/null; then
  echo "[INFO] Updating 1Password document: $OP_PROJECT_SECRETS_DOCUMENT"
  tar -C "$HOME/.config" -czf - projects |
    op document edit "$OP_PROJECT_SECRETS_DOCUMENT" - \
      --vault "$OP_VAULT" \
      --file-name "$ARCHIVE_NAME" >/dev/null
else
  echo "[INFO] Creating 1Password document: $OP_PROJECT_SECRETS_DOCUMENT"
  tar -C "$HOME/.config" -czf - projects |
    op document create - \
      --title "$OP_PROJECT_SECRETS_DOCUMENT" \
      --vault "$OP_VAULT" \
      --file-name "$ARCHIVE_NAME" >/dev/null
fi

echo "[INFO] Backed up $PROJECTS_DIR to 1Password vault $OP_VAULT"
