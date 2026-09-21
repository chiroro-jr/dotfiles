#!/bin/sh
# Cursor CLI Installer Script
# Installs/updates Cursor CLI globally via mise

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# 'mise use' both installs the version and sets it in the global config.
# The registry shorthand is cursor-agent; fish aliases `agent` to it.
mise use -g cursor-agent@latest
