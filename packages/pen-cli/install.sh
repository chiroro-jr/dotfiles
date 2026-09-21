#!/bin/sh

set -e

if ! command -v pnpm >/dev/null 2>&1; then
    echo "pnpm not installed. Install the pnpm package first."
    exit 1
fi

# @pen.dev/cli imports css-tree but does not declare it. pnpm will not expose
# svgo's nested copy, so inject the missing dependency before installing.
GLOBAL_DIR="$(pnpm root -g)"
WORKSPACE="$GLOBAL_DIR/pnpm-workspace.yaml"
mkdir -p "$GLOBAL_DIR"

if [ ! -f "$WORKSPACE" ]; then
    printf 'allowBuilds:\n  sharp: true\n' > "$WORKSPACE"
fi

if ! grep -q '@pen.dev/cli' "$WORKSPACE"; then
    cat >> "$WORKSPACE" <<'EOF'

packageExtensions:
  "@pen.dev/cli":
    dependencies:
      css-tree: ^3.0.1
EOF
fi

SHARP_IGNORE_GLOBAL_LIBVIPS=1 pnpm i -g @pen.dev/cli
