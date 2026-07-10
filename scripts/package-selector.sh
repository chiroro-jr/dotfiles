#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="${1:?Usage: package-selector.sh <install|uninstall> [options]}"
shift

case "$ACTION" in
  install|uninstall) ;;
  *)
    echo "[ERROR] Unsupported package action: $ACTION" >&2
    exit 2
    ;;
esac

DRY_RUN=false
LIST_ONLY=false
SELECT_ALL=false

usage() {
  cat <<EOF
Usage: ./${ACTION}.sh [--all] [--dry-run] [--list]

Interactively select packages to ${ACTION}. Selections accept individual numbers,
ranges, or all packages:
  1 2 4       Select individual packages
  2-5         Select an inclusive range
  1, 3-5 9    Combine values and ranges
  a           Select all packages
  q           Quit without making changes

Options:
  --all       Select all available packages without prompting.
  --dry-run   Print selected package scripts without running them.
  --list      List available packages and exit.
  -h, --help  Show this help message.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --all) SELECT_ALL=true ;;
    --dry-run) DRY_RUN=true ;;
    --list) LIST_ONLY=true ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

packages=()
while IFS= read -r -d '' package_dir; do
  package_name="$(basename "$package_dir")"
  [ -x "$package_dir/$ACTION.sh" ] && packages+=("$package_name")
done < <(find "$ROOT/packages" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

if [ "${#packages[@]}" -eq 0 ]; then
  echo "[ERROR] No packages provide $ACTION.sh." >&2
  exit 1
fi

print_packages() {
  local index
  printf 'Available packages to %s:\n' "$ACTION"
  for index in "${!packages[@]}"; do
    printf '  %2d) %s\n' "$((index + 1))" "${packages[index]}"
  done
}

if "$LIST_ONLY"; then
  print_packages
  exit 0
fi

selected=()
if "$SELECT_ALL"; then
  selected=("${packages[@]}")
else
  while true; do
    print_packages
    read -r -p "Select packages (numbers, ranges, a=all, q=quit): " selection

    case "$selection" in
      q|Q)
        echo "[INFO] No packages selected."
        exit 0
        ;;
      a|A)
        selected=("${packages[@]}")
        break
        ;;
      "")
        echo "[WARN] Enter a selection or q to quit." >&2
        continue
        ;;
    esac

    selection="${selection//,/ }"
    declare -A selected_indexes=()
    valid=true

    for token in $selection; do
      if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        start=$((10#${BASH_REMATCH[1]}))
        end=$((10#${BASH_REMATCH[2]}))
        if ((start < 1 || end < start || end > ${#packages[@]})); then
          valid=false
          break
        fi
        for ((index = start; index <= end; index++)); do
          selected_indexes["$index"]=1
        done
      elif [[ "$token" =~ ^[0-9]+$ ]]; then
        index=$((10#$token))
        if ((index < 1 || index > ${#packages[@]})); then
          valid=false
          break
        fi
        selected_indexes["$index"]=1
      else
        valid=false
        break
      fi
    done

    if ! "$valid"; then
      echo "[WARN] Invalid selection. Use numbers, ranges such as 2-5, a, or q." >&2
      continue
    fi

    selected=()
    for ((index = 1; index <= ${#packages[@]}; index++)); do
      [ -n "${selected_indexes[$index]:-}" ] && selected+=("${packages[index - 1]}")
    done
    break
  done
fi

printf '[INFO] Selected packages to %s:\n' "$ACTION"
printf '  - %s\n' "${selected[@]}"

if "$DRY_RUN"; then
  printf '[INFO] Dry run; no package scripts will be executed.\n'
  for package_name in "${selected[@]}"; do
    printf '  %s\n' "packages/$package_name/$ACTION.sh"
  done
  exit 0
fi

read -r -p "Proceed? [y/N] " confirmation
if [[ ! "$confirmation" =~ ^[Yy]([Ee][Ss])?$ ]]; then
  echo "[INFO] Cancelled."
  exit 0
fi

for package_name in "${selected[@]}"; do
  echo "[INFO] ${ACTION^}ing $package_name..."
  "$ROOT/packages/$package_name/$ACTION.sh"
done

echo "[INFO] Selected packages processed successfully."
