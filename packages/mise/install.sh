#!/bin/sh

set -e

if ! command -v mise >/dev/null 2>&1; then
    yay -S --noconfirm --needed mise
fi

# Install every tool in the Stow-managed global config.
mise install
