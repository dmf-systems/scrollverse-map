# scrollverse-map

A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 security checklist (steps 111–130)

Run the hardening and validation sequence with root privileges:

```bash
sudo bash scripts/dmf7_security_checklist.sh
```

What it does:
- Configures unattended upgrades and SSH hardening
- Sets up UFW firewall rules for required ports
- Runs Lynis and Trivy scans
- Applies nofile limits, enables swap, and checks disk health
- Verifies local services (API, console, AI, DBs), Docker, PM2, and DMF7 checks
- Prints the final DMF7 operational banner

Prerequisites:
- Debian/Ubuntu host with apt, ufw, Docker, and PM2 available
- Network access to pull the `aquasec/trivy` image
- Services bound to the expected localhost ports if you want the validation curls to succeed
