#!/bin/sh

set -e

if pacman -Q zen-browser-bin >/dev/null 2>&1; then
  yay -Rns --noconfirm zen-browser-bin
else
  echo "Zen Browser is not installed."
fi
