#!/bin/sh
# Dokploy CLI Uninstaller Script
# Removes Dokploy CLI from the global mise config and uninstalls it

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run packages/mise/install.sh first."
    exit 1
fi

# Remove Dokploy CLI from the global config and uninstall it
mise unuse -g npm:@dokploy/cli@latest
mise uninstall npm:@dokploy/cli@latest
