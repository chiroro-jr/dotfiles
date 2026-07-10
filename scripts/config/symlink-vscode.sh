#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
DOTFILES_DIR="$REPO_ROOT/stow"
VSCODE_DIR="$HOME/.config/Code/User"

mkdir -p "$VSCODE_DIR"

ln -sf "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_DIR/settings.json"
ln -sf "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_DIR/keybindings.json"
