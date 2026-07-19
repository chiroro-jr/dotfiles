#!/bin/sh

for package in signal-desktop kdenlive libreoffice-fresh xournalpp spotify; do
    yay -Rns --noconfirm "$package" || true
done
