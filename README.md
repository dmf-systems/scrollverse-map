# scrollverse-map

This repository now includes automation and reference configs to stand up the DMF7 reverse proxy stack (nginx, certbot, logrotate, restart helpers) described in the deployment runbook.

## What gets installed
- nginx configured with routes for the UI (4100), API (4000), AI UI (3001), Grafana (3000), and Neo4j (7474)
- certbot with nginx plugin (optional, requires domain or public IP and email)
- log rotation for `/opt/dmf7/logs/*.log`
- recovery helper script to restart the stack services

## Quick start (root required)
```bash
sudo ./scripts/setup_dmf7_node.sh \
  --server-name 72.61.114.167 \
  --run-certbot \
  --certbot-email you@example.com \
  --verify
```

Key flags:
- `--server-name` sets `server_name` in nginx (default: `72.61.114.167`, override with your domain/IP).
- `--run-certbot` enables HTTPS issuance; requires `--certbot-email` or `CERTBOT_EMAIL`.
- `--verify` runs the post-setup health checks (curls, docker logs, pm2 list).

Environment variables `SERVER_NAME`, `CERTBOT_EMAIL`, `RUN_CERTBOT=true`, and `RUN_VERIFY=true` can be used instead of flags.

## Reference files
- `config/nginx/dmf7.conf` — nginx vhost content written to `/etc/nginx/sites-available/dmf7`.
- `config/logrotate/dmf7` — logrotate policy placed at `/etc/logrotate.d/dmf7`.
- `scripts/dmf7-restart.sh` — recovery script copied to `/root/dmf7-restart.sh`.
- `scripts/setup_dmf7_node.sh` — automation for steps 28–45 of the deployment plan (nginx install, enable site, certbot optional, logrotate, autoheal restart, verifications, endpoint summary).

## Manual verification commands (non-fatal)
These mirror the deployment checklist and are also available via `--verify`:
- `docker logs qdrant --tail 20`
- `docker logs neo4j --tail 20`
- `docker logs redis-ai --tail 20`
- `curl http://localhost:11435/api/tags`
- `curl http://localhost:6333/collections`
- `curl http://localhost:7474`
- `curl http://localhost/api`
- `curl http://localhost`
- `curl http://localhost/ai`
- `pm2 list`
- `docker ps`
- `systemctl status nginx`
