#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXTENSIONS_FILE="$SCRIPT_DIR/extensions.txt"

if ! command -v code >/dev/null 2>&1; then
  echo "VS Code is not installed. Run ./install.sh first." >&2
  exit 1
fi

while IFS= read -r extension || [ -n "$extension" ]; do
  [ -n "$extension" ] || continue
  code --install-extension "$extension" ||
    printf '[WARN] Could not install VS Code extension: %s\n' "$extension" >&2
done < "$EXTENSIONS_FILE"
