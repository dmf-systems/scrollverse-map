# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 automation
Run `scripts/dmf7_update_1137_1150.sh` as root to provision the DMF7 update, monitoring, and log-cleaning helpers:

- Installs `/usr/local/bin/dmf7-update`, `/usr/local/bin/dmf7-log-clean`, `/usr/local/bin/dmf7-monitor`, `/usr/local/bin/dmf7-watch`
- Adds a daily cron entry `0 3 * * * /usr/local/bin/dmf7-log-clean`
- Optional flags: `--skip-update`, `--skip-monitor`, `--skip-endpoints`
- Prints the final DMF7 node readiness banner when finished
