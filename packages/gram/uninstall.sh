#!/bin/sh

set -e

if pacman -Q gram >/dev/null 2>&1; then
  yay -Rns --noconfirm gram
else
  echo "Gram is not installed."
fi
