# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 network stack automation
Use `scripts/dmf7_network_stack_setup.sh` to configure the nginx reverse proxy and DMF7 network checks (Steps 261-277).

Run as root (or with sudo):

```
sudo bash scripts/dmf7_network_stack_setup.sh
```

The script installs nginx, writes the `dmf7` site config for 72.61.114.167 and local service hostnames, enables the site, opens port 80 via ufw (when available), validates the config, and records deployment status in `/opt/dmf7/DEPLOY_LOG`.
