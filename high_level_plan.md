# Email Archiving System

*Goal:* Periodically archive email from any IMAP server offline, prune old mail on the server, expose a browser-searchable archive, and back it up to Backblaze B2. All on your Ubuntu 24.04 Linux box via Docker, no full mail server.

## Prerequisites

* Ubuntu 24.04 server with sudo access.
* Docker & Docker Compose installed.
* Email account with IMAP access and app-specific password.
* Backblaze B2 account: Account ID, Application Key (read/write), and target bucket name.

---

## Directory layout (assumed root path)

```text
/srv/docker-data/email-archive/
├── data/
│   ├── maildir/             # local Maildir archive
│   └── notmuch/             # notmuch index (ephemeral; can be rebuilt)
├── scripts/                 # sync/prune/backup scripts
├── .env                    # credentials
└── docker-compose.yml
```

Ensure ownership/permissions restrict access to credentials (e.g., `.env` chmod 600).

---

## 1. Environment file (`.env`)

Populate `/srv/docker-data/email-archive/.env` with:

```ini
# Email Provider Credentials
EMAIL_USER=your-email@example.com
EMAIL_PASS=your-email-password-or-app-password

# IMAP Server Configuration
IMAP_HOST=imap.example.com
IMAP_PORT=993

# Backblaze B2 Credentials
B2_ACCOUNT_ID=your_b2_account_id
B2_APPLICATION_KEY=your_b2_application_key
B2_BUCKET_NAME=your-b2-bucket-name

# Web UI auth
WEB_USER=admin
WEB_PASSWORD=choose-a-strong-password

# Email pruning configuration
PRUNE_DAYS=365
```

---

## 2. `docker-compose.yml`

Place this at `/srv/docker-data/email-archive/docker-compose.yml`:

```yaml
version: '3.8'

services:
  ##########################################################
  # SERVICE 1: MBSYNC (for Syncing emails from IMAP to Maildir)
  ##########################################################
  mbsync:
    image: alpine:latest
    env_file: .env
    volumes:
      - ./data/maildir:/maildir
      - ./config/mbsyncrc:/maildir/.mbsyncrc:ro
    working_dir: /maildir
    command: sh -c "apk add --no-cache isync && mbsync -a"

  ##########################################################
  # SERVICE 2: NOTMUCH WEB (for Viewing and Searching)
  ##########################################################
  notmuch-web:
    image: anarcat/notmuch-web
    restart: unless-stopped
    ports:
      - "8090:8000"
    env_file: .env
    environment:
      - NOTMUCH_WEB_USER=${WEB_USER}
      - NOTMUCH_WEB_PASSWORD=${WEB_PASSWORD}
    volumes:
      - ./data/maildir:/home/user/mail:ro
      - ./data/notmuch:/home/user/.notmuch
    command: >
      sh -c "notmuch setup && notmuch-web --host=0.0.0.0"

  ##########################################################
  # SERVICE 3: RCLONE (for Off-site Backups)
  ##########################################################
  rclone:
    image: rclone/rclone:latest
    env_file: .env
    environment:
      - RCLONE_CONFIG_B2_TYPE=b2
      - RCLONE_CONFIG_B2_ACCOUNT=${B2_ACCOUNT_ID}
      - RCLONE_CONFIG_B2_KEY=${B2_APPLICATION_KEY}
    volumes:
      - ./data/maildir:/data/maildir:ro
```

---

## 3. Task scripts

Create the following executable scripts under `scripts/` (e.g., `/srv/docker-data/email-archive/scripts/`).

### a. `sync_and_index.sh`

```bash
#!/bin/bash
# sync_and_index.sh - Syncs email from IMAP server to local Maildir and triggers notmuch indexing.

cd /srv/docker-data/email-archive || exit

echo "$(date): Starting email sync from IMAP server..."
docker compose run --rm mbsync \
  -c /maildir/.mbsyncrc \
  email-channel

echo "$(date): Sync complete. Indexing with notmuch..."
docker compose exec notmuch-web notmuch new

echo "$(date): Indexing complete."
```

### b. `prune_remote.sh`

```bash
#!/bin/bash
# prune_remote.sh - Deletes emails on IMAP server older than configured days (PRUNE_DAYS).

cd /srv/docker-data/email-archive || exit

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
  python:3.11-alpine \
  python /scripts/prune_imap.py

echo "$(date): Pruning complete."
```

### c. `backup_to_b2.sh`

```bash
#!/bin/bash
# backup_to_b2.sh - Syncs local Maildir to Backblaze B2.

cd /srv/docker-data/email-archive || exit

echo "$(date): Starting backup to Backblaze B2..."
docker compose run --rm rclone sync /data/maildir "b2:${B2_BUCKET_NAME}/email-archive" --fast-list

echo "$(date): Backup complete."
```

Make them executable:

```bash
chmod +x scripts/*.sh
```

---

## 4. Initial steps to get the system running

1. **Start the web viewer** so the archive UI is live:

```bash
cd /srv/docker-data/email-archive
docker compose up -d notmuch-web
```

Access at `http://<server-ip>:8090` (will be empty until you sync).

2. **Manually trigger a dry run / initial sync** by running:

```bash
./scripts/sync_and_index.sh
```

3. **Run backup and prune manually** to validate behavior:

```bash
./scripts/backup_to_b2.sh
./scripts/prune_remote.sh
```

Verify:

* Mail appears in Notmuch web UI (index is rebuilt live; ephemeral index is acceptable).
* Backup directory shows up in Backblaze B2.
* Pruning behaves as expected before relying on it (you decide when to un-comment real runs).

---

## 5. Cron entries (commented out until dry-run/proof)

Add these to whatever scheduling mechanism you use—but **keep them commented out** until someone has manually executed and verified all three scripts:

```crontab
# Sync from IMAP server and index (weekly, adjust as desired)
# 0 3 * * 0 /srv/docker-data/email-archive/scripts/sync_and_index.sh >> /var/log/email_archive_sync.log 2>&1

# Backup the local archive to Backblaze B2 (weekly)
# 0 4 * * 0 /srv/docker-data/email-archive/scripts/backup_to_b2.sh >> /var/log/email_archive_backup.log 2>&1

# Prune old emails from IMAP server (weekly)
# 0 5 * * 0 /srv/docker-data/email-archive/scripts/prune_remote.sh >> /var/log/email_archive_prune.log 2>&1
```

**Manual verification step required before uncommenting.** The expectation: run each script once, inspect logs/output, then enable the corresponding cron line.

---

## 6. Verification / Operational notes

* **Web UI logs:** Monitor `notmuch-web` with `docker compose logs -f notmuch-web` to ensure it’s up and indexing proceeds.
* **Archive search:** The Notmuch index is ephemeral; if lost, running `notmuch new` in the container will rebuild it from the Maildir.
* **Backup check:** Use your Backblaze B2 console or `rclone ls b2:...` to confirm the Maildir content is present.
* **Prune caution:** Only enable pruning after you are certain the sync is working and you’ve reviewed what gets deleted.

---

## 7. Updating

To refresh images and keep the web UI current:

```bash
cd /srv/docker-data/email-archive
docker compose pull
docker compose up -d notmuch-web
```