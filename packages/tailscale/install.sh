#!/bin/sh

yay -S --noconfirm --needed tailscale

# Enable and start the Tailscale daemon
sudo systemctl enable --now tailscaled
