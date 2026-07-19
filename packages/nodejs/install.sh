#!/bin/sh

# 1. Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# 2. Install build dependencies for Node.js
# These are essential for node-gyp and native C++ modules
sudo pacman -S --noconfirm --needed \
    base-devel \
    openssl \
    zlib

# Install the version declared in the Stow-managed global mise config.
# `mise install` does not rewrite that configuration.
mise install node
