# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 management commands

This repository ships helper scripts for DMF7 nodes. Install them to `/usr/local/bin` and make them executable:

```bash
sudo install -m 755 scripts/dmf7-status scripts/dmf7-restart scripts/dmf7-backup scripts/dmf7-update scripts/dmf7-ai-test scripts/dmf7-final-message /usr/local/bin/
```

Available commands:
- `dmf7-status` — show PM2, Docker, system, and NGINX status
- `dmf7-restart` — restart Docker services, PM2 apps, and NGINX
- `dmf7-backup` — archive `/root/DMF7` and `/opt/dmf7/data` into `/opt/dmf7/backups`
- `dmf7-update` — pull the app, use Node 20 via nvm, install, build, and restart PM2
- `dmf7-ai-test` — hit the local Ollama endpoint with a test prompt
- `dmf7-final-message` — print the deployment banner with service URLs and management commands

After installation you can validate with:
```bash
dmf7-status
dmf7-ai-test
```

These scripts assume Docker, PM2, nvm, pnpm, and the listed services are present on the host.
