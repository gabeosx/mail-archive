#!/bin/bash
# backup_to_b2.sh - Syncs local Maildir to Backblaze B2.

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR" || exit 1

# Load environment variables
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please copy env.example to .env and configure your credentials."
    exit 1
fi

source .env

echo "$(date): Starting backup to Backblaze B2..."

# Run rclone to sync local Maildir to Backblaze B2
docker compose run --rm rclone sync /data/maildir "b2:${B2_BUCKET_NAME}/email-archive" --fast-list

echo "$(date): Backup complete." 