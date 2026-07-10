#!/bin/sh
# Vite+ Uninstaller Script
# Removes vp and related Vite+ data from the machine via mise

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# Remove viteplus from the global config and uninstall it
mise unuse --global viteplus@latest
mise uninstall viteplus@latest
