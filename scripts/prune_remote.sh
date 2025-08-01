#!/bin/bash
# prune_remote.sh - Deletes emails on IMAP server older than configured days.
# Usage: ./prune_remote.sh [--dry-run]

set -e

# Parse command line arguments
DRY_RUN=""

# Check for environment variable first
if [ "${DRY_RUN:-false}" = "true" ]; then
    DRY_RUN="--dry-run"
    echo "Dry run mode enabled via environment variable"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="--dry-run"
            echo "Dry run mode enabled - no emails will actually be deleted"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run]"
            echo "  --dry-run: Show what would be deleted without actually deleting"
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

# Use PRUNE_DAYS from .env, default to 365 if not set
DAYS=${PRUNE_DAYS:-365}
CUTOFF_DATE=$(date -d "$DAYS days ago" '+%d-%b-%Y')
echo "$(date): Pruning emails on IMAP server older than $CUTOFF_DATE (${DAYS} days)..."

# Run Python script to delete old emails from IMAP server
docker run --rm -v "$(pwd)/scripts:/scripts" \
  -e EMAIL_USER="$EMAIL_USER" \
  -e EMAIL_PASS="$EMAIL_PASS" \
  -e IMAP_HOST="$IMAP_HOST" \
  -e IMAP_PORT="$IMAP_PORT" \
  -e CUTOFF_DATE="$CUTOFF_DATE" \
  -e PRUNE_DAYS="$DAYS" \
  -e SYNC_FOLDERS="$SYNC_FOLDERS" \
  python:3.11-alpine \
  python /scripts/prune_imap.py $DRY_RUN

echo "$(date): Pruning complete." 