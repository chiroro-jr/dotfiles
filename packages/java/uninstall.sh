#!/bin/sh
# Java Uninstaller Script
# Removes Java from the global mise config and uninstalls it

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# Remove java from the global config and uninstall it
mise unuse -g java@25
mise uninstall java@25
