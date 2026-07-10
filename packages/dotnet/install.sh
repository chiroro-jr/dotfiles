#!/bin/sh
# .NET Installer Script
# Installs/updates the latest stable .NET SDK globally via mise

set -e

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    echo "Mise not installed. Run ./install-mise.sh first."
    exit 1
fi

latest_stable="$(
    mise ls-remote dotnet |
        awk '/^[0-9]+\.[0-9]+\.[0-9]+$/ { print }' |
        sort -V |
        tail -n 1
)"

if [ -z "$latest_stable" ]; then
    echo "Could not find a stable .NET version from mise ls-remote dotnet."
    exit 1
fi

echo "Installing .NET $latest_stable..."
mise use -g "dotnet@$latest_stable"
