#!/bin/sh
# Android CLI Installer Script
# Installs/updates Android CLI globally via mise

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# 'mise use' both installs the version and sets it in the global config
mise use -g android-cli@latest
