# Omarchy Customization

This repository contains a collection of shell scripts to automate the customization and setup of the **Omarchy** Linux (based on Arch Linux).

It handles the installation of packages, development tools, and configuration files (dotfiles) to create a consistent development environment.

## Prerequisites

- **Omarchy Linux** installation.
- **yay** (AUR helper) must be installed.

## Usage

To set up the environment, simply run the master script:

```bash
./run-all.sh
```

## What it does

The `run-all.sh` script orchestrates the following process:

1.  **System Setup**:
    - Installs essential build dependencies.
    - Installs `mise` for managing runtime environments.
    - Installs `stow` for dotfiles management.

2.  **Package Installation**:
    - **Shell**: Fish
    - **Development**: Node.js, pnpm, Bun, Gemini CLI, Cursor CLI, Opencode, T3 Code, MariaDB Clients.
    - **Editors**: VS Code, VS Code Insiders, Cursor, Zed, Zed Preview, Antigravity.

3.  **Configuration & Dotfiles**:
    - Clones dotfiles from `https://github.com/chiroro-jr/dotfiles`.
    - Uses `stow` to apply configurations for `fish`, `git`, `zed`, and `opencode`.
    - Manually symlinks settings for VS Code and VS Code Insiders.
    - Applies custom **Hyprland** overrides (`hyprland-overrides.conf`) by injecting a source line into the main config.

4.  **Finalization**:
    - Uninstalls unwanted default programs.
    - Changes the default shell to `fish`.
    - Removes orphaned packages.

## Rclone Google Drive photos backup

Install rclone:

```bash
./packages/install-rclone.sh
```

Configure Google Drive once:

```bash
rclone config
```

Use remote name `gdrive`, storage `drive`, scope `drive`, browser auth. For backups, use `rclone copy` only; it uploads new/changed files and does not delete Drive files.

Manual photos backup:

```bash
cd /mnt/Nebula/gdrive/photos
rclone copy . gdrive:photos -P
```

Enable nightly backup from `00:00` with max runtime `6h`:

```bash
mkdir -p ~/.config/systemd/user
ln -sf ~/omarchy-customization/services/rclone-photos-backup.service ~/.config/systemd/user/
ln -sf ~/omarchy-customization/services/rclone-photos-backup.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now rclone-photos-backup.timer
```

Check timer/status/logs:

```bash
systemctl --user list-timers rclone-photos-backup.timer
systemctl --user status rclone-photos-backup.service
journalctl --user -u rclone-photos-backup.service -f
tail -f ~/.local/state/rclone/photos-backup.log
```

Manual service run:

```bash
systemctl --user start rclone-photos-backup.service
```

Uninstall rclone:

```bash
./packages/uninstall-rclone.sh
```

## Scripts Overview

- `run-all.sh`: The main entry point that executes all other scripts in the correct order.
- `install-*.sh`: Scripts dedicated to installing specific tools or packages (e.g., `install-fish.sh`, `install-vscode.sh`).
- `packages/install-rclone.sh`: Downloads the latest rclone Linux release directly from GitHub Releases, verifies `SHA256SUMS`, installs to `~/.local/share/rclone`, and symlinks `~/.local/bin/rclone`.
- `packages/uninstall-rclone.sh`: Removes the release-based rclone install.
- `scripts/rclone-photos-backup.sh`: Copies `/mnt/Nebula/gdrive/photos` to `gdrive:photos` without deleting Google Drive files.
- `services/rclone-photos-backup.{service,timer}`: User systemd service/timer for nightly rclone photos backup.
- `install-cursor-cli.sh`: Installs Cursor CLI using the official installer from `https://cursor.com/install`.
- `install-pi-coding-agent.sh`: Downloads the latest Pi Coding Agent Linux release directly from GitHub Releases, verifies `SHA256SUMS`, installs to `~/.local/share/pi-coding-agent`, and symlinks `~/.local/bin/pi`.
- `uninstall-pi-coding-agent.sh`: Removes the release-based Pi install.
- `install-cursor.sh`: Parses `https://cursor.com/download` to find the latest Cursor Linux AppImage URL, follows Cursor's redirect to the current release asset, and installs it locally as `~/.local/share/cursor/Cursor.AppImage`.
- `uninstall-cursor.sh`: Removes the locally installed Cursor AppImage, launcher, desktop file, and icon.
- `install-opencode-desktop.sh`: Downloads the latest Opencode Desktop AppImage directly from GitHub Releases to avoid the current `opencode-bin` vs `opencode-desktop-bin` AUR package conflict.
- `install-gram.sh`: Downloads the latest Gram Linux tarball directly from Codeberg Releases and installs it locally as `~/.local/share/gram/gram.app`.
- `install-zennotes.sh`: Downloads the latest ZenNotes Linux AppImage directly from GitHub Releases, extracts it once to avoid slow AppImage/FUSE startup, and installs it locally as `~/.local/share/zennotes/app`.
- `install-synara.sh`: Downloads the latest Synara Linux AppImage directly from GitHub Releases, extracts it once to avoid slow AppImage/FUSE startup, and installs it locally as `~/.local/share/synara/app`.
- `install-zed-preview.sh`: Downloads the latest Zed Preview release directly from GitHub Releases and installs it side-by-side with stable Zed as `zed-preview`.
- `uninstall-zed.sh`: Removes the locally installed stable Zed app, launcher, desktop file, and icon.
- `uninstall-zed-preview.sh`: Removes the locally installed Zed Preview app, launcher, desktop file, and icon.
- `install-t3-code.sh`: Downloads the latest T3 Code AppImage directly from GitHub Releases and can be rerun to update immediately (`--nightly` or `--channel nightly` installs the latest nightly build; default is stable).
- `uninstall-kimi-code.sh`: Removes the `kimi-cli` tool installed via `uv`, with a manual fallback if `uv` is no longer present.
- `uninstall-opencode-desktop.sh`: Removes the locally installed Opencode Desktop AppImage, launcher, desktop file, and icon.
- `uninstall-gram.sh`: Removes the locally installed Gram app, launcher, desktop file, and icons.
- `uninstall-zennotes.sh`: Removes the locally installed ZenNotes app, launcher, desktop file, and icon.
- `uninstall-synara.sh`: Removes the locally installed Synara app, launcher, desktop file, and icon.
- `uninstall-t3-code.sh`: Removes the locally installed T3 Code AppImage, launcher, desktop file, and icon.
- `symlink-*.sh`: Scripts for linking configuration files that require special handling (VS Code).
- `change-shell.sh`: Sets `fish` as the default user shell.
- `remove-orphans.sh`: Cleans up unused dependencies using `pacman -Qtdq`.
