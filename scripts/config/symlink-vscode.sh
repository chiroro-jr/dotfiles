#!/bin/sh
set -e

DOTFILES_DIR="$HOME/dotfiles"
VSCODE_DIR="$HOME/.config/Code/User"

mkdir -p "$VSCODE_DIR"

ln -sf "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_DIR/settings.json"
ln -sf "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_DIR/keybindings.json"
