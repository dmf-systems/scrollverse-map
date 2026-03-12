# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 firewall baseline (steps 1151-1166)

Provision the DMF7 firewall, Fail2Ban, deployment logs, and status tooling with:

```bash
sudo bash scripts/dmf7_firewall_baseline_1151_1166.sh
```

The script opens the required UFW ports, installs and configures Fail2Ban, writes deployment/service records under `/opt/dmf7`, installs the `dmf7-status` helper, and prints the final node readiness banner.
