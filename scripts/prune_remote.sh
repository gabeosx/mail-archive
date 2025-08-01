#!/bin/bash
# prune_remote.sh - Deletes emails on Yahoo's server older than a year.

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

CUTOFF_DATE=$(date -d '365 days ago' '+%d-%b-%Y')
echo "$(date): Pruning emails on Yahoo server older than $CUTOFF_DATE..."

# Run imapsync to delete old emails from Yahoo
docker compose run --rm imapsync \
  --host1 imap.mail.yahoo.com --port1 993 --ssl1 \
  --user1 "$YAHOO_USER" --passfile1 <(echo "$YAHOO_PASS") \
  --search "BEFORE $CUTOFF_DATE" \
  --delete

echo "$(date): Pruning complete." 