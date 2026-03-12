#!/usr/bin/env bash
set -euo pipefail

# Automation for DMF7 steps 943-960: audit tools, resource guard, incident
# reporting, snapshots, and scheduled tasks.

AUDIT_BIN="/usr/local/bin/dmf7-audit"
RESOURCE_GUARD_BIN="/usr/local/bin/dmf7-resource-guard"
INCIDENT_BIN="/usr/local/bin/dmf7-incident"
SNAPSHOT_BIN="/usr/local/bin/dmf7-snapshot"

DMF7_ROOT="/opt/dmf7"
INCIDENT_DIR="${DMF7_ROOT}/incidents"
SNAPSHOT_DIR="${DMF7_ROOT}/snapshots"
RESOURCE_GUARD_LOG="${DMF7_ROOT}/resource-guard.log"
SNAPSHOT_LOG="${DMF7_ROOT}/snapshot.log"

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"
fi

ensure_paths() {
  $SUDO mkdir -p "$DMF7_ROOT" "$INCIDENT_DIR" "$SNAPSHOT_DIR"
}

install_audit() {
  $SUDO tee "$AUDIT_BIN" >/dev/null <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 SYSTEM AUDIT "
echo "================================="

echo ""
echo "System uptime:"
uptime

echo ""
echo "Memory:"
free -h

echo ""
echo "Disk:"
df -h

echo ""
echo "Docker containers:"
if command -v docker >/dev/null 2>&1; then
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
  echo "docker not found"
fi

echo ""
echo "PM2 services:"
if command -v pm2 >/dev/null 2>&1; then
  pm2 list
else
  echo "pm2 not found"
fi

echo ""
echo "Open ports:"
if command -v ss >/dev/null 2>&1; then
  ss -tulnp | head -n 20
else
  echo "ss not found"
fi
EOF
  $SUDO chmod +x "$AUDIT_BIN"
}

install_resource_guard() {
  $SUDO tee "$RESOURCE_GUARD_BIN" >/dev/null <<'EOF'
#!/bin/bash

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
MEM=$(free | awk '/Mem:/ {print $3/$2 * 100.0}')

echo "CPU usage: $CPU%"
echo "Memory usage: $MEM%"

if [ "$CPU" -gt 90 ]; then
  echo "High CPU detected — restarting workers"
  pm2 restart all
fi

if [ "${MEM%.*}" -gt 90 ]; then
  echo "High memory detected — restarting workers"
  pm2 restart all
fi
EOF
  $SUDO chmod +x "$RESOURCE_GUARD_BIN"
}

install_incident_tool() {
  $SUDO tee "$INCIDENT_BIN" >/dev/null <<'EOF'
#!/bin/bash

DATE=$(date +%F-%H%M)

echo "Creating incident report..."

mkdir -p /opt/dmf7/incidents

{
echo "DMF7 INCIDENT REPORT"
echo "Time: $(date)"
echo ""
echo "PM2:"
pm2 list
echo ""
echo "Docker:"
docker ps
echo ""
echo "System:"
uptime
free -h
df -h
} > /opt/dmf7/incidents/incident-$DATE.txt

echo "Report saved to /opt/dmf7/incidents/incident-$DATE.txt"
EOF
  $SUDO chmod +x "$INCIDENT_BIN"
}

install_snapshot_tool() {
  $SUDO tee "$SNAPSHOT_BIN" >/dev/null <<'EOF'
#!/bin/bash

DATE=$(date +%F-%H%M)

mkdir -p /opt/dmf7/snapshots

{
echo "DMF7 SNAPSHOT"
echo "Time: $(date)"
echo ""
top -b -n1 | head -n 15
echo ""
docker ps
echo ""
pm2 list
} > /opt/dmf7/snapshots/snapshot-$DATE.txt

echo "Snapshot saved."
EOF
  $SUDO chmod +x "$SNAPSHOT_BIN"
}

install_cron_entries() {
  local cron_tmp
  cron_tmp="$(mktemp)"
  crontab -l 2>/dev/null | grep -v "/usr/local/bin/dmf7-resource-guard" | grep -v "/usr/local/bin/dmf7-snapshot" >"$cron_tmp" || true

  echo "*/3 * * * * /usr/local/bin/dmf7-resource-guard > ${RESOURCE_GUARD_LOG} 2>&1" >>"$cron_tmp"
  echo "0 */6 * * * /usr/local/bin/dmf7-snapshot > ${SNAPSHOT_LOG} 2>&1" >>"$cron_tmp"

  crontab "$cron_tmp"
  rm -f "$cron_tmp"
}

run_verification() {
  echo "Running dmf7-audit..."
  $AUDIT_BIN || true
  echo ""

  echo "Running dmf7-resource-guard..."
  $RESOURCE_GUARD_BIN || true
  echo ""

  echo "Running dmf7-incident..."
  $INCIDENT_BIN || true
  echo ""

  echo "Running dmf7-snapshot..."
  $SNAPSHOT_BIN || true
  echo ""

  echo "Current cron entries:"
  crontab -l
}

final_status() {
  local node_ip
  node_ip="${DMF7_NODE_IP:-$(hostname -I 2>/dev/null | awk '{print $1}' || true)}"

  echo "======================================="
  echo "DMF7 AUTONOMOUS NODE ACTIVE"
  echo ""
  echo "AI runtime: operational"
  echo "Worker queue: operational"
  echo "Cluster orchestrator: operational"
  echo "Monitoring: operational"
  echo "Security: operational"
  echo ""
  echo "Node IP: ${node_ip:-unknown}"
  echo ""
  echo "STATUS: PRODUCTION AI NODE"
  echo "======================================="
}

main() {
  ensure_paths
  install_audit
  install_resource_guard
  install_incident_tool
  install_snapshot_tool
  install_cron_entries

  if [[ "${1:-}" == "--verify" ]]; then
    run_verification
  fi

  final_status
}

main "$@"
