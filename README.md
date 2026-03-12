# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 SSL automation (steps 278-292)
Use `scripts/dmf7_ssl_setup.sh` to automate the SSL portion of the DMF7 deployment checklist.

### Prerequisites
- Run on the DMF7 host as root (script manages packages, nginx, and certbot).
- nginx site file at `/etc/nginx/sites-available/dmf7` is present.
- You have a domain pointed at the host and an email for Let's Encrypt.

### Usage
```bash
sudo bash scripts/dmf7_ssl_setup.sh --domain dmf7.example.com --email ops@example.com
```
Add `--staging` for a test issuance.

### What the script does
- Installs certbot and the nginx plugin.
- Updates the nginx `server_name` to your domain and reloads nginx.
- Requests a Let's Encrypt certificate with HTTP->HTTPS redirect.
- Enables and tests certbot renewal, runs HTTPS checks (localhost, domain, IP).
- Writes `/opt/dmf7/DEPLOY_LOG`, prints UFW/fail2ban status, and shows the final DMF7 service banner.
