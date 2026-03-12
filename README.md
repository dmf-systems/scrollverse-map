# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 maintenance automation
Run `sudo bash scripts/dmf7_system_maintenance.sh` to apply DMF7 steps 151–160 on a node. The script:
- Installs `/usr/local/bin/dmf7-maintenance` (apt update/upgrade/autoremove, docker prune, pm2 flush) and `/usr/local/bin/dmf7-info` (hostname, IP, Node/PNPM/Docker/PM2 versions, disk, memory, CPU).
- Schedules weekly maintenance via cron: `0 2 * * 0 /usr/local/bin/dmf7-maintenance > /opt/dmf7/logs/maintenance.log 2>&1`.
- Runs `dmf7-info`, shows routing, DNS, time sync status, installs/enables/starts `chrony`, and verifies with `chronyc tracking`.
- Prints the final “DMF7 NODE STABLE & LOCKED FOR PROD” banner with management commands.

The script must be run as root because it writes to `/usr/local/bin`, installs packages, and manages system services/cron. Ensure `/opt/dmf7/logs` is writable for cron output.
