#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXTENSIONS_FILE="$SCRIPT_DIR/extensions.txt"

yay -S --noconfirm --needed visual-studio-code-bin

if [ -f "$EXTENSIONS_FILE" ]; then
  while IFS= read -r extension || [ -n "$extension" ]; do
    [ -n "$extension" ] || continue
    code --install-extension "$extension" ||
      printf '[WARN] Could not install VS Code extension: %s\n' "$extension" >&2
  done < "$EXTENSIONS_FILE"
fi
