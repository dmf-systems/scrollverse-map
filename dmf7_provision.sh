#!/usr/bin/env bash

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must be run as root (sudo)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

install_system_dependencies() {
  log "Updating apt cache and upgrading packages (Step 11)"
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y build-essential curl git unzip htop jq python3 python3-pip
}

install_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    log "Installing Docker (Step 12)"
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
  else
    log "Docker already installed; skipping installer"
  fi

  log "Enabling and starting Docker service"
  systemctl enable docker
  systemctl start docker
  docker --version
}

install_docker_compose_plugin() {
  log "Installing Docker Compose plugin (Step 13)"
  apt-get install -y docker-compose-plugin
  docker compose version
}

create_ai_workspace() {
  log "Creating AI workspace directories (Step 14)"
  mkdir -p /opt/dmf7/data
  mkdir -p /opt/dmf7/logs
  mkdir -p /opt/dmf7/backups
  mkdir -p /opt/dmf7/models
}

require_container() {
  local name="$1"
  if ! docker ps --format '{{.Names}}' | grep -Fxq "$name"; then
    echo "Container '$name' is required but not running. Start it and rerun." >&2
    exit 1
  fi
}

install_ollama_models() {
  log "Pulling Ollama models (Step 15)"
  require_container "ollama"
  docker exec ollama ollama pull llama3
  docker exec ollama ollama pull mistral
  docker exec ollama ollama pull phi
}

verify_services() {
  log "Verifying AI engine (Step 16)"
  curl -fsS http://localhost:11435/api/tags >/dev/null

  log "Testing vector database (Step 17)"
  curl -fsS http://localhost:6333/collections >/dev/null

  log "Testing graph database (Step 18)"
  curl -fsS http://localhost:7474 >/dev/null
}

configure_cron() {
  log "Configuring system cron jobs (Step 19)"
  local tmpfile
  tmpfile="$(mktemp)"
  crontab -l 2>/dev/null >"$tmpfile" || true

  add_cron_entry() {
    local entry="$1"
    if ! grep -Fqx "$entry" "$tmpfile"; then
      echo "$entry" >>"$tmpfile"
    fi
  }

  add_cron_entry '*/15 * * * * cd /root/DMF7 && pnpm run ingest:scheduled > /opt/dmf7/logs/ingest.log 2>&1'
  add_cron_entry '0 * * * * docker restart redis-ai qdrant neo4j > /opt/dmf7/logs/infra.log 2>&1'
  add_cron_entry '0 3 * * * tar -czf /opt/dmf7/backups/backup-$(date +\%F).tar.gz /root/DMF7 /opt/dmf7/data'

  crontab "$tmpfile"
  rm -f "$tmpfile"
}

configure_firewall() {
  log "Configuring firewall rules (Step 20)"
  ufw allow 22
  ufw allow 4000
  ufw allow 4100
  ufw allow 3001
  ufw allow 3000
  ufw allow 7474
  ufw allow 6333
  ufw allow 9000
  ufw --force enable
}

configure_fail2ban() {
  log "Installing and enabling fail2ban (Step 21)"
  apt-get install -y fail2ban
  systemctl enable fail2ban
  systemctl start fail2ban
}

restart_monitoring() {
  log "Restarting monitoring containers (Step 22)"
  for container in netdata cadvisor glances; do
    if docker ps --format '{{.Names}}' | grep -Fxq "$container"; then
      docker restart "$container"
    else
      log "Container '$container' not found; skipping restart"
    fi
  done
}

verify_full_stack() {
  log "Verifying full stack (Step 23)"
  if command -v pm2 >/dev/null 2>&1; then
    pm2 list
  else
    echo "pm2 is not installed; install it to manage Node processes." >&2
  fi
  docker ps
}

final_health_checks() {
  log "Running final health checks (Step 24)"
  curl -fsS http://localhost:4000 >/dev/null
  curl -fsS http://localhost:4100 >/dev/null
  curl -fsS http://localhost:6333 >/dev/null
  curl -fsS http://localhost:11435 >/dev/null
}

create_snapshot() {
  log "Creating system snapshot (Step 25)"
  tar -czf /root/dmf7-system-snapshot.tar.gz /root/DMF7
}

configure_autostart() {
  log "Configuring autostart services (Step 26)"
  if command -v pm2 >/dev/null 2>&1; then
    pm2 startup
    pm2 save
  else
    echo "pm2 is not installed; skipping pm2 autostart configuration." >&2
  fi
  systemctl enable docker
}

final_status() {
  log "Final node status (Step 27)"
  echo "DMF7 AI NODE ONLINE"
  echo "Gateway: http://72.61.114.167:4000"
  echo "Console: http://72.61.114.167:4100"
  echo "AI UI: http://72.61.114.167:3001"
  echo "Grafana: http://72.61.114.167:3000"
  echo "Neo4j: http://72.61.114.167:7474"
  echo "Portainer: http://72.61.114.167:9000"
}

main() {
  install_system_dependencies
  install_docker
  install_docker_compose_plugin
  create_ai_workspace
  install_ollama_models
  verify_services
  configure_cron
  configure_firewall
  configure_fail2ban
  restart_monitoring
  verify_full_stack
  final_health_checks
  create_snapshot
  configure_autostart
  final_status
}

main "$@"
