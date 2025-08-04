#!/bin/bash
# backup_to_b2.sh - Syncs local Maildir to Backblaze B2.
# Usage: ./backup_to_b2.sh [--dry-run]

set -e

# Parse command line arguments
DRY_RUN=""
RCLONE_FLAGS=""

# Check for environment variable first
if [ "${DRY_RUN:-false}" = "true" ]; then
    DRY_RUN="--dry-run"
    RCLONE_FLAGS="--dry-run"
    echo "Dry run mode enabled via environment variable"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="--dry-run"
            RCLONE_FLAGS="--dry-run"
            echo "Dry run mode enabled - no files will actually be uploaded"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run]"
            echo "  --dry-run: Show what would be backed up without actually uploading"
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

echo "$(date): Starting backup to Backblaze B2..."

# Run rclone to sync local archive tree to Backblaze B2
docker compose run --rm rclone sh -c "rclone sync /data/archive \"b2:${B2_BUCKET_NAME}/email-archive\" --fast-list $RCLONE_FLAGS"

echo "$(date): Backup complete." 