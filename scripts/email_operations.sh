#!/bin/bash
# email_operations.sh - Comprehensive email archive operations using docker-compose
# Usage: ./email_operations.sh [operation] [--dry-run]
# Operations: sync, backup, prune, all

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
    echo "  sync     - Sync emails from IMAP server and index with notmuch"
    echo "  backup   - Backup local maildir to Backblaze B2"
    echo "  prune    - Prune old emails from IMAP server"
    echo "  all      - Run all operations (sync, backup, prune)"
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
        sync|backup|prune|all)
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

# Function to run sync operation
run_sync() {
    echo "$(date): Starting email sync operation..."
    
    # Generate mbsync config with actual credentials
    mkdir -p data/maildir
    
    # Initialize Maildir structure to prevent assertion error
    mkdir -p data/maildir/INBOX/{cur,new,tmp}
    
    sed -e "s/__EMAIL_USER__/$EMAIL_USER/g" \
        -e "s/__EMAIL_PASS__/$EMAIL_PASS/g" \
        -e "s/__IMAP_HOST__/$IMAP_HOST/g" \
        -e "s/__IMAP_PORT__/$IMAP_PORT/g" \
        -e "s/__SYNC_FOLDERS__/$SYNC_FOLDERS/g" \
        config/mbsyncrc > data/maildir/.mbsyncrc
    
    # Run mbsync with dry run support
    DRY_RUN="$DRY_RUN_ENV" docker compose run --rm mbsync
    
    if [[ "$DRY_RUN_ENV" != "true" ]]; then
        echo "$(date): Sync complete. Indexing with notmuch..."
        docker compose exec notmuch-web notmuch new
        echo "$(date): Indexing complete."
    else
        echo "$(date): Dry run complete. No indexing performed in dry run mode."
    fi
}

# Function to run backup operation
run_backup() {
    echo "$(date): Starting backup operation..."
    DRY_RUN="$DRY_RUN_ENV" docker compose run --rm rclone
    echo "$(date): Backup operation complete."
}

# Function to run prune operation
run_prune() {
    echo "$(date): Starting prune operation..."
    
    # Calculate cutoff date
    DAYS=${PRUNE_DAYS:-365}
    CUTOFF_DATE=$(date -d "$DAYS days ago" '+%d-%b-%Y')
    echo "$(date): Pruning emails older than $CUTOFF_DATE (${DAYS} days)..."
    
    # Run prune with dry run support
    CUTOFF_DATE="$CUTOFF_DATE" DRY_RUN="$DRY_RUN_ENV" docker compose run --rm prune-imap
    echo "$(date): Prune operation complete."
}

# Execute the requested operation
case $OPERATION in
    sync)
        run_sync
        ;;
    backup)
        run_backup
        ;;
    prune)
        run_prune
        ;;
    all)
        echo "$(date): Running all email operations..."
        run_sync
        echo ""
        run_backup
        echo ""
        run_prune
        echo "$(date): All operations complete."
        ;;
esac