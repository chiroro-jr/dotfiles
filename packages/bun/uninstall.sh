#!/bin/sh
# Bun Uninstaller Script
# Removes Bun from the global mise config and uninstalls it

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# Remove bun from the global config and uninstall it
mise unuse -g bun@latest
mise uninstall bun@latest
