# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Auto-Heal and Control

This repository includes the DMF7 auto-heal service, control command, and nightly snapshot tooling described in steps 53–63 of the deployment runbook.

### Provided files
- `systemd/dmf7-heal.service` — systemd unit for the auto-heal loop.
- `scripts/dmf7-heal` — restarts critical containers and PM2 processes when they are down.
- `scripts/dmf7` — convenience control command for status/restart/backup/update/ai helpers.
- `scripts/dmf7-snapshot` — creates a tarball snapshot under `/opt/dmf7/snapshots`.

### Install (run as root)
Copy the scripts and unit into place and start the service:

```bash
cp scripts/dmf7-heal /usr/local/bin/
cp scripts/dmf7 /usr/local/bin/
cp scripts/dmf7-snapshot /usr/local/bin/
chmod +x /usr/local/bin/dmf7 /usr/local/bin/dmf7-heal /usr/local/bin/dmf7-snapshot

cp systemd/dmf7-heal.service /etc/systemd/system/dmf7-heal.service
systemctl daemon-reload
systemctl enable dmf7-heal
systemctl start dmf7-heal
systemctl status dmf7-heal
```

Schedule the nightly snapshot (runs at 04:00):

```bash
crontab -e
# add:
0 4 * * * /usr/local/bin/dmf7-snapshot
```

Harden unattended updates:

```bash
apt install -y unattended-upgrades
dpkg-reconfigure unattended-upgrades
```

### Control command usage
After installation, the control helper is available as `dmf7`:

```bash
dmf7 status
dmf7 restart
dmf7 backup
dmf7 update
dmf7 ai
```

### Final stack check

```bash
dmf7 status
dmf7 ai
```

```bash
echo "===================================="
echo " DMF7 AUTONOMOUS AI NODE ACTIVE "
echo "===================================="
echo "Server: 72.61.114.167"
echo ""
echo "Core Interfaces:"
echo "Console  : http://72.61.114.167"
echo "API      : http://72.61.114.167/api"
echo "AI UI    : http://72.61.114.167/ai"
echo "Grafana  : http://72.61.114.167/grafana"
echo "Neo4j    : http://72.61.114.167/neo4j"
echo "Portainer: http://72.61.114.167:9000"
echo ""
echo "Control Command:"
echo "dmf7"
echo "===================================="
```
