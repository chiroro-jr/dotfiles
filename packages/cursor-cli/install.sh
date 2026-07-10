#!/usr/bin/env bash

set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl is required to install Cursor CLI." >&2
  exit 1
fi

echo "[INFO] Installing Cursor CLI using the official installer..."
curl https://cursor.com/install -fsS | bash

echo "[INFO] Cursor CLI installation complete."
