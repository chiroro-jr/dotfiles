#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="/mnt/Nebula/gdrive/photos"
DEST_REMOTE="gdrive:photos"
LOG_DIR="$HOME/.local/state/rclone"
LOG_FILE="$LOG_DIR/photos-backup.log"
LOCK_FILE="/tmp/rclone-photos-backup.lock"

mkdir -p "$LOG_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "[ERROR] Source directory does not exist: $SOURCE_DIR" >&2
  exit 1
fi

cd "$SOURCE_DIR"

flock -n "$LOCK_FILE" \
  rclone copy . "$DEST_REMOTE" -P \
    --transfers 8 \
    --checkers 16 \
    --create-empty-src-dirs \
    --max-duration 6h \
    --log-file "$LOG_FILE" \
    --log-level INFO
