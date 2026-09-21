#!/bin/sh

set -e

if pacman -Q t3code-bin >/dev/null 2>&1; then
  yay -Rns --noconfirm t3code-bin
else
  echo "T3 Code is not installed."
fi
