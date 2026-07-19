#!/bin/sh

set -eu

command -v yay >/dev/null 2>&1 || {
    echo "Error: yay is required by this Omarchy bootstrap." >&2
    exit 1
}

# Build and bootstrap dependencies used by subsequent installers.
yay -S --noconfirm --needed \
    base-devel \
    curl \
    git \
    jq \
    libffi \
    openssl \
    python \
    readline \
    sqlite \
    tar \
    unzip \
    wget \
    zlib
