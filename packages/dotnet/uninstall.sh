#!/bin/sh
# .NET Uninstaller Script
# Removes .NET from the global mise config and uninstalls it

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

version="$(mise ls -g --current --no-header dotnet 2>/dev/null | awk '$1 == "dotnet" { print $2; exit }')"

if [ -z "$version" ]; then
    echo ".NET is not configured globally in mise."
    exit 0
fi

echo "Uninstalling .NET $version..."
mise unuse -g "dotnet@$version"
mise uninstall "dotnet@$version"
