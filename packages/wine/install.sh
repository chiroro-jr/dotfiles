#!/bin/sh

set -eu

if ! pacman-conf --repo-list | grep -qx multilib; then
  echo "The multilib repository must be enabled in /etc/pacman.conf." >&2
  exit 1
fi

# Install Wine and its user-facing helper as explicitly installed packages.
yay -S --noconfirm --needed \
  wine-staging \
  winetricks

# Optional Wine runtime libraries. Marking these as dependencies allows the
# uninstall script to remove only those no longer needed by another package.
yay -S --noconfirm --needed --asdeps \
  wine-gecko \
  wine-mono \
  cabextract \
  unzip \
  7zip \
  freetype2 \
  lib32-freetype2 \
  ttf-ms-fonts \
  giflib \
  lib32-giflib \
  libpng \
  lib32-libpng \
  libldap \
  lib32-libldap \
  gnutls \
  lib32-gnutls \
  mpg123 \
  lib32-mpg123 \
  openal \
  lib32-openal \
  v4l-utils \
  lib32-v4l-utils \
  libpulse \
  lib32-libpulse \
  libgpg-error \
  lib32-libgpg-error \
  alsa-plugins \
  lib32-alsa-plugins \
  alsa-lib \
  lib32-alsa-lib \
  libjpeg-turbo \
  lib32-libjpeg-turbo \
  sqlite \
  lib32-sqlite \
  libxcomposite \
  lib32-libxcomposite \
  libxinerama \
  lib32-libxinerama \
  libgcrypt \
  lib32-libgcrypt \
  ncurses \
  lib32-ncurses \
  ocl-icd \
  lib32-ocl-icd \
  libxslt \
  lib32-libxslt \
  libva \
  lib32-libva \
  gtk3 \
  lib32-gtk3 \
  gst-plugins-base-libs \
  vulkan-icd-loader \
  lib32-vulkan-icd-loader

echo "Wine installed successfully."
