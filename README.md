# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 control center automation (steps 899-907)
Use `scripts/dmf7_control_center_899_907.sh` to install the DMF7 global control menu, auto-start service, and node info file described in the deployment runbook.

**Prerequisites**
- `sudo` available for writing to `/usr/local/bin`, `/etc/systemd/system`, and `/opt/dmf7`
- `systemd` available for enabling/restarting services

**Run**
```bash
sudo ./scripts/dmf7_control_center_899_907.sh
```
The script installs `/usr/local/bin/dmf7`, enables the `dmf7` systemd service, writes `/opt/dmf7/NODE_INFO.txt`, reloads systemd, and prints the final status banner. Override `SUDO` if you need a different privilege escalation command.
