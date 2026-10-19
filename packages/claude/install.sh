#!/usr/bin/env bash
# Claude Code Installer Script
# Installs/updates Claude Code globally via mise, then applies shared settings,
# plugins, and user-scoped MCP servers.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SHARED_SETTINGS="$REPO_ROOT/config/claude/settings.json"
SETTINGS_PATH="$HOME/.claude/settings.json"

MARKETPLACES=(
  "aquila-lab/wonder-plugins"
)
PLUGINS=(
  "wonder@wonder"
  "resend@claude-plugins-official"
)

info() {
  echo "[INFO] $*" >&2
}

warn() {
  echo "[WARN] $*" >&2
}

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi
command -v jq >/dev/null 2>&1 || {
  echo "[ERROR] jq is required." >&2
  exit 1
}

# 'mise use' both installs the version and sets it in the global config
mise use -g claude@latest

claude() {
  mise exec -- claude "$@"
}

# Merge rather than symlink: Claude Code rewrites settings.json, and local-only
# keys (such as autoMode, which can describe private repos) must stay out of
# this public repository. Shared values win; other existing keys are kept.
mkdir -p "$(dirname -- "$SETTINGS_PATH")"
if [ -f "$SETTINGS_PATH" ]; then
  merged="$(jq -s '.[0] * .[1]' "$SETTINGS_PATH" "$SHARED_SETTINGS")"
else
  merged="$(cat "$SHARED_SETTINGS")"
fi
printf '%s\n' "$merged" > "$SETTINGS_PATH"
info "Applied shared settings to $SETTINGS_PATH"

for marketplace in "${MARKETPLACES[@]}"; do
  claude plugin marketplace add "$marketplace" >/dev/null ||
    warn "Could not add plugin marketplace $marketplace"
done
for plugin in "${PLUGINS[@]}"; do
  claude plugin install --scope user "$plugin" >/dev/null ||
    warn "Could not install plugin $plugin"
done

# add_mcp_server <name> <command> [args...]
# Registers a user-scoped stdio server once its binary has been installed.
add_mcp_server() {
  local name="$1"
  local command="$2"
  shift 2

  if [ ! -x "$command" ]; then
    warn "Skipping MCP server $name; $command is not installed."
    return
  fi
  if claude mcp get "$name" >/dev/null 2>&1; then
    info "MCP server $name is already configured."
    return
  fi
  claude mcp add --scope user "$name" -- "$command" "$@"
}

add_mcp_server fff "$HOME/.local/bin/fff-mcp"
add_mcp_server pencil \
  "$HOME/.local/share/pen/resources/app.asar.unpacked/out/mcp-server-linux-x64" \
  --app desktop --agent claudeCodeCLI
