#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXTENSIONS_FILE="$SCRIPT_DIR/extensions.txt"
CODIUM_BIN="$HOME/.local/bin/codium"

if [ ! -x "$CODIUM_BIN" ]; then
  echo "VSCodium is not installed. Run ./install.sh first." >&2
  exit 1
fi

while IFS= read -r extension || [ -n "$extension" ]; do
  [ -n "$extension" ] || continue
  "$CODIUM_BIN" --install-extension "$extension" ||
    printf '[WARN] Could not install VSCodium extension: %s\n' "$extension" >&2
done < "$EXTENSIONS_FILE"
