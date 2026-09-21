#!/bin/sh

set -e

if pacman -Q zed >/dev/null 2>&1; then
  yay -Rns --noconfirm zed
else
  echo "Zed is not installed."
fi
