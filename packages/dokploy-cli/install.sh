#!/bin/sh
# Dokploy CLI Installer Script
# Installs/updates Dokploy CLI globally via mise

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run packages/mise/install.sh first."
    exit 1
fi

# GitHub releases ship no binaries, so install the npm package
# 'mise use' both installs the version and sets it in the global config
mise use -g npm:@dokploy/cli@latest
