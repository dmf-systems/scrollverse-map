# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 provisioning helper

Run `dmf7_provision.sh` as root to apply deployment steps 11–27 (system dependencies, Docker, firewall, cron, health checks, and backups) on a Debian/Ubuntu host.

Example:

```bash
sudo bash dmf7_provision.sh
```

The script will:
- Install base packages, Docker, and the Docker Compose plugin.
- Create the `/opt/dmf7` workspace and configure cron jobs for ingest, service restarts, and backups.
- Pull Ollama models inside the running `ollama` container and verify Qdrant/Neo4j endpoints.
- Enable UFW rules, install fail2ban, restart monitoring containers (netdata, cadvisor, glances), and run pm2/docker health checks.
- Generate a snapshot archive at `/root/dmf7-system-snapshot.tar.gz` and configure pm2/docker autostart.

Prerequisites:
- Run on the target host (not in a container) with systemd and apt available.
- Ensure the required containers (`ollama`, `redis-ai`, `qdrant`, `neo4j`, plus optional `netdata`, `cadvisor`, `glances`) are present.
- The script enables UFW and modifies cron/system services; review before executing in production.
