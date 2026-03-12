#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

log() {
  echo "[dmf7-network] $*"
}

install_nginx() {
  log "Installing nginx reverse proxy (Step 261)"
  $SUDO apt-get update -y
  $SUDO apt-get install -y nginx
}

enable_nginx() {
  log "Enabling nginx at boot and starting service (Step 262)"
  $SUDO systemctl enable nginx
  $SUDO systemctl start nginx
}

write_nginx_config() {
  log "Writing dmf7 nginx site configuration (Step 263)"
  $SUDO tee /etc/nginx/sites-available/dmf7 >/dev/null <<'EOF'
server {
    listen 80;
    server_name 72.61.114.167;

    location / {
        proxy_pass http://localhost:4100;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

server {
    listen 80;
    server_name api.dmf7.local;

    location / {
        proxy_pass http://localhost:4000;
    }
}

server {
    listen 80;
    server_name ai.dmf7.local;

    location / {
        proxy_pass http://localhost:3001;
    }
}

server {
    listen 80;
    server_name graph.dmf7.local;

    location / {
        proxy_pass http://localhost:7474;
    }
}

server {
    listen 80;
    server_name vector.dmf7.local;

    location / {
        proxy_pass http://localhost:6333;
    }
}
EOF

  log "Enabling dmf7 site (Step 264)"
  $SUDO ln -sf /etc/nginx/sites-available/dmf7 /etc/nginx/sites-enabled/dmf7
}

validate_and_reload_nginx() {
  log "Testing nginx configuration (Step 265)"
  $SUDO nginx -t

  log "Reloading nginx (Step 266)"
  $SUDO systemctl reload nginx
}

configure_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    log "Opening firewall for HTTP 80/tcp (Step 267)"
    $SUDO ufw allow 80/tcp
    $SUDO ufw reload
  else
    log "ufw not installed; skipping firewall updates (Step 267)"
  fi
}

nginx_status() {
  log "Checking nginx status (Step 268)"
  $SUDO systemctl status nginx --no-pager
}

verify_proxy() {
  log "Testing local proxy http://localhost (Step 269)"
  curl --max-time 10 http://localhost
}

prepare_logs() {
  log "Creating nginx log directory /opt/dmf7/nginx-logs (Step 270)"
  $SUDO mkdir -p /opt/dmf7/nginx-logs
}

check_ports_and_firewall() {
  log "Verifying active ports (Step 271)"
  $SUDO ss -tulnp

  if command -v ufw >/dev/null 2>&1; then
    log "Saving firewall state (Step 272)"
    $SUDO ufw status
  fi
}

verify_public_access() {
  log "Testing public access http://72.61.114.167 (Step 273)"
  curl --max-time 10 http://72.61.114.167
}

network_stack_status() {
  if command -v dmf7-status >/dev/null 2>&1; then
    log "Running dmf7-status (Step 274)"
    dmf7-status
  else
    log "dmf7-status not available; skipping Step 274"
  fi
}

write_deploy_log() {
  log "Writing deployment marker (Step 275)"
  $SUDO mkdir -p /opt/dmf7
  $SUDO bash -c "echo \"DMF7 STACK NETWORK READY $(date)\" > /opt/dmf7/DEPLOY_LOG"

  log "Verifying deploy log (Step 276)"
  $SUDO cat /opt/dmf7/DEPLOY_LOG
}

final_status_banner() {
  cat <<'EOF'
====================================
DMF7 PLATFORM NETWORK STACK ACTIVE
====================================

Main Console:
http://72.61.114.167

Gateway API:
http://72.61.114.167:4000

AI Interface:
http://72.61.114.167:3001

Neo4j:
http://72.61.114.167:7474

Vector DB:
http://72.61.114.167:6333

Monitoring:
Grafana:  http://72.61.114.167:3000
Portainer: http://72.61.114.167:9000
====================================
EOF
}

main() {
  install_nginx
  enable_nginx
  write_nginx_config
  validate_and_reload_nginx
  configure_firewall
  nginx_status
  verify_proxy
  prepare_logs
  check_ports_and_firewall
  verify_public_access
  network_stack_status
  write_deploy_log
  final_status_banner
}

main "$@"
