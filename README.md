# Omarchy Workstation

One repository for this machine's user configuration and provisioning scripts.

## Layout

```text
stow/                  GNU Stow source packages for home-directory configuration
packages/<name>/       Per-package install.sh and optional uninstall.sh
scripts/bootstrap.sh   Curated workstation setup sequence
scripts/verify.sh      Static verification; never runs installers
scripts/config/        Dotfile, Hyprland, and editor configuration tasks
scripts/system/        System maintenance tasks
config/                Configuration assets used by scripts
services/              User systemd units
```

## Setup

Run the curated setup sequence:

```bash
./scripts/bootstrap.sh
```

Install one package:

```bash
./packages/zed/install.sh
```

Apply only the Stow-managed configuration:

```bash
./scripts/config/install-dotfiles.sh
```

VS Code settings are linked separately:

```bash
./scripts/config/symlink-vscode.sh
```

## Safe verification

Static verification checks shell syntax, repository layout, Stow package presence, and every bootstrap path. It does not invoke installers, modify configuration, install packages, or call the network.

```bash
./scripts/verify.sh
# or
./scripts/bootstrap.sh --check
```

## Local secrets

Never commit API tokens, passwords, or private keys. Keep them in an ignored file outside this repository, then source that file conditionally from your local shell configuration.

## Rclone Google Drive photo backup

Install rclone:

```bash
./packages/rclone/install.sh
```

Configure the `gdrive` remote once:

```bash
rclone config
```

Enable the nightly timer:

```bash
mkdir -p ~/.config/systemd/user
ln -sf "$PWD/services/rclone-photos-backup.service" ~/.config/systemd/user/
ln -sf "$PWD/services/rclone-photos-backup.timer" ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now rclone-photos-backup.timer
```
