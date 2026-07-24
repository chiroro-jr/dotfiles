#!/bin/sh

set -eu

installed_packages=""

for package in wine-staging winetricks; do
  if pacman -Q "$package" >/dev/null 2>&1; then
    installed_packages="$installed_packages $package"
  fi
done

if [ -z "$installed_packages" ]; then
  echo "Wine and Winetricks are not installed."
  exit 0
fi

# -Rns also removes dependencies that are no longer needed. Packages required
# elsewhere, or which were already explicitly installed, are preserved.
# shellcheck disable=SC2086
yay -Rns --noconfirm $installed_packages

echo "Wine uninstalled successfully."
