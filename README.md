# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 nextgen production checklist (steps 227-244)

Use `scripts/dmf7_nextgen_production.sh` to automate the Node 20 fix, platform rebuild, PM2 restarts, service verification, and production flagging outlined in the latest DMF7 runbook steps.

Example:

```
chmod +x scripts/dmf7_nextgen_production.sh
sudo NVM_DIR="$HOME/.nvm" PLATFORM_DIR="/opt/dmf7/platform" bash scripts/dmf7_nextgen_production.sh
```

Environment overrides:

- `NODE_VERSION` (default: `20`)
- `PLATFORM_DIR` (default: `/opt/dmf7/platform`)
- `STATUS_FILE` (default: `/opt/dmf7/STATUS`)
