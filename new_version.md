I want to update to a new approach.

# Tools (what + why)

* **mbsync (isync):** one-way IMAP pull from Yahoo → local Maildir.
* **Dovecot (+ ACL, FTS Xapian/flatcurve, zlib/mail\_compress):** IMAP read-only archive with full-text search + compression.
* **Roundcube:** browser UI (view/search only). Exposed on a host port.
* **imapfilter:** deletes old mail on Yahoo after sync. **No official Docker image** — use a tiny self-built image or a vetted community one.
* **rclone (optional crypt):** off-site sync of archive/index/configs to B2 (or S3-compatible).
* **Scheduler:** Ofelia (or cron sidecar) to run mbsync → imapfilter → rclone + daily compress/index tasks.

# Host paths

* `/srv/docker-data/mail/archive` — Maildir archive
* `/srv/docker-data/mail/dovecot/index` — Dovecot INDEX
* `/srv/docker-data/mail/dovecot/control` — Dovecot CONTROL
* `/srv/docker-data/mail/state/mbsync` — mbsync SyncState
* `/srv/docker-data/mail/roundcube/db` — Roundcube DB
* `/srv/docker-data/mail/config/{dovecot,mbsync,roundcube,imapfilter,rclone}` — configs
* `/srv/docker-data/mail/secrets/{imap_password,rclone.conf}` — secrets

# Docker (concise skeleton)

```yaml
services:
  dovecot:
    image: <dovecot-image>
    volumes:
      - /srv/docker-data/mail/archive:/srv/mail/archive:ro
      - /srv/docker-data/mail/dovecot/index:/var/dovecot/index:rw
      - /srv/docker-data/mail/dovecot/control:/var/dovecot/control:rw
      - /srv/docker-data/mail/config/dovecot:/etc/dovecot:ro
    # no public ports

  roundcube:
    image: <roundcube-image>
    ports:
      - "8080:80"   # public UI on this host; you’ll proxy to it elsewhere
    environment:
      - ROUNDCUBE_DEFAULT_HOST=dovecot
    volumes:
      - /srv/docker-data/mail/roundcube/db:/var/roundcube/db:rw
      - /srv/docker-data/mail/config/roundcube:/var/roundcube/config:ro
    depends_on: [dovecot]

  mbsync:
    image: <isync-image>
    volumes:
      - /srv/docker-data/mail/archive:/srv/mail/archive:rw
      - /srv/docker-data/mail/state/mbsync:/var/lib/mbsync:rw
      - /srv/docker-data/mail/config/mbsync:/etc/mbsync:ro
    secrets: [imap_password]

  imapfilter:
    build: ./imapfilter   # self-built tiny image (no official upstream)
    volumes:
      - /srv/docker-data/mail/config/imapfilter:/etc/imapfilter:ro
    secrets: [imap_password]

  rclone:
    image: <rclone-image>
    volumes:
      - /srv/docker-data/mail:/data:ro
      - /srv/docker-data/mail/config/rclone:/config/rclone:ro
    secrets: [rclone_credentials]

  compress:  # daily “compress old mail” task for Dovecot mail_compress
    image: <tiny-shell-image>
    volumes:
      - /srv/docker-data/mail/archive:/srv/mail/archive:rw

  ofelia:
    image: mcuadros/ofelia:latest
    depends_on: [mbsync, imapfilter, rclone, compress]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

secrets:
  imap_password: { file: /srv/docker-data/mail/secrets/imap_password }
  rclone_credentials: { file: /srv/docker-data/mail/secrets/rclone.conf }
```

**Flow:** `mbsync → imapfilter → rclone` (scheduled), plus daily compress/index jobs.
**Safety:** Dovecot ACLs + read-only bind mount on `/srv/docker-data/mail/archive` keep the archive immutable via IMAP.
