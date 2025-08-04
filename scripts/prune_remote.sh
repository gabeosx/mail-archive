#!/bin/bash
# prune_remote.sh - Runs imapfilter to delete old emails on remote IMAP.
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

# Use PRUNE_DAYS from .env file
if [ -z "$PRUNE_DAYS" ]; then
    echo "Error: PRUNE_DAYS not set in .env file"
    echo "Please set PRUNE_DAYS in your .env file (e.g., PRUNE_DAYS=365)"
    exit 1
fi
echo "$(date): Running imapfilter to prune emails older than ${PRUNE_DAYS} days..."

# Use docker compose service for imapfilter (config-driven; reads DRY_RUN env)
export DRY_RUN="$([ -n "$DRY_RUN" ] && echo true || echo false)"
docker compose run --rm imapfilter
unset DRY_RUN

echo "$(date): Pruning complete." 