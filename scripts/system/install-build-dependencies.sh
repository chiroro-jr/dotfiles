#!/bin/sh

# Install build dependencies
yay -S --noconfirm --needed \
    base-devel \
    git \
    openssl \
    zlib \
    readline \
    libffi \
    sqlite
