#!/bin/sh
# Herdr Uninstaller Script
# Removes Herdr from the global mise config and uninstalls it

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# Remove Herdr from the global config and uninstall it
mise unuse -g herdr@latest
mise uninstall herdr@latest
