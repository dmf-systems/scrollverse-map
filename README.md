# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Node Refresh (Steps 813-825)

Use the helper script to enforce Node.js 20, rebuild DMF7 with pnpm, restart PM2 services, and verify supporting containers.

### Prerequisites
- nvm available at `$HOME/.nvm`
- pnpm, pm2, curl, and docker in PATH
- DMF7 codebase available (defaults to `~/DMF7`, override with `DMF7_DIR`)

### Run
```bash
bash scripts/dmf7_node_refresh_813_825.sh
```

Environment overrides:
- `NODE_VERSION` (default: `20`)
- `DMF7_DIR` (default: `~/DMF7`)
- `PUBLIC_HOST` (default: `72.61.114.167` for final banner)
