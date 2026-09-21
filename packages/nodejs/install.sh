#!/bin/sh
# Node.js Installer Script
# Installs/updates Node.js globally via mise

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# These are essential for node-gyp and native C++ modules
sudo pacman -S --noconfirm --needed \
    base-devel \
    openssl \
    zlib

# 'mise use' both installs the version and sets it in the global config
mise use -g node@latest
