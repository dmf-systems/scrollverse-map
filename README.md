# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Control Automation

Run the automation to install the DMF7 control panel and safe reboot helpers, perform quick system checks, and print the final deployment banner:

```bash
sudo bash scripts/dmf7_control_setup.sh
```

The script installs `/usr/local/bin/dmf7-control` (menu-driven controls) and `/usr/local/bin/dmf7-safe-reboot` (backup + PM2 save + reboot). It also runs `df -h`, `free -h`, and `uptime` to verify disk, memory, and CPU status before displaying the production status summary.
