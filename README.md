# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Backup Automation

Run `sudo bash scripts/dmf7_backup_setup.sh` to install backup utilities, create backup/cleanup helpers under `/usr/local/bin`, run an initial backup, and schedule daily jobs (backup at 01:00, cleanup at 01:30). Backups are stored in `/opt/dmf7/backups` and the backup log is written to `/opt/dmf7/logs/backup.log`.
