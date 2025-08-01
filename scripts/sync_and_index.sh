#!/bin/bash
# sync_and_index.sh - Syncs Yahoo mail and triggers notmuch indexing.

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

echo "$(date): Starting email sync from Yahoo..."

# Run imapsync to download emails from Yahoo
docker compose run --rm imapsync \
  --host1 imap.mail.yahoo.com --port1 993 --ssl1 \
  --user1 "$YAHOO_USER" --passfile1 <(echo "$YAHOO_PASS") \
  --host2 . --folder2 INBOX \
  --syncinternaldates --skipsize

echo "$(date): Sync complete. Indexing with notmuch..."

# Trigger notmuch indexing
docker compose exec notmuch-web notmuch new

echo "$(date): Indexing complete." 