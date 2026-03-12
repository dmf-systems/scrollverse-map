# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 production verification (steps 64–80)

Use `scripts/dmf7_production_check.sh` to run the operational checklist end to end.

- Prereqs: `bash`, `nvm`, `node` 20, `pnpm`, `pm2`, `docker`, `curl`, `ufw`, `systemctl`, and access to the DMF7 codebase at `~/DMF7` (override with `DMF7_DIR`).
- The script restarts PM2 services (`pm2 delete all`) and curls both localhost and public endpoints; run it only when you are ready to disrupt existing PM2 processes.
- Interactive steps (e.g., `htop`) require a TTY; the script will skip them when no terminal is available.
- Public host defaults to `72.61.114.167` and can be overridden with `PUBLIC_HOST`.

Example:

```bash
NODE_VERSION=20 DMF7_DIR="$HOME/DMF7" PUBLIC_HOST=72.61.114.167 ./scripts/dmf7_production_check.sh
```
