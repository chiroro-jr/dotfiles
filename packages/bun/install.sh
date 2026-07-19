#!/bin/sh

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi
# Install the version declared in the Stow-managed global mise config.
# `mise install` does not rewrite that configuration.
mise install bun
