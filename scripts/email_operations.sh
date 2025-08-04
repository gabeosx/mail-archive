#!/bin/bash
# email_operations.sh - Comprehensive email archive operations using docker-compose
# Usage: ./email_operations.sh [operation] [--dry-run]
# Operations: sync, filter, backup, all

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [operation] [--dry-run]"
    echo ""
    echo "Operations:"
    echo "  sync     - Sync emails from IMAP server (mbsync)"
    echo "  filter   - Cleanup/prune on remote IMAP using imapfilter"
    echo "  backup   - Backup local archive to Backblaze B2 (rclone)"
    echo "  all      - Run sync → filter → backup"
    echo ""
    echo "Options:"
    echo "  --dry-run - Show what would happen without making changes"
    echo "  --help    - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 sync --dry-run        # Test sync operation"
    echo "  $0 backup                # Run backup operation"
    echo "  $0 all --dry-run         # Test all operations"
}

# Parse command line arguments
OPERATION=""
DRY_RUN_FLAG=""
DRY_RUN_ENV="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        sync|filter|backup|all)
            if [ -n "$OPERATION" ]; then
                echo "Error: Multiple operations specified. Please specify only one."
                show_usage
                exit 1
            fi
            OPERATION="$1"
            shift
            ;;
        --dry-run)
            DRY_RUN_FLAG="--dry-run"
            DRY_RUN_ENV="true"
            echo "Dry run mode enabled - no permanent changes will be made"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

if [ -z "$OPERATION" ]; then
    echo "Error: No operation specified."
    show_usage
    exit 1
fi

# Function to run sync operation (mbsync)
run_sync() {
    echo "$(date): Starting email sync operation..."
    
    # Prepare host config path for mbsync used by the container
    HOST_MBSYNC_CONFIG_DIR="/srv/docker-data/mail/config/mbsync"
    mkdir -p "$HOST_MBSYNC_CONFIG_DIR"

    # Generate mbsync config with actual credentials (password read from secret in container)
    sed -e "s/__EMAIL_USER__/$EMAIL_USER/g" \
        -e "s/__IMAP_HOST__/$IMAP_HOST/g" \
        -e "s/__IMAP_PORT__/$IMAP_PORT/g" \
        -e "s/__SYNC_FOLDERS__/$SYNC_FOLDERS/g" \
        config/mbsyncrc > "$HOST_MBSYNC_CONFIG_DIR/mbsyncrc"

    # Run mbsync with dry run support
    export DRY_RUN="$DRY_RUN_ENV"
    docker compose run --rm mbsync
    unset DRY_RUN
    echo "$(date): Sync complete."
}

# Function to run filter/prune operation (imapfilter)
run_filter() {
    echo "$(date): Starting imapfilter prune operation..."
    export DRY_RUN="$DRY_RUN_ENV"
    docker compose run --rm imapfilter
    unset DRY_RUN
    echo "$(date): imapfilter operation complete."
}

# Function to run backup operation (rclone)
run_backup() {
    echo "$(date): Starting backup operation..."
    export DRY_RUN="$DRY_RUN_ENV"
    docker compose run --rm rclone
    unset DRY_RUN
    echo "$(date): Backup operation complete."
}

# Execute the requested operation
case $OPERATION in
    sync)
        run_sync
        ;;
    filter)
        run_filter
        ;;
    backup)
        run_backup
        ;;
    all)
        echo "$(date): Running sync → filter → backup..."
        run_sync
        echo ""
        run_filter
        echo ""
        run_backup
        echo "$(date): All operations complete."
        ;;
esac