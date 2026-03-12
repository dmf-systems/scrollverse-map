# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 security hardening (steps 293–310)

Run the automation as root to apply the hardening checklist:

```bash
sudo bash scripts/dmf7_security_hardening_293_310.sh
```

The script installs unattended upgrades, rootkit scanners (rkhunter, chkrootkit), and Lynis, enforces the requested SSH settings, configures logrotate for `/opt/dmf7/logs/*.log`, creates the daily `/usr/local/bin/dmf7-security-scan` cron job at 03:15, runs initial scans/audits, and writes the deployment snapshot to `/opt/dmf7/DEPLOY_LOG`.
