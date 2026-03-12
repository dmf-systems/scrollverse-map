# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Final Ops (Steps 98–110)

The `scripts/dmf7_final_steps.sh` helper automates the final DMF7 server tasks (Grafana plugin install, log viewer, monitor, health checks, and emergency start/stop).

Usage:

```bash
# setup-only
sudo bash scripts/dmf7_final_steps.sh

# run setup plus log/health checks and emergency stop/start validation
sudo bash scripts/dmf7_final_steps.sh --verify
```

Notes:
- Requires root access with Docker, PM2, crontab, and systemd available.
- Installs helpers to `/usr/local/bin` and schedules the monitor cron at `*/5 * * * *`.
- Customise with env vars `GRAFANA_CONTAINER` and `MONITOR_LOG` if needed.
