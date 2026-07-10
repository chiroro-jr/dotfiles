#!/bin/sh

# Find where fish is located
# We use 'command -v' because it is the POSIX-compliant way to locate binaries
FISH_PATH=$(command -v fish)

# Check if fish is installed
if [ -z "$FISH_PATH" ]; then
    echo "Error: Fish shell is not installed."
    echo "Install it first with: sudo pacman -S fish"
    exit 1
fi

# Ensure the fish path is in /etc/shells
# chsh will often reject shells not listed in this file
if ! grep -Fxq "$FISH_PATH" /etc/shells; then
    echo "Adding $FISH_PATH to /etc/shells (requires sudo)..."
    echo "$FISH_PATH" | sudo tee -a /etc/shells
fi

# Change the shell for the current user
echo "Changing default shell to $FISH_PATH..."
if chsh -s "$FISH_PATH"; then
    echo "Success! Restart your terminal or log out/in to see the changes."
else
    echo "Error: Failed to change the shell."
    exit 1
fi
