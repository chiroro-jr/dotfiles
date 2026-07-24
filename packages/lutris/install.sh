#!/bin/sh

set -e

# Lutris plus the 32-bit graphics and networking libraries required by Wine games.
yay -S --noconfirm --needed \
  lutris \
  lib32-mesa \
  lib32-vulkan-icd-loader \
  lib32-vulkan-intel \
  lib32-gnutls
