#!/bin/sh
# Gleam Uninstaller Script
# Removes Gleam from the global mise config and uninstalls it

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# Remove gleam from the global config and uninstall it
mise unuse -g gleam@latest
mise uninstall gleam@latest
