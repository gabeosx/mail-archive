# Mail Archive (mbsync → imapfilter → rclone + Dovecot/Roundcube)

A Docker-based email archiving system that:

- Syncs emails from an IMAP server to a local Maildir using mbsync
- Serves a read-only IMAP archive via Dovecot and web UI via Roundcube
- Optionally prunes old mail on the remote server using imapfilter
- Backs up the archive to Backblaze B2 using rclone

## Features

- **Email Sync (mbsync)**: One-way IMAP pull to local Maildir
- **Read-only IMAP + UI**: Dovecot backend, Roundcube frontend on port 8080
- **Pruning (imapfilter)**: Deletes old mail on remote server after sync
- **Backup (rclone)**: Syncs archive to B2 (or S3-compatible)
- **Docker-based**: Easy deployment and management

## Prerequisites

- Ubuntu 24.04 server (or any Linux with Docker support)
- Docker & Docker Compose installed
- Email account with IMAP access and app-specific password
- Backblaze B2 account with:
  - Account ID
  - Application Key (read/write permissions)
  - Target bucket name

## Quick Start

1. **Clone this repository**:
   ```bash
   git clone <your-repo-url>
   cd mail-archive
   ```

2. **Configure your credentials**:
   ```bash
   cp env.example .env
   # Edit .env with your actual credentials
   ```

3. **Prepare host paths (once, on the host):**
   ```bash
   sudo mkdir -p \
     /srv/docker-data/mail/archive \
     /srv/docker-data/mail/dovecot/{index,control} \
     /srv/docker-data/mail/state/mbsync \
     /srv/docker-data/mail/roundcube/db \
     /srv/docker-data/mail/config/{dovecot,mbsync,roundcube,imapfilter,rclone} \
     /srv/docker-data/mail/secrets
   ```

4. **Place configs and secrets (on the host):**
   - Dovecot config in `/srv/docker-data/mail/config/dovecot/` (must define `mail_location` pointing at `/srv/mail/archive`)
   - Roundcube config (optional) in `/srv/docker-data/mail/config/roundcube/`
   - `/srv/docker-data/mail/secrets/yahoo_app_password`
   - `/srv/docker-data/mail/secrets/rclone.conf` (optional; or use env)

5. **Start Dovecot and Roundcube UI**:
   ```bash
   docker compose up -d dovecot roundcube
   ```

6. **Test all operations (recommended)**:
   ```bash
   ./scripts/email_operations.sh all --dry-run
   ```

7. **Run initial sync**:
   ```bash
   ./scripts/email_operations.sh sync
   ```

8. **Access the Roundcube UI** at `http://your-server-ip:8080`

9. **Run regular operations** (filter then backup):
   ```bash
   ./scripts/email_operations.sh filter --dry-run
   ./scripts/email_operations.sh filter
   ./scripts/email_operations.sh backup
   ```

## ⚠️ IMPORTANT: Testing Strategy for Valuable Email Archives

**If you have decades of valuable email, DO NOT skip this section!**

This system includes powerful pruning capabilities that can **permanently delete emails from your IMAP server**. While the system has excellent safety features, you must test methodically to ensure it works correctly with your specific email provider and configuration.

### 🛡️ Safety-First Approach

**NEVER run operations on your full email archive without testing first.** Follow this phased approach:

**Note**: All verification commands use Docker containers to match the exact execution environment of the actual operations, ensuring consistency between testing and production runs.

1. **Phase 1**: Test with limited scope (single folder)
2. **Phase 2**: Expand to full archive (sync + backup only)
3. **Phase 3**: Verify backup completeness and recovery
4. **Phase 4**: Test pruning with conservative settings (optional)

### Phase 1: Limited Scope Testing

**Goal**: Verify basic functionality with minimal risk.

**Configuration**:
```ini
# In your .env file
SYNC_FOLDERS=INBOX          # Only sync INBOX folder
PRUNE_DAYS=30              # Conservative pruning (if testing prune later)
DRY_RUN=false              # Will use --dry-run flags instead
```

**Steps**:
1. **Test sync with dry-run**:
   ```bash
   ./scripts/email_operations.sh sync --dry-run
   ```
   
2. **Verify dry-run output**:
   - Check that IMAP connection succeeds
   - Verify folder paths look correct
   - Confirm email count estimates are reasonable
   - Note any error messages

3. **Run actual sync** (if dry-run looks good):
   ```bash
   ./scripts/email_operations.sh sync
   ```

4. **Verify sync results**:
   ```bash
    # Check local Maildir structure using Docker (same environment as sync)
    docker run --rm -v "/srv/docker-data/mail/archive:/maildir" alpine:latest ls -la /maildir/
    docker run --rm -v "/srv/docker-data/mail/archive:/maildir" alpine:latest ls -la /maildir/INBOX/cur/
   
   # Count emails in local archive using Docker
    docker run --rm -v "/srv/docker-data/mail/archive:/maildir" alpine:latest \
     sh -c "find /maildir/INBOX -name '*.eml' -o -name '*:2,*' | wc -l"
   ```

5. **Test web interface**:
   - Access `http://your-server:8080`
   - Verify emails appear correctly
   - Test search functionality
   - Check email content displays properly

6. **Test backup**:
   ```bash
   # Test backup with dry-run
   ./scripts/email_operations.sh backup --dry-run
   
   # Run actual backup (if dry-run looks good)
   ./scripts/email_operations.sh backup
   ```

**Verification Checklist**:
- [ ] IMAP connection successful
- [ ] Local Maildir created with correct structure
- [ ] Email count matches expectations
- [ ] Web interface shows emails correctly
- [ ] Backup uploaded to B2 successfully
- [ ] No error messages in any operation

### Phase 2: Full Archive Sync

**Goal**: Download your complete email archive safely.

**Configuration**:
```ini
# In your .env file  
SYNC_FOLDERS=*             # All folders
PRUNE_DAYS=365             # Still conservative
```

**Steps**:
1. **Test full sync with dry-run**:
   ```bash
   ./scripts/email_operations.sh sync --dry-run
   ```

2. **Verify folder discovery**:
   - Check that all expected folders are listed
   - Verify folder names match your email provider's structure
   - Look for any permission errors

3. **Run full sync** (will take significant time for decades of email):
   ```bash
   ./scripts/email_operations.sh sync
   ```

4. **Monitor progress**:
   ```bash
   # Watch sync progress
   docker compose logs -f mbsync
   
   # Check growing maildir size using Docker
    docker run --rm -v "/srv/docker-data/mail/archive:/maildir" alpine:latest du -sh /maildir/
   ```

5. **Verify complete archive**:
   ```bash
    # Check all folders were created using Docker (same environment as operations)
    docker run --rm -v "/srv/docker-data/mail/archive:/maildir" alpine:latest ls -la /maildir/
   
   # Count total emails using Docker
    docker run --rm -v "/srv/docker-data/mail/archive:/maildir" alpine:latest \
     sh -c "find /maildir -name '*.eml' -o -name '*:2,*' | wc -l"
   
   # Check largest folders using Docker
    docker run --rm -v "/srv/docker-data/mail/archive:/maildir" alpine:latest \
     sh -c "du -sh /maildir/*/ | sort -hr"
   ```

6. **Test web interface with full archive**:
   - Verify search works across all folders
   - Test date-based searches
   - Check various email formats display correctly

**Verification Checklist**:
- [ ] All expected folders downloaded
- [ ] Total email count reasonable for your archive
- [ ] No missing or corrupted folders
- [ ] Web search works across all emails
- [ ] Large attachments handled correctly

### Phase 3: Backup Verification & Recovery Testing

**Goal**: Ensure you can recover your archive if needed.

**Steps**:
1. **Complete backup**:
   ```bash
   ./scripts/email_operations.sh backup
   ```

2. **Verify B2 backup contents using Docker (same environment as backup)**:
   ```bash
   # Source environment variables first
   source .env
   
    # Check backup contents using the same rclone container
    docker compose run --rm rclone ls "B2:${B2_BUCKET_NAME}/email-archive/" | head -20
    
    # Check total backup size using Docker rclone
    docker compose run --rm rclone size "B2:${B2_BUCKET_NAME}/email-archive/"
   ```

3. **Test recovery procedure using Docker**:
   ```bash
   # Source environment variables first
   source .env
   
   # Create test recovery area
   mkdir test-recovery
   
    # Download a sample folder from backup using Docker rclone (same as operations)
   docker run --rm \
     -v "$(pwd)/test-recovery:/data" \
     -e RCLONE_CONFIG_B2_TYPE=b2 \
     -e RCLONE_CONFIG_B2_ACCOUNT="${B2_ACCOUNT_ID}" \
     -e RCLONE_CONFIG_B2_KEY="${B2_APPLICATION_KEY}" \
     rclone/rclone:latest \
      copy "B2:${B2_BUCKET_NAME}/email-archive/INBOX" /data/INBOX/ --max-transfer 100M
   
   # Verify emails are intact using Docker
   docker run --rm -v "$(pwd)/test-recovery:/data" alpine:latest ls -la /data/INBOX/cur/ | head -10
   ```

4. **Document your recovery process**:
   - Note B2 bucket path
   - Record rclone commands that work
   - Test full recovery procedure if possible

**Verification Checklist**:
- [ ] Backup exists in B2 with expected size
- [ ] Can download sample emails from backup
- [ ] Backup folder structure matches local archive
- [ ] Recovery procedure documented and tested

### Phase 4: Conservative Pruning Testing (Optional)

**⚠️ DANGER ZONE: This phase permanently deletes emails from your server.**

**Only proceed if**:
- Phases 1-3 completed successfully
- Local archive is complete and verified
- Backup is confirmed and tested
- You understand pruning consequences

**Configuration for initial pruning test**:
```ini
# Start VERY conservative
PRUNE_DAYS=30              # Only delete emails older than 30 days
SYNC_FOLDERS=INBOX         # Test on single folder first
```

**Steps**:
1. **Test pruning with dry-run**:
   ```bash
    ./scripts/email_operations.sh filter --dry-run
   ```

2. **Carefully review dry-run output**:
   - Note exactly how many emails would be deleted
   - Verify the cutoff date is correct
   - Confirm you're comfortable losing these emails from the server

3. **If comfortable, run conservative pruning**:
   ```bash
    ./scripts/email_operations.sh filter
   ```

4. **Verify pruning results**:
   - Check your email client/webmail to confirm old emails are gone
   - Verify emails still exist in local archive
   - Confirm recent emails remain on server

5. **Gradually expand scope** (only after success):
   ```ini
   # After INBOX success, expand gradually
   SYNC_FOLDERS=INBOX "Sent"
   # Later: SYNC_FOLDERS=*
   
   # After 30-day success, consider longer periods
   PRUNE_DAYS=90
   # Later: PRUNE_DAYS=365 or higher
   ```

**Verification Checklist**:
- [ ] Dry-run output reviewed and approved
- [ ] Correct number of emails deleted from server
- [ ] Deleted emails still exist in local archive
- [ ] Recent emails remain on server
- [ ] Ready to expand scope gradually

### 🚨 Critical Safety Reminders

1. **Always use `--dry-run` first** for any new operation or configuration change
2. **Verify backups exist** before running any pruning operations
3. **Start conservative** with short retention periods and limited folder scope
4. **Test incrementally** - don't jump from INBOX to all folders immediately
5. **Document what works** - note successful configurations for future reference
6. **Monitor logs** - watch for errors or unexpected behavior

### Emergency Recovery

If something goes wrong:

1. **Stop all operations immediately**
2. **Check your local archive using Docker** (same environment as operations):
   ```bash
   docker run --rm -v "$(pwd)/data/maildir:/maildir" alpine:latest ls -la /maildir/
   ```
3. **Restore from B2 backup using Docker** (same environment as backup operations):
   ```bash
   # Source environment variables first
   source .env
   
    # Use the same rclone container as backup operations
    docker compose run --rm rclone sync "B2:${B2_BUCKET_NAME}/email-archive/" /data/maildir/
   ```
4. Inspect Roundcube logs and reload the page. Indexing is handled by Dovecot/IMAP, no manual rebuild needed.

## Configuration

### Environment Variables

Copy `env.example` to `.env` and configure:

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

# Roundcube Web UI auth (optional; may configure through UI)
WEB_USER=
WEB_PASSWORD=

# Email synchronization and pruning configuration
PRUNE_DAYS=365

# Folder patterns to sync and prune (applies to both sync and prune operations)
# Use "*" for all folders, or specify folders separated by spaces
# Examples:
#   SYNC_FOLDERS=*                           # All folders
#   SYNC_FOLDERS=INBOX "Sent" "Drafts"       # Specific folders only
#   SYNC_FOLDERS=INBOX "[Gmail]/Sent Mail"   # Gmail-style folders
SYNC_FOLDERS=*

# Dry run mode - set to "true" to enable dry run for mbsync/imapfilter/rclone
DRY_RUN=false
```

### Email Provider Setup

You'll need to configure your email provider for IMAP access:

**For Gmail:**
- Enable 2-factor authentication
- Generate an app-specific password
- Use `imap.gmail.com` for IMAP_HOST and `993` for IMAP_PORT

**For Yahoo:**
- Go to Yahoo Account Security
- Enable 2-factor authentication
- Generate an app-specific password
- Use `imap.mail.yahoo.com` for IMAP_HOST and `993` for IMAP_PORT

**For Outlook/Hotmail:**
- Enable 2-factor authentication
- Generate an app-specific password
- Use `outlook.office365.com` for IMAP_HOST and `993` for IMAP_PORT

**For other providers:**
- Check your email provider's documentation for IMAP settings
- Ensure IMAP is enabled in your account settings
- Use app-specific passwords when available for better security

## Provider-Specific Configuration Examples

### Gmail Configuration
```ini
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-gmail-app-password
IMAP_HOST=imap.gmail.com
IMAP_PORT=993
```

### Yahoo Configuration
```ini
EMAIL_USER=your-email@yahoo.com
EMAIL_PASS=your-yahoo-app-password
IMAP_HOST=imap.mail.yahoo.com
IMAP_PORT=993
```

### Outlook/Hotmail Configuration
```ini
EMAIL_USER=your-email@outlook.com
EMAIL_PASS=your-outlook-app-password
IMAP_HOST=outlook.office365.com
IMAP_PORT=993
```

### Custom IMAP Server Configuration
```ini
EMAIL_USER=your-email@yourdomain.com
EMAIL_PASS=your-password
IMAP_HOST=imap.yourdomain.com
IMAP_PORT=993
```

### Backblaze B2 Setup

1. Create a Backblaze B2 account
2. Create a bucket for email archives
3. Create an application key with read/write permissions
4. Note your Account ID and Application Key

### Email Synchronization and Pruning Configuration

- `PRUNE_DAYS`: Number of days to keep emails on the IMAP server (default: 365)
  - Emails older than this will be deleted from the server during pruning
  - Set to a higher number to keep emails longer
  - Common values:
    - `30` = 1 month
    - `90` = 3 months  
    - `365` = 1 year (default)
    - `730` = 2 years
    - `1095` = 3 years
  - **Note**: Date calculations use GNU date format (Linux containers)

- `SYNC_FOLDERS`: Folder patterns to sync and prune (default: `*`)
  - `*` = All folders (recommended for most users)
  - Specific folders: `INBOX "Sent" "Drafts"`
  - Gmail example: `INBOX "[Gmail]/Sent Mail" "[Gmail]/All Mail"`
  - Yahoo example: `INBOX "Sent" "Draft" "Bulk Mail"`
  - **Note**: Both sync and prune operations use the same folder configuration

## Usage

### Testing with Dry Run Mode

**⚠️ IMPORTANT: Always test with dry run mode first!**

All scripts support dry run mode to safely test functionality without making permanent changes. **All dry run operations use the same Docker containers and environment as actual operations**, ensuring test results accurately predict production behavior:

- **`--dry-run`**: Shows what would happen without actually performing the operation
- **Recommended workflow**: Run with `--dry-run` first, then run without it if the output looks correct

**Example testing workflow**:
```bash
# Option 1: Test individual operations with scripts
./scripts/sync_and_index.sh --dry-run
./scripts/backup_to_b2.sh --dry-run
./scripts/prune_remote.sh --dry-run

# Option 2: Test using the comprehensive docker-compose approach
./scripts/email_operations.sh sync --dry-run
./scripts/email_operations.sh backup --dry-run
./scripts/email_operations.sh filter --dry-run

# Option 3: Test all operations at once
./scripts/email_operations.sh all --dry-run

# Option 4: Set environment variable for dry run mode (temporarily)
export DRY_RUN=true
./scripts/email_operations.sh all
# Variable is only set for current shell session
```

### Docker-Compose Operations (Recommended)

**Comprehensive email operations using docker-compose**:

```bash
# Run all operations (sync, filter, backup)
./scripts/email_operations.sh all

# Test all operations with dry run
./scripts/email_operations.sh all --dry-run

# Run individual operations
./scripts/email_operations.sh sync
./scripts/email_operations.sh backup
./scripts/email_operations.sh filter

# Test individual operations
./scripts/email_operations.sh sync --dry-run
./scripts/email_operations.sh backup --dry-run
./scripts/email_operations.sh filter --dry-run
```

**Direct docker-compose commands**:
```bash
# Set dry run mode in environment (optional)
export DRY_RUN=true

# Run individual services
docker compose run --rm mbsync
docker compose run --rm rclone
docker compose run --rm imapfilter
```

### Manual Operations (Individual Scripts)

**Sync emails from IMAP server**:
```bash
./scripts/sync_and_index.sh
# Dry run (show what would be synced without actually syncing):
./scripts/sync_and_index.sh --dry-run
```

**Backup to Backblaze B2**:
```bash
./scripts/backup_to_b2.sh
# Dry run (show what would be backed up without actually uploading):
./scripts/backup_to_b2.sh --dry-run
```

**Prune old emails from IMAP server**:
```bash
./scripts/prune_remote.sh
# Dry run (show what would be deleted without actually deleting):
./scripts/prune_remote.sh --dry-run
```

### Automated Scheduling

**Important**: Test all operations with `--dry-run` first, then run them manually to verify they work correctly before adding to cron.

Add to your crontab (after manual verification):

```crontab
# Option 1: Run all operations at once (recommended)
0 3 * * 0 /path/to/email-archive/scripts/email_operations.sh all >> /var/log/email_archive.log 2>&1

# Option 2: Run operations separately (traditional approach)
# Sync from IMAP server and index (weekly)
0 3 * * 0 /path/to/email-archive/scripts/sync_and_index.sh >> /var/log/email_archive_sync.log 2>&1

# Backup to Backblaze B2 (weekly)
0 4 * * 0 /path/to/email-archive/scripts/backup_to_b2.sh >> /var/log/email_archive_backup.log 2>&1

# Prune old emails from IMAP server (weekly)
0 5 * * 0 /path/to/email-archive/scripts/prune_remote.sh >> /var/log/email_archive_prune.log 2>&1
```

## Directory Structure

```
email-archive/
├── config/
│   └── mbsyncrc            # mbsync configuration
├── data/
│   └── maildir/            # Local Maildir archive
├── scripts/
│   ├── email_operations.sh # Comprehensive operations (recommended)
│   ├── sync_and_index.sh   # Sync and index emails
│   ├── prune_remote.sh     # Prune old emails
│   ├── prune_imap.py       # Python IMAP pruning script
│   └── backup_to_b2.sh     # Backup to B2
├── docker-compose.yml      # Docker services
├── env.example             # Environment template
├── .env                    # Your credentials (not in git)
└── README.md              # This file
```

## Services

### 1. MBSYNC
- Downloads emails from IMAP server to local Maildir format
- Uses the `isync` package in Alpine Linux
- Configured via `config/mbsyncrc`

### 2. Roundcube Web
- Provides web interface for browsing emails via Dovecot
- Runs on port 8080
- Uses the `roundcube/roundcubemail` Docker image

### 3. Rclone
- Handles backup to Backblaze B2
- Uses the `rclone/rclone` Docker image

### 4. Python IMAP Pruning
- Removes old emails from IMAP server (configurable days)
- Uses Python's built-in `imaplib` library
- Runs in a lightweight Python Alpine container

## Security Notes

- Keep your `.env` file secure (chmod 600)
- Use strong passwords for the web interface
- Consider using a reverse proxy with SSL for production
- Regularly update Docker images

## Troubleshooting

### Common Issues

**Web interface not accessible**:
```bash
docker compose logs roundcube
```

**Sync fails**:
- Verify email provider credentials
- Check if app password is correct
- Ensure 2FA is enabled on your email account
- Verify IMAP server settings (host and port)

**Backup fails**:
- Verify B2 credentials
- Check bucket permissions
- Ensure application key has write access

**Permission errors**:
```bash
chmod +x scripts/*.sh
chmod 600 .env
```

### Logs

View service logs:
```bash
docker compose logs -f [service-name]
```

 

## Updating

To update the system:

```bash
git pull
docker compose pull
docker compose up -d roundcube dovecot
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source. Please check the license file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the logs
3. Open an issue on the repository 