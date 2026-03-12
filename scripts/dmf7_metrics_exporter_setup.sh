#!/usr/bin/env bash
set -euo pipefail

log() {
  echo -e "\n==> $*"
}

warn() {
  echo "WARN: $*" >&2
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root. Try again with sudo." >&2
    exit 1
  fi
}

ensure_directory() {
  local dir="$1"
  mkdir -p "${dir}"
}

install_node_exporter() {
  log "Installing prometheus-node-exporter"
  if ! dpkg -s prometheus-node-exporter >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y prometheus-node-exporter
  else
    log "prometheus-node-exporter already installed"
  fi

  systemctl enable prometheus-node-exporter
  systemctl start prometheus-node-exporter

  if ! systemctl --quiet is-active prometheus-node-exporter; then
    warn "prometheus-node-exporter is not active; check systemd logs"
  fi

  systemctl --no-pager status prometheus-node-exporter || warn "Unable to read prometheus-node-exporter status"
}

verify_http_endpoint() {
  local url="$1"
  local description="$2"

  log "Checking ${description} at ${url}"
  if ! curl --fail --silent --show-error --location --max-time 5 "${url}" >/tmp/dmf7_check.log 2>&1; then
    warn "Unable to reach ${description} (${url})"
  else
    log "${description} reachable"
  fi
}

write_metrics_script() {
  log "Creating /usr/local/bin/dmf7-metrics"
  cat <<'EOF' >/usr/local/bin/dmf7-metrics
#!/usr/bin/env bash

print_header() {
  echo "=============================="
  echo " DMF7 SYSTEM METRICS "
  echo "=============================="
}

run_section() {
  local title="$1"
  shift
  echo ""
  echo "${title}"

  if command -v "$1" >/dev/null 2>&1; then
    "$@"
  else
    echo "Command $1 not found; skipping"
  fi
}

print_header

run_section "CPU LOAD:" uptime
run_section "MEMORY:" free -h
run_section "DISK:" df -h /
run_section "DOCKER:" docker ps
run_section "PM2:" pm2 list
EOF

  chmod +x /usr/local/bin/dmf7-metrics
}

write_node_command() {
  log "Creating /usr/local/bin/dmf7-node"
  cat <<'EOF' >/usr/local/bin/dmf7-node
#!/usr/bin/env bash
set -euo pipefail

echo "=============================="
echo " DMF7 NODE COMMAND "
echo "=============================="

echo "1) Status"
echo "2) Metrics"
echo "3) Restart Stack"
echo "4) Backup"
echo "5) Security Scan"

option="${DMF7_NODE_OPTION:-}"
if [[ -z "${option}" ]]; then
  read -rp "Select option: " option
else
  echo "Auto-selected option: ${option}"
fi

case "${option}" in
  1) dmf7-status ;;
  2) dmf7-metrics ;;
  3) dmf7-stack restart ;;
  4) dmf7-backup ;;
  5) dmf7-security-scan ;;
  *) echo "Invalid option" ;;
esac
EOF

  chmod +x /usr/local/bin/dmf7-node
}

run_metrics_script() {
  log "Testing dmf7-metrics"
  if ! /usr/local/bin/dmf7-metrics; then
    warn "dmf7-metrics exited with an error"
  fi
}

run_node_command() {
  log "Testing dmf7-node (Metrics option)"
  if ! DMF7_NODE_OPTION=2 /usr/local/bin/dmf7-node; then
    warn "dmf7-node check failed"
  fi
}

run_health_checks() {
  verify_http_endpoint "http://localhost:4000/api/health" "AI job health"

  if command -v redis-cli >/dev/null 2>&1; then
    log "Testing Redis queue"
    if ! redis-cli ping; then
      warn "Redis ping failed"
    fi
  else
    warn "redis-cli not available; skipping Redis ping"
  fi

  verify_http_endpoint "http://localhost:6333/collections" "Qdrant collections"
  verify_http_endpoint "http://localhost:7474" "Neo4j graph"
  verify_http_endpoint "http://localhost:11435/api/tags" "Ollama AI models"
}

write_deploy_log() {
  ensure_directory /opt/dmf7
  echo "DMF7 GLOBAL NODE ACTIVE $(date)" >/opt/dmf7/DEPLOY_LOG
  log "Updated /opt/dmf7/DEPLOY_LOG"
}

final_banner() {
  cat <<'EOF'
==========================================
 DMF7 AUTONOMOUS AI INFRASTRUCTURE ACTIVE
==========================================

Console:  http://72.61.114.167
API:      http://72.61.114.167:4000
AI:       http://72.61.114.167:3001

Graph DB: http://72.61.114.167:7474
VectorDB: http://72.61.114.167:6333

Monitoring:
Grafana:  http://72.61.114.167:3000
Portainer:http://72.61.114.167:9000

STATUS: GLOBAL NODE LIVE
==========================================
EOF
}

run_final_status() {
  if command -v dmf7-status >/dev/null 2>&1; then
    log "Running dmf7-status"
    if ! dmf7-status; then
      warn "dmf7-status reported an issue"
    fi
  else
    warn "dmf7-status not available; skipping final system validation"
  fi
}

main() {
  require_root

  install_node_exporter
  verify_http_endpoint "http://localhost:9100/metrics" "Node Exporter metrics endpoint"

  write_metrics_script
  run_metrics_script

  run_health_checks

  write_node_command
  run_node_command

  run_final_status
  write_deploy_log
  final_banner
}

main "$@"
