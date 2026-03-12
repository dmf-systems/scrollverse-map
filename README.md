# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## Firewall and Fail2Ban hardening

Automate security hardening steps 377-400 with:

```bash
sudo bash scripts/dmf7_firewall_hardening.sh
```

What it does:
- Installs and configures UFW with default deny inbound and allows SSH plus DMF7 service ports (80, 443, 4000, 4100, 3001, 6333, 7474, 9000, 3000).
- Installs Fail2Ban with an `sshd` jail (maxretry 3, bantime 1h) and restarts the service.
- Creates helper commands `/usr/local/bin/dmf7-firewall` and `/usr/local/bin/dmf7-network` for quick status checks.
- Runs basic connectivity checks (ping, DNS lookup, GitHub API) and writes `/opt/dmf7/DEPLOY_LOG`.

Requirements: run as root on Debian/Ubuntu with `apt-get`; `nslookup` output is best when `dnsutils` is available. The script tolerates missing optional utilities but will report them.
