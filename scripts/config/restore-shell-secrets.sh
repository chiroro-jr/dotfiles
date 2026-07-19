#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE_PATH="$REPO_ROOT/config/1password/secrets.fish.tpl"
OUTPUT_PATH="$HOME/.config/fish/conf.d/secrets.fish"
OP_VAULT="${OP_VAULT:-Personal}"
OP_SHELL_SECRETS_ITEM="${OP_SHELL_SECRETS_ITEM:-Workstation Shell Secrets}"

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

command -v op >/dev/null 2>&1 || error "1Password CLI (op) is required."
[ -f "$TEMPLATE_PATH" ] || error "Missing template: $TEMPLATE_PATH"

# Escape replacement metacharacters before substituting reference components.
escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

vault="$(escape_sed_replacement "$OP_VAULT")"
item="$(escape_sed_replacement "$OP_SHELL_SECRETS_ITEM")"
tmp_template="$(mktemp)"
trap 'rm -f "$tmp_template"' EXIT

sed \
  -e "s|__VAULT__|$vault|g" \
  -e "s|__ITEM__|$item|g" \
  "$TEMPLATE_PATH" > "$tmp_template"

mkdir -p "$(dirname -- "$OUTPUT_PATH")"
op inject \
  --in-file "$tmp_template" \
  --out-file "$OUTPUT_PATH" \
  --file-mode 0600 \
  --force
chmod 600 "$OUTPUT_PATH"

if command -v fish >/dev/null 2>&1; then
  fish -n "$OUTPUT_PATH" || error "Generated Fish secrets file has invalid syntax."
fi

echo "[INFO] Restored shell secrets to $OUTPUT_PATH"
