# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 node operations (steps 871-882)

The repository ships an automation script to provision DMF7 log rotation, backups, and reset tooling in one run.

Run as root:

```bash
sudo bash scripts/dmf7_log_rotation_backup_reset_871_882.sh
```

What it does:
- Installs logrotate and writes `/etc/logrotate.d/dmf7`
- Installs `/usr/local/bin/dmf7-backup`, runs an initial backup, and schedules a daily cron at 02:00 to `/opt/dmf7/backup.log`
- Installs `/usr/local/bin/dmf7-reset` to restart PM2, Docker services (redis-ai, qdrant, neo4j, ollama), and nginx
- Prints the final node status banner

Flags:
- `--skip-backup-run` to avoid the initial backup
- `--skip-logrotate-test` to skip `logrotate -d /etc/logrotate.conf`
- `--skip-cron` to omit the cron entry
- `--run-reset` to execute the reset tool once after installation
