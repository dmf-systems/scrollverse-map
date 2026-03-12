#!/usr/bin/env bash
set -euo pipefail

NODE_IP="72.61.114.167"
DEPLOY_LOG="/opt/dmf7/SYSTEM_DEPLOYMENT_LOG.txt"
SERVICE_MAP="/opt/dmf7/SERVICE_MAP.txt"
READY_FILE="/opt/dmf7/NODE_READY.txt"
STATUS_CMD="/usr/local/bin/dmf7-status"

apt_updated=0

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This installer must be run as root (use sudo)." >&2
    exit 1
  fi
}

apt_update_once() {
  if [[ "$apt_updated" -eq 0 ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt_updated=1
  fi
}

ensure_package() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    apt_update_once
    apt-get install -y "$pkg"
  fi
}

configure_ufw() {
  echo "Configuring UFW firewall (steps 1151-1152)..."
  ensure_package ufw

  local ports=("OpenSSH" 80 443 4000 4100 3001 7474 7687 6333 9000 3000)
  for port in "${ports[@]}"; do
    ufw allow "$port"
  done

  ufw --force enable
  ufw status verbose
}

configure_fail2ban() {
  echo "Installing and configuring Fail2Ban (steps 1153-1156)..."
  ensure_package fail2ban

  systemctl enable fail2ban

  cat >/etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
EOF

  systemctl restart fail2ban
  fail2ban-client status
}

write_deployment_log() {
  echo "Writing deployment log (steps 1157-1158)..."
  mkdir -p /opt/dmf7

  cat >"$DEPLOY_LOG" <<EOF
DMF7 GLOBAL NODE DEPLOYMENT

Node IP
$NODE_IP

Services
DMF7 Gateway
DMF7 Operator Console
DMF7 Ingest
DMF7 Retrieval

Infrastructure
Neo4j Graph DB
Qdrant Vector DB
Redis Stack
Ollama AI Runtime

Interfaces
OpenWebUI
Grafana
Portainer

Security
UFW Firewall
Fail2Ban

Status
Production Node Active
EOF

  cat "$DEPLOY_LOG"
}

write_service_map() {
  echo "Writing service map (steps 1159-1160)..."
  cat >"$SERVICE_MAP" <<'EOF'
DMF7 SERVICE MAP

4000  Gateway API
4100  Operator Console
3001  OpenWebUI
7474  Neo4j Browser
7687  Neo4j Bolt
6333  Qdrant Vector DB
6380  Redis Stack
3000  Grafana
9000  Portainer
11435 Ollama Runtime
EOF

  cat "$SERVICE_MAP"
}

install_status_command() {
  echo "Installing dmf7-status helper (steps 1161-1163)..."
  cat >"$STATUS_CMD" <<'EOF'
#!/bin/bash

echo "========== DMF7 STATUS =========="

echo ""
echo "PM2 SERVICES"
if command -v pm2 >/dev/null 2>&1; then
  pm2 list
else
  echo "pm2 not installed"
fi

echo ""
echo "DOCKER SERVICES"
if command -v docker >/dev/null 2>&1; then
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "docker is installed but not running"
else
  echo "docker not installed"
fi

echo ""
echo "SYSTEM LOAD"
uptime || true

echo ""
echo "MEMORY"
free -h || true

echo ""
echo "DISK"
df -h || true

echo ""
echo "================================="
EOF

  chmod +x "$STATUS_CMD"
  "$STATUS_CMD" || true
}

write_ready_file() {
  echo "Writing node ready file (steps 1164-1165)..."
  echo "DMF7 Node $NODE_IP Production Ready" >"$READY_FILE"
  cat "$READY_FILE"
}

print_final_confirmation() {
  echo "================================="
  echo "DMF7 GLOBAL NODE ONLINE"
  echo ""
  echo "Gateway API        : http://$NODE_IP:4000"
  echo "Operator Console   : http://$NODE_IP:4100"
  echo "AI Interface       : http://$NODE_IP:3001"
  echo "Neo4j              : http://$NODE_IP:7474"
  echo "Grafana Monitoring : http://$NODE_IP:3000"
  echo "Portainer Docker   : http://$NODE_IP:9000"
  echo ""
  echo "SYSTEM STATUS: PRODUCTION READY"
  echo "================================="
}

main() {
  require_root
  configure_ufw
  configure_fail2ban
  write_deployment_log
  write_service_map
  install_status_command
  write_ready_file
  print_final_confirmation
}

main "$@"
