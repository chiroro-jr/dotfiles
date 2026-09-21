#!/bin/sh

set -e

if ! command -v pnpm >/dev/null 2>&1; then
    echo "pnpm not installed. Install the pnpm package first."
    exit 1
fi

SHARP_IGNORE_GLOBAL_LIBVIPS=1 pnpm remove @pen.dev/cli -g
