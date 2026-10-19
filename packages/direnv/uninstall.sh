#!/bin/sh
# Direnv Uninstaller Script
# Removes direnv from the global mise config and uninstalls it

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run packages/mise/install.sh first."
    exit 1
fi

# Remove direnv from the global config and uninstall it
mise unuse -g direnv@latest
mise uninstall direnv@latest
