#!/bin/sh

for package in 1password-beta signal-desktop kdenlive libreoffice-fresh xournalpp spotify; do
    yay -Rns --noconfirm "$package" || true
done
