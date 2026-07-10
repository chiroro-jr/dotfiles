#!/bin/sh

if ! command -v fish >/dev/null 2>&1; then
    yay -S --noconfirm --needed fish
fi
