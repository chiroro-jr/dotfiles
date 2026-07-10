#!/bin/sh

if ! command -v mise >/dev/null 2>&1; then
    yay -S --noconfirm --needed mise
fi
