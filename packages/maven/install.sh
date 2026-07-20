#!/bin/sh

set -e

if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

# Install Maven at the version declared in the Stow-managed global mise config.
mise install maven
