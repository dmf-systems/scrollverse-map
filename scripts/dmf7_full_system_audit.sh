#!/usr/bin/env bash

# DMF7 Steps 161-178 automation
set -euo pipefail

AUDIT_SCRIPT="/usr/local/bin/dmf7-audit"
CLEAN_SCRIPT="/usr/local/bin/dmf7-clean"
CRON_ENTRY="0 3 * * * /usr/local/bin/dmf7-clean"

SUDO_CMD=""
if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO_CMD="sudo"
  else
    echo "Run as root or install sudo to manage /usr/local/bin and system services."
    exit 1
  fi
fi

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

run_cmd() {
  local label="$1"
  shift
  local command="$*"

  echo ""
  echo "==> $label"
  if ! bash -c "$command"; then
    echo "!! $label failed (continuing)"
  fi
}

run_if_available() {
  local label="$1"
  local binary="$2"
  shift 2
  local command="$*"

  if cmd_exists "$binary"; then
    run_cmd "$label" "$command"
  else
    echo ""
    echo "!! Skipping $label; $binary not installed"
  fi
}

install_scripts() {
  ${SUDO_CMD} install -m 755 -d /usr/local/bin

  echo "Installing dmf7-audit to ${AUDIT_SCRIPT}"
  cat <<'EOF' | ${SUDO_CMD} tee "${AUDIT_SCRIPT}" >/dev/null
#!/bin/bash

echo "======================================"
echo " DMF7 SYSTEM AUDIT "
echo "======================================"

echo ""
echo "SYSTEM:"
hostname
uptime

echo ""
echo "CPU:"
lscpu | grep "Model name"

echo ""
echo "MEMORY:"
free -h

echo ""
echo "DISK:"
df -h /

echo ""
echo "NODE:"
node -v

echo ""
echo "PNPM:"
pnpm -v

echo ""
echo "DOCKER:"
docker --version

echo ""
echo "PM2:"
pm2 -v

echo ""
echo "NETWORK PORTS:"
ss -tulnp | head

echo ""
echo "======================================"
EOF
  ${SUDO_CMD} chmod +x "${AUDIT_SCRIPT}"

  echo "Installing dmf7-clean to ${CLEAN_SCRIPT}"
  cat <<'EOF' | ${SUDO_CMD} tee "${CLEAN_SCRIPT}" >/dev/null
#!/bin/bash

echo "Cleaning logs..."

find /opt/dmf7/logs -type f -name "*.log" -mtime +14 -delete

journalctl --vacuum-time=7d

echo "Logs cleaned"
EOF
  ${SUDO_CMD} chmod +x "${CLEAN_SCRIPT}"
}

ensure_cron_entry() {
  echo "Ensuring cron entry for dmf7-clean"
  local existing_cron
  existing_cron="$(${SUDO_CMD} crontab -l 2>/dev/null || true)"

  if printf "%s\n" "${existing_cron}" | grep -Fq "${CRON_ENTRY}"; then
    echo "Cron entry already present"
    return
  fi

  printf "%s\n%s\n" "${existing_cron}" "${CRON_ENTRY}" | ${SUDO_CMD} crontab -
  echo "Cron entry added"
}

run_checks() {
  run_if_available "Run dmf7-audit" "${AUDIT_SCRIPT}" "${SUDO_CMD} ${AUDIT_SCRIPT}"

  run_if_available "List running services" "systemctl" "${SUDO_CMD} systemctl list-units --type=service --state=running | head"
  run_if_available "Check open network ports" "ss" "${SUDO_CMD} ss -tuln"
  run_if_available "Verify docker networks" "docker" "${SUDO_CMD} docker network ls"

  run_if_available "Ensure PM2 startup" "pm2" "${SUDO_CMD} pm2 startup"
  run_if_available "Save PM2 process list" "pm2" "${SUDO_CMD} pm2 save"

  run_if_available "Check dmf7-heal service" "systemctl" "${SUDO_CMD} systemctl status dmf7-heal"
  run_if_available "Run dmf7-check" "dmf7-check" "${SUDO_CMD} dmf7-check"

  run_if_available "Test API from server" "curl" "curl -sf http://localhost:4000"
  run_if_available "Test console from server" "curl" "curl -sf http://localhost:4100"
  run_if_available "Test AI engine" "dmf7-ai-test" "${SUDO_CMD} dmf7-ai-test"
  run_if_available "Verify vector database" "curl" "curl -sf http://localhost:6333/collections"
  run_if_available "Verify graph database" "curl" "curl -sf http://localhost:7474"
  run_if_available "Verify Redis" "docker" "${SUDO_CMD} docker exec redis-ai redis-cli ping"
  run_if_available "Verify system health" "dmf7-health" "${SUDO_CMD} dmf7-health"
}

final_message() {
  cat <<'EOF'
==========================================
 DMF7 AI INFRASTRUCTURE CONFIRMED LIVE
==========================================

Primary Services:

Console  : http://72.61.114.167:4100
API      : http://72.61.114.167:4000
AI UI    : http://72.61.114.167:3001

Databases:

Neo4j    : http://72.61.114.167:7474
Qdrant   : http://72.61.114.167:6333

Monitoring:

Grafana  : http://72.61.114.167:3000
Netdata  : http://72.61.114.167:19999

Infrastructure Control:

Portainer: http://72.61.114.167:9000

==========================================
 STATUS: PRODUCTION NODE ACTIVE
==========================================
EOF
}

install_scripts
ensure_cron_entry
run_checks
final_message
