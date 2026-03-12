# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Service Recovery Helper

Use `scripts/dmf7-redeploy.sh` to perform the full DMF7 recovery sequence described in the ops runbook (install Node 20 via nvm, reinstall pnpm deps, apply .env defaults, reset pm2, restart Docker infra, and re-run health checks).

Prerequisites:
- nvm installed and available at `$HOME/.nvm`
- pnpm, pm2, docker, and curl available on the host
- DMF7 project located at `$HOME/DMF7` (override with `DMF7_DIR=/path/to/DMF7`)

Run:

```bash
chmod +x scripts/dmf7-redeploy.sh
DMF7_DIR=/root/DMF7 ENV_FILE=/root/DMF7/.env bash scripts/dmf7-redeploy.sh
```

The script will:
- Install and use Node.js 20 via nvm
- Reinstall dependencies (`pnpm install`) and rebuild the workspace
- Ensure `.env` exists (copied from `.env.example` when present) and add the required service URLs if missing
- Reset and restart pm2 services for gateway, operator console, ingest, and retrieval
- Restart supporting Docker containers (redis-ai, qdrant, neo4j, ollama, portainer, netdata, cadvisor, glances, grafana)
- Run quick health checks against `http://localhost:4000` and `http://localhost:4100`, then enable pm2 startup

After the script finishes, manually verify public access (4000, 4100, 3001, 7474, 3000, 9000) from your browser if needed.
