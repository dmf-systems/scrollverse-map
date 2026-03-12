# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 ops: logging tools (steps 484-500)
Run as root to automate the advanced logging and diagnostics setup:

```bash
bash scripts/dmf7_logging_tools_484_500.sh
```

The script installs `jq` and `multitail`, provisions `dmf7-logview`, `dmf7-logs-live`, `dmf7-health-report` (with a 02:00 cron job), and `dmf7-diagnose`, generates an initial health report, and prints the deployment summary banner.
