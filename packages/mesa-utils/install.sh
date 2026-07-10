#!/bin/sh
# Mesa Utils Installer Script
# Installs mesa-utils required by Flutter on Linux

set -e

yay -S --noconfirm --needed mesa-utils
