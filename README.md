# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 platform utilities

This repository includes operational helpers for DMF7 nodes. To reset PM2 so it runs from the production platform directory and to verify services (steps 245-260), run:

```bash
sudo bash scripts/dmf7_pm2_platform_reset.sh
```

The script:
- switches to `/opt/dmf7/platform` before launching services
- restarts the PM2-managed gateway/console/ingest/retrieval apps via `pnpm`
- saves PM2 state and confirms all four processes are `online`
- checks local endpoints (4000, 4100, 6333, 11435/api/tags, 7474, 3001)
- runs `dmf7-status`, sets `/opt/dmf7/NODE_ID`, and runs `dmf7-report`
- prints the final confirmation banner with external URLs
