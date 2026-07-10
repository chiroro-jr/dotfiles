# Omarchy Customization

Shell tooling for setting up and maintaining an Omarchy workstation.

## Layout

```text
packages/<package>/install.sh    Package-specific installation
packages/<package>/uninstall.sh  Package-specific removal, when supported
scripts/bootstrap.sh             Curated full setup sequence
scripts/verify.sh                Static verification; never runs installers
scripts/config/                  Dotfile, Hyprland, and editor configuration tasks
scripts/system/                  System-wide maintenance tasks
config/                          Configuration assets used by scripts
services/                        User systemd units
```

## Usage

Run the curated setup sequence:

```bash
./scripts/bootstrap.sh
```

Install or remove one package:

```bash
./packages/zed/install.sh
./packages/zed/uninstall.sh
```

## Safe verification

This validates Bash syntax, the package layout, and every path used by the bootstrap sequence. It does **not** invoke an installer, install packages, alter configuration, or call the network.

```bash
./scripts/verify.sh
# or
./scripts/bootstrap.sh --check
```

## Rclone Google Drive photos backup

Install rclone:

```bash
./packages/rclone/install.sh
```

Configure Google Drive once:

```bash
rclone config
```

Use remote name `gdrive`, storage `drive`, scope `drive`, and browser authentication. For backups, use `rclone copy`; it uploads new or changed files without deleting Drive files.

Manual backup:

```bash
cd /mnt/Nebula/gdrive/photos
rclone copy . gdrive:photos -P
```

Enable the nightly backup timer:

```bash
mkdir -p ~/.config/systemd/user
ln -sf ~/omarchy-customization/services/rclone-photos-backup.service ~/.config/systemd/user/
ln -sf ~/omarchy-customization/services/rclone-photos-backup.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now rclone-photos-backup.timer
```

Check it:

```bash
systemctl --user list-timers rclone-photos-backup.timer
systemctl --user status rclone-photos-backup.service
journalctl --user -u rclone-photos-backup.service -f
tail -f ~/.local/state/rclone/photos-backup.log
```
