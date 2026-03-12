# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 system performance tools

Run the helper script to install monitoring utilities and create the live monitor/report commands:

```bash
sudo bash scripts/dmf7_system_performance_tools.sh
```

After installation:
- `dmf7-live` shows uptime, CPU/memory, disk, Docker containers, and PM2 services (Ctrl+C to exit).
- `nload` displays live network traffic (press `q` to exit).
- `ncdu /` inspects disk usage.
- `dmf7-report` writes a daily report to `/opt/dmf7/reports/`.
