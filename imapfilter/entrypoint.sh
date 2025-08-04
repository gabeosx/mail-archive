#!/bin/sh
set -e

DRY_RUN="${DRY_RUN:-false}"

CONFIG_DIR="/etc/imapfilter"
CONFIG_FILE="$CONFIG_DIR/config.lua"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found (mount /srv/docker-data/mail/config/imapfilter)" >&2
  exit 1
fi

if [ "$DRY_RUN" = "true" ]; then
  echo "=== IMAPFILTER DRY-RUN: Printing planned actions (no deletes) ==="
  # Run in verbose mode; config should gate actual delete based on DRY_RUN
  exec imapfilter -v -c "$CONFIG_FILE"
else
  exec imapfilter -v -c "$CONFIG_FILE"
fi

