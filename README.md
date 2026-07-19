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

Install one package directly:

```bash
./packages/zed/install.sh
```

Or use the interactive package selectors:

```bash
./install.sh
./uninstall.sh
```

They list available packages and accept selections such as `1 2 4`, `2-5`, a mixed list such as `1 3-5 9`, `a` for all, or `q` to quit.

```bash
./install.sh --list
./install.sh --all --dry-run
./uninstall.sh --dry-run
```

`--dry-run` prints selected package scripts without running them.

Apply all Stow-managed configuration:

```bash
./scripts/config/install-dotfiles.sh
```

Stow links the selected application configs into `$HOME` without folding whole
runtime directories such as `~/.pi` or `~/.config/opencode` into the repository.
VS Code and VSCodium extension manifests live beside their package installers;
the installers restore the latest available version of each listed extension.

## Safe verification

Static verification checks shell syntax, repository layout, Stow package presence, and every bootstrap path. It does not invoke installers, modify configuration, install packages, or call the network.

```bash
./scripts/verify.sh
# or
./scripts/bootstrap.sh --check
```

## Local secrets

Never commit API tokens, passwords, or private keys. Fish secrets belong in
`~/.config/fish/conf.d/secrets.fish`, which is intentionally not managed by
Stow and is ignored if accidentally copied into this repository.

## 1Password-backed secrets

The scripts default to the `Personal` vault. Override it with `OP_VAULT`; item
names can be overridden with `OP_SHELL_SECRETS_ITEM` and
`OP_PROJECT_SECRETS_DOCUMENT`.

Create a 1Password item named `Workstation Shell Secrets` with password fields
named `OPENCODE_API_KEY`, `NEURALWATT_API_KEY`, and `GITHUB_TOKEN`, then generate
the ignored local Fish file:

```bash
./scripts/config/restore-shell-secrets.sh
```

Back up the complete local `~/.config/projects` directory as one 1Password
Document, creating it on the first run and updating it afterward:

```bash
./scripts/config/backup-project-secrets.sh
```

Restore that archive on a new machine. Any existing directory is moved to a
timestamped backup before extraction:

```bash
./scripts/config/restore-project-secrets.sh
```

Android signing keys should also have a second encrypted offline backup.

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
