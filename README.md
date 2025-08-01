# Email Archiving Cookbook

A Docker-based email archiving system that periodically syncs Yahoo mail offline, prunes old mail on the server, exposes a browser-searchable archive, and backs it up to Backblaze B2.

## Features

- **Email Sync**: Downloads emails from Yahoo using IMAP
- **Web Interface**: Browser-searchable archive using Notmuch Web
- **Automatic Pruning**: Removes old emails from Yahoo server (configurable)
- **Cloud Backup**: Automatic backup to Backblaze B2
- **Docker-based**: Easy deployment and management
- **Version Controlled**: Git repository for easy updates and customization

## Prerequisites

- Ubuntu 24.04 server (or any Linux with Docker support)
- Docker & Docker Compose installed
- Yahoo app-specific password generated
- Backblaze B2 account with:
  - Account ID
  - Application Key (read/write permissions)
  - Target bucket name

## Quick Start

1. **Clone this repository**:
   ```bash
   git clone <your-repo-url>
   cd email-archive
   ```

2. **Configure your credentials**:
   ```bash
   cp env.example .env
   # Edit .env with your actual credentials
   ```

3. **Start the web interface**:
   ```bash
   docker compose up -d notmuch-web
   ```

4. **Run initial sync**:
   ```bash
   ./scripts/sync_and_index.sh
   ```

5. **Access the web interface** at `http://your-server-ip:8090`

## Configuration

### Environment Variables

Copy `env.example` to `.env` and configure:

```ini
# Yahoo Credentials
YAHOO_USER=your-email@yahoo.com
YAHOO_PASS=your-yahoo-app-password

# Backblaze B2 Credentials
B2_ACCOUNT_ID=your_b2_account_id
B2_APPLICATION_KEY=your_b2_application_key
B2_BUCKET_NAME=your-b2-bucket-name

# Web UI auth
WEB_USER=admin
WEB_PASSWORD=choose-a-strong-password
```

### Yahoo App Password Setup

1. Go to Yahoo Account Security
2. Enable 2-factor authentication
3. Generate an app-specific password
4. Use this password in the `YAHOO_PASS` field

### Backblaze B2 Setup

1. Create a Backblaze B2 account
2. Create a bucket for email archives
3. Create an application key with read/write permissions
4. Note your Account ID and Application Key

## Usage

### Manual Operations

**Sync emails from Yahoo**:
```bash
./scripts/sync_and_index.sh
```

**Backup to Backblaze B2**:
```bash
./scripts/backup_to_b2.sh
```

**Prune old emails from Yahoo**:
```bash
./scripts/prune_remote.sh
```

### Automated Scheduling

Add to your crontab (after manual verification):

```crontab
# Sync from Yahoo and index (weekly)
0 3 * * 0 /path/to/email-archive/scripts/sync_and_index.sh >> /var/log/email_archive_sync.log 2>&1

# Backup to Backblaze B2 (weekly)
0 4 * * 0 /path/to/email-archive/scripts/backup_to_b2.sh >> /var/log/email_archive_backup.log 2>&1

# Prune old emails from Yahoo server (weekly)
0 5 * * 0 /path/to/email-archive/scripts/prune_remote.sh >> /var/log/email_archive_prune.log 2>&1
```

## Directory Structure

```
email-archive/
├── data/
│   ├── maildir/             # Local Maildir archive
│   └── notmuch/             # Notmuch index (ephemeral)
├── scripts/
│   ├── sync_and_index.sh    # Sync and index emails
│   ├── prune_remote.sh      # Prune old emails
│   └── backup_to_b2.sh      # Backup to B2
├── docker-compose.yml       # Docker services
├── env.example             # Environment template
├── .env                    # Your credentials (not in git)
└── README.md              # This file
```

## Services

### 1. IMAPSYNC
- Downloads emails from Yahoo
- Handles pruning of old emails
- Uses the `gkoerk/imapsync` Docker image

### 2. Notmuch Web
- Provides web interface for searching emails
- Runs on port 8090
- Uses the `anarcat/notmuch-web` Docker image

### 3. Rclone
- Handles backup to Backblaze B2
- Uses the `rclone/rclone` Docker image

## Security Notes

- Keep your `.env` file secure (chmod 600)
- Use strong passwords for the web interface
- Consider using a reverse proxy with SSL for production
- Regularly update Docker images

## Troubleshooting

### Common Issues

**Web interface not accessible**:
```bash
docker compose logs notmuch-web
```

**Sync fails**:
- Verify Yahoo credentials
- Check if app password is correct
- Ensure 2FA is enabled on Yahoo account

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

### Rebuilding Index

If the notmuch index gets corrupted:
```bash
docker compose exec notmuch-web notmuch new
```

## Updating

To update the system:

```bash
git pull
docker compose pull
docker compose up -d notmuch-web
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