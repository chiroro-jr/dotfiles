#!/bin/sh

set -e

if pacman -Q lutris >/dev/null 2>&1; then
  yay -Rns --noconfirm lutris
else
  echo "Lutris is not installed."
fi
