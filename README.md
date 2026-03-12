# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Nginx Reverse Proxy (Steps 826-840)

The repository includes an automation script to provision the DMF7 reverse proxy, firewall, and optional TLS with certbot.

Script: `scripts/dmf7_nginx_reverse_proxy_826_840.sh`

What it does:
- Installs Nginx, UFW, and certbot (with the Nginx plugin)
- Removes the default Nginx site, installs the DMF7 site block, and restarts Nginx
- Opens required firewall ports (80, 443, 4000, 4100, 3001, 7474, 3000, 9000, 19999) and enables UFW
- Optionally issues certificates with certbot and enables auto-renewal
- Runs a basic curl reachability check and prints the DMF7 public access banner

Usage (run as root/sudo):

```bash
sudo ./scripts/dmf7_nginx_reverse_proxy_826_840.sh \
  --certbot-email you@example.com \
  --certbot-domains example.com,www.example.com
```

Optional flags:
- `--test-url <url>`: Override the curl test target (default `http://72.61.114.167`)
- `--skip-curl`: Skip the curl reachability check
- `--help`: Show usage

Certbot is only executed when both `--certbot-email` and `--certbot-domains` are provided. Domains are comma-separated. If you want to run without issuing certificates yet, omit those flags.
