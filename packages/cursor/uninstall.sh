#!/bin/sh

set -e

if pacman -Q cursor-bin >/dev/null 2>&1; then
  yay -Rns --noconfirm cursor-bin
else
  echo "Cursor is not installed."
fi
