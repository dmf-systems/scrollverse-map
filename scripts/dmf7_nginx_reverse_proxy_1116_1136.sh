#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "[dmf7 1116-1136] $*"
}

warn() {
  echo "[dmf7 1116-1136][warn] $*" >&2
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This installer must be run as root (try sudo)." >&2
    exit 1
  fi
}

write_nginx_config() {
  cat >/etc/nginx/sites-available/dmf7 <<'EOF'
server {
    listen 80;
    server_name _;

    location /gateway/ {
        proxy_pass http://127.0.0.1:4000/;
    }

    location /console/ {
        proxy_pass http://127.0.0.1:4100/;
    }

    location /ai/ {
        proxy_pass http://127.0.0.1:3001/;
    }

    location /neo4j/ {
        proxy_pass http://127.0.0.1:7474/;
    }

    location /grafana/ {
        proxy_pass http://127.0.0.1:3000/;
    }

    location /portainer/ {
        proxy_pass http://127.0.0.1:9000/;
    }

    location /qdrant/ {
        proxy_pass http://127.0.0.1:6333/;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/dmf7 /etc/nginx/sites-enabled/dmf7
}

verify_route() {
  local name="$1"
  local url="$2"

  if ! command -v curl >/dev/null 2>&1; then
    warn "curl not available; skipping ${name} verification"
    return
  fi

  if ! curl -fsSL --max-time 5 "$url" >/dev/null; then
    warn "${name} route at ${url} is not responding (service may be offline)"
  else
    log "Verified ${name} route at ${url}"
  fi
}

install_nginx() {
  log "Installing and enabling nginx reverse proxy"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y nginx

  systemctl enable nginx
  systemctl start nginx

  rm -f /etc/nginx/sites-enabled/default
  write_nginx_config

  nginx -t
  systemctl restart nginx

  verify_route "gateway" "http://localhost/gateway"
  verify_route "console" "http://localhost/console"
}

install_certbot() {
  log "Installing certbot for nginx"
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y certbot python3-certbot-nginx
}

configure_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    log "Allowing HTTP/HTTPS through UFW"
    ufw allow 80/tcp || warn "Unable to allow port 80 via ufw"
    ufw allow 443/tcp || warn "Unable to allow port 443 via ufw"
  else
    warn "ufw not installed; skipping firewall configuration"
  fi
}

write_backup_script() {
  mkdir -p /opt/dmf7/backups
  mkdir -p /opt/dmf7 "$HOME/DMF7"

  cat >/usr/local/bin/dmf7-backup <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

DATE=$(date +%Y%m%d-%H%M)
BACKUP_DIR="/opt/dmf7/backups"
mkdir -p "${BACKUP_DIR}"

TARGETS=()
for path in /opt/dmf7 "$HOME/DMF7"; do
  if [ -e "$path" ]; then
    TARGETS+=("$path")
  else
    echo "Missing $path; skipping" >&2
  fi
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "No backup targets found" >&2
  exit 1
fi

tar -czf "${BACKUP_DIR}/dmf7-${DATE}.tar.gz" "${TARGETS[@]}"
echo "Backup created: ${DATE}"
EOF

  chmod +x /usr/local/bin/dmf7-backup
}

schedule_backup() {
  local cron_entry="0 2 * * * /usr/local/bin/dmf7-backup"

  if crontab -l 2>/dev/null | grep -Fq "/usr/local/bin/dmf7-backup"; then
    log "Backup cron entry already present"
  else
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    log "Scheduled daily backup at 02:00"
  fi
}

test_backup() {
  if /usr/local/bin/dmf7-backup; then
    ls -al /opt/dmf7/backups || warn "Unable to list backups"
  else
    warn "dmf7-backup reported an error"
  fi
}

write_restart_script() {
  cat >/usr/local/bin/dmf7-restart-all <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

restart_cmd() {
  if ! "$@"; then
    echo "Command failed: $*" >&2
    return 1
  fi
}

restart_cmd pm2 restart all || true

for svc in neo4j redis-ai qdrant open-webui portainer netdata cadvisor glances; do
  restart_cmd docker restart "$svc" || true
done

echo "DMF7 services restarted"
EOF

  chmod +x /usr/local/bin/dmf7-restart-all
}

test_restart_script() {
  if ! /usr/local/bin/dmf7-restart-all; then
    warn "dmf7-restart-all reported an error"
  fi
}

final_checks() {
  if command -v dmf7-check >/dev/null 2>&1; then
    if ! dmf7-check; then
      warn "dmf7-check reported issues"
    fi
  else
    warn "dmf7-check not found; skipping"
  fi

  echo "================================="
  echo "DMF7 DEPLOYMENT COMPLETE"
  echo "Gateway: http://72.61.114.167/gateway/"
  echo "Console: http://72.61.114.167/console/"
  echo "AI Interface: http://72.61.114.167/ai/"
  echo "Neo4j: http://72.61.114.167/neo4j/"
  echo "Grafana: http://72.61.114.167/grafana/"
  echo "Portainer: http://72.61.114.167/portainer/"
  echo "================================="
}

main() {
  require_root

  install_nginx
  install_certbot
  configure_firewall

  write_backup_script
  schedule_backup
  test_backup

  write_restart_script
  test_restart_script

  final_checks
}

main "$@"
