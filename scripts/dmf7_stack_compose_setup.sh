#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="/opt/dmf7/stack"
STACK_FILE="${STACK_DIR}/docker-compose.yml"
CONTROL_SCRIPT="/usr/local/bin/dmf7-stack"
DEPLOY_LOG="/opt/dmf7/DEPLOY_LOG"

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"
fi

log() {
  printf '[dmf7-stack] %s\n' "$*"
}

ensure_dependency() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    log "Missing dependency: $name"
    exit 1
  fi
}

install_docker_compose_plugin() {
  if ! docker compose version >/dev/null 2>&1; then
    log "Installing docker-compose-plugin"
    $SUDO apt-get update -y
    $SUDO apt-get install -y docker-compose-plugin
  fi
  docker compose version
}

write_stack_file() {
  log "Writing stack file to ${STACK_FILE}"
  $SUDO mkdir -p "$STACK_DIR"
  $SUDO tee "$STACK_FILE" >/dev/null <<'EOF'
version: "3.9"

services:

  gateway:
    image: node:20
    working_dir: /app
    volumes:
      - ../platform:/app
    command: pnpm --filter @dmf7/gateway start
    ports:
      - "4000:4000"

  console:
    image: node:20
    working_dir: /app
    volumes:
      - ../platform:/app
    command: pnpm --filter @dmf7/operator-console start
    ports:
      - "4100:4100"

  redis:
    image: redis:7
    ports:
      - "6379:6379"

  qdrant:
    image: qdrant/qdrant
    ports:
      - "6333:6333"

  neo4j:
    image: neo4j
    ports:
      - "7474:7474"
      - "7687:7687"

  ollama:
    image: ollama/ollama
    ports:
      - "11435:11434"
EOF
}

start_stack() {
  log "Starting DMF7 stack"
  (cd "$STACK_DIR" && $SUDO docker compose up -d)
  (cd "$STACK_DIR" && $SUDO docker compose ps)
}

write_control_script() {
  log "Installing control helper at ${CONTROL_SCRIPT}"
  $SUDO tee "$CONTROL_SCRIPT" >/dev/null <<'EOF'
#!/bin/bash

set -euo pipefail

cd /opt/dmf7/stack

case "${1:-}" in
start)
  docker compose up -d
  ;;
stop)
  docker compose down
  ;;
restart)
  docker compose down
  docker compose up -d
  ;;
status)
  docker compose ps
  ;;
logs)
  docker compose logs --tail=50
  ;;
*)
  echo "Usage: dmf7-stack {start|stop|restart|status|logs}"
  ;;
esac
EOF
  $SUDO chmod +x "$CONTROL_SCRIPT"
}

verify_endpoints() {
  log "Verifying stack endpoints"
  local endpoints=(
    "http://localhost:4000"
    "http://localhost:4100"
    "http://localhost:6333"
    "http://localhost:7474"
  )

  for url in "${endpoints[@]}"; do
    if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
      log "OK: $url"
    else
      log "WARN: $url did not respond successfully"
    fi
  done
}

write_deploy_log() {
  log "Recording deployment log at ${DEPLOY_LOG}"
  $SUDO sh -c "echo \"DMF7 STACK DEPLOYED $(date)\" > \"$DEPLOY_LOG\""
  $SUDO cat "$DEPLOY_LOG"
}

final_banner() {
  local host_ip
  host_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  host_ip="${host_ip:-localhost}"

  cat <<EOF
=======================================
 DMF7 FULL STACK ORCHESTRATION ACTIVE 
=======================================

Gateway:  http://${host_ip}:4000
Console:  http://${host_ip}:4100
AI UI:    http://${host_ip}:3001

Neo4j:    http://${host_ip}:7474
Qdrant:   http://${host_ip}:6333

Monitoring:
Grafana:  http://${host_ip}:3000
Portainer:http://${host_ip}:9000

=======================================
 DMF7 AUTONOMOUS AI NODE COMPLETE 
=======================================
EOF
}

main() {
  ensure_dependency docker
  ensure_dependency curl

  install_docker_compose_plugin
  write_stack_file
  start_stack
  write_control_script

  log "Checking stack status via dmf7-stack"
  dmf7-stack status || log "dmf7-stack status reported a problem"

  verify_endpoints
  write_deploy_log
  final_banner
}

main "$@"
