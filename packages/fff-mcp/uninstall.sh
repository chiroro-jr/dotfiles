#!/bin/sh

INSTALL_DIR="${FFF_MCP_INSTALL_DIR:-$HOME/.local/bin}"
BINARY_NAME="fff-mcp"
BINARY_PATH="${INSTALL_DIR}/${BINARY_NAME}"

info() { printf '\033[1;34m%s\033[0m\n' "$*"; }
success() { printf '\033[1;38;5;208m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*" >&2; }

info "Uninstalling FFF MCP Server..."

# 1. Remove the binary
if [ -f "$BINARY_PATH" ]; then
    echo "Removing ${BINARY_PATH}..."
    rm -f "$BINARY_PATH"
    success "Binary removed."
else
    warn "Binary not found at ${BINARY_PATH}"
fi

# 2. Show instructions for removing MCP configs
echo ""
info "Remove MCP configuration from your AI assistants:"
echo ""

# Claude Code
if command -v claude >/dev/null 2>&1; then
    echo "[Claude Code] Run: claude mcp remove fff"
    echo ""
fi

# OpenCode
if command -v opencode >/dev/null 2>&1; then
    echo "[OpenCode] Remove the 'fff' entry from ~/.config/opencode/opencode.json"
    echo ""
fi

# Codex
if command -v codex >/dev/null 2>&1; then
    echo "[Codex] Run: codex mcp remove fff"
    echo ""
fi

success "FFF MCP Server uninstalled."
