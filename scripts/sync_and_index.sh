#!/bin/bash
# sync_and_index.sh - Syncs email from IMAP server (mbsync).
# Usage: ./sync_and_index.sh [--dry-run]

set -e

# Parse command line arguments
DRY_RUN_MODE="false"

# Check for environment variable first
if [ "${DRY_RUN:-false}" = "true" ]; then
    DRY_RUN_MODE="true"
    echo "Dry run mode enabled via environment variable"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN_MODE="true"
            echo "Dry run mode enabled - no emails will actually be synced"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run]"
            echo "  --dry-run: Show what would be synced without actually syncing"
            echo "  Can also be enabled by setting DRY_RUN=true in .env"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run]"
            exit 1
            ;;
    esac
done

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

echo "$(date): Starting email sync from IMAP server (mbsync)..."

HOST_MBSYNC_CONFIG_DIR="/srv/docker-data/mail/config/mbsync"
mkdir -p "$HOST_MBSYNC_CONFIG_DIR"
sed -e "s/__EMAIL_USER__/$EMAIL_USER/g" \
    -e "s/__IMAP_HOST__/$IMAP_HOST/g" \
    -e "s/__IMAP_PORT__/$IMAP_PORT/g" \
    -e "s/__SYNC_FOLDERS__/$SYNC_FOLDERS/g" \
    config/mbsyncrc > "$HOST_MBSYNC_CONFIG_DIR/mbsyncrc"

# Run mbsync to download emails from IMAP server to local Maildir
export DRY_RUN="$DRY_RUN_MODE"
docker compose run --rm mbsync
unset DRY_RUN

echo "$(date): Sync complete."