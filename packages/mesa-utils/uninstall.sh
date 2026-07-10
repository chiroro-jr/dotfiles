#!/bin/sh
# Mesa Utils Uninstaller Script
# Removes mesa-utils

set -e

yay -Rns --noconfirm mesa-utils || true
