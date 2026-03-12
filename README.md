# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Phase2 automation (steps 1001-1021)

A provisioning script is included to install the Phase2 AI system components:

- Agent task runner (`/usr/local/bin/dmf7-agent`) and task creator (`/usr/local/bin/dmf7-agent-task`)
- Vector ingest helper (`/usr/local/bin/dmf7-vector-ingest`) targeting Qdrant at `localhost:6333`
- Research analyzer (`/usr/local/bin/dmf7-analyze`) and network scanner (`/usr/local/bin/dmf7-network-scan`)
- Required directories under `/opt/dmf7` plus a cron job to execute `dmf7-agent` every minute

Run with elevated permissions:

```bash
sudo ./scripts/dmf7_phase2_1001_1021.sh [--verify] [--skip-cron]
```

Use `--verify` to run basic checks after provisioning. Use `--skip-cron` if you want to avoid installing the cron entry.
