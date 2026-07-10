#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

INSTALLERS=(
  "scripts/system/install-build-dependencies.sh"
  "packages/mise/install.sh"
  "packages/fish/install.sh"
  "packages/nodejs/install.sh"
  "packages/pnpm/install.sh"
  "packages/bun/install.sh"
  "packages/gemini-cli/install.sh"
  "packages/cursor-cli/install.sh"
  "packages/cursor/install.sh"
  "packages/opencode/install.sh"
  "packages/mariadb-clients/install.sh"
  "packages/vscode/install.sh"
  "packages/antigravity/install.sh"
  "packages/zed/install.sh"
  "packages/zed-preview/install.sh"
  "packages/android-studio/install.sh"
  "packages/direnv/install.sh"
  "packages/google-chrome/install.sh"
  "packages/helium-browser/install.sh"
  "packages/t3-code/install.sh"
  "packages/pencil/install.sh"
  "packages/uv/install.sh"
  "packages/stow/install.sh"
  "scripts/config/install-dotfiles.sh"
  "scripts/config/install-hyprland-overrides.sh"
  "scripts/config/symlink-vscode.sh"
  "scripts/system/uninstall-unwanted-programs.sh"
  "scripts/system/change-shell.sh"
  "scripts/system/remove-orphans.sh"
)

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap.sh [--check]

Runs the curated Omarchy setup sequence.

Options:
  --check     Validate repository layout, script syntax, and bootstrap paths
               without running any installer or modifying the system.
  -h, --help  Show this help message.
EOF
}

main() {
  case "${1:-}" in
    --check)
      exec "$BOOTSTRAP_ROOT/scripts/verify.sh"
      ;;
    -h|--help)
      usage
      ;;
    "")
      local installer
      for installer in "${INSTALLERS[@]}"; do
        [ -x "$BOOTSTRAP_ROOT/$installer" ] || {
          echo "[ERROR] Missing or non-executable installer: $installer" >&2
          exit 1
        }
        echo "[INFO] Running $installer"
        "$BOOTSTRAP_ROOT/$installer"
      done
      ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
