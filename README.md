# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 system automation

A helper script is provided to install the DMF7 audit, resource guard, incident report, and snapshot tools (steps 943-960) along with the required cron jobs.

Run with sudo (adds binaries under `/usr/local/bin` and cron entries):

```bash
sudo bash scripts/dmf7_system_audit_943_960.sh        # installs tools
sudo bash scripts/dmf7_system_audit_943_960.sh --verify  # installs and runs verification commands
```

The script installs:
- `dmf7-audit`: system audit summary (uptime, memory, disk, docker, pm2, open ports)
- `dmf7-resource-guard`: CPU/memory guard that restarts pm2 workers on high usage
- `dmf7-incident`: incident report saved to `/opt/dmf7/incidents`
- `dmf7-snapshot`: snapshot saved to `/opt/dmf7/snapshots`

Cron schedules:
- `*/3 * * * * /usr/local/bin/dmf7-resource-guard > /opt/dmf7/resource-guard.log 2>&1`
- `0 */6 * * * /usr/local/bin/dmf7-snapshot > /opt/dmf7/snapshot.log 2>&1`
