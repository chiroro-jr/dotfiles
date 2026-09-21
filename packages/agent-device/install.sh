#!/bin/sh

if ! command -v pnpm >/dev/null 2>&1; then
    echo "pnpm not installed. Install the pnpm package first."
    exit 1
fi

pnpm i -g agent-device@latest
