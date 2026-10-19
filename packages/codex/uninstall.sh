#!/bin/sh
# Codex Uninstaller Script
# Removes Codex from the global mise config and uninstalls it

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run packages/mise/install.sh first."
    exit 1
fi

# Remove Codex from the global config and uninstall it
mise unuse -g codex@latest
mise uninstall codex@latest
