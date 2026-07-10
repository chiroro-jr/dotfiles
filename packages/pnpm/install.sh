#!/bin/sh

# 1. Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# 2. Check if pnpm is already installed
if command -v pnpm >/dev/null 2>&1; then
    echo "pnpm is already installed."
    exit 0
fi

# 'mise use' both installs the version and sets it in the global config
mise use --global pnpm@latest
