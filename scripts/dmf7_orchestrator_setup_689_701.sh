#!/usr/bin/env bash

set -euo pipefail

ORCHESTRATOR_BIN="/usr/local/bin/dmf7-orchestrator"
SERVICE_FILE="/etc/systemd/system/dmf7-orchestrator.service"
VERSION_DIR="/opt/dmf7"
VERSION_FILE="${VERSION_DIR}/VERSION"
SUMMARY_BIN="/usr/local/bin/dmf7-summary"
MOTD_FILE="/etc/motd"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
  fi
}

require_systemctl() {
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemctl is required to manage the orchestrator service." >&2
    exit 1
  fi
}

write_orchestrator_binary() {
  cat > "${ORCHESTRATOR_BIN}" <<'EOF'
#!/bin/bash

echo "======================================"
echo " DMF7 ORCHESTRATOR "
echo "======================================"

echo ""
echo "Checking core services..."

curl -s http://localhost:4000 > /dev/null
GATEWAY=$?

curl -s http://localhost:4100 > /dev/null
CONSOLE=$?

if [ $GATEWAY -ne 0 ]; then
echo "Gateway offline - restarting"
pm2 restart dmf7-gateway
fi

if [ $CONSOLE -ne 0 ]; then
echo "Console offline - restarting"
pm2 restart dmf7-console
fi

echo ""
echo "Checking containers..."

for C in $(docker ps -a --format "{{.Names}}")
do
STATE=$(docker inspect -f '{{.State.Running}}' $C)

if [ "$STATE" != "true" ]; then
echo "Restarting container $C"
docker restart $C
fi
done

echo ""
echo "DMF7 orchestration check complete."
EOF

  chmod 755 "${ORCHESTRATOR_BIN}"
}

write_service_file() {
  cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=DMF7 Platform Orchestrator
After=network.target docker.service

[Service]
ExecStart=${ORCHESTRATOR_BIN}
Restart=always
RestartSec=60
User=root

[Install]
WantedBy=multi-user.target
EOF
  chmod 644 "${SERVICE_FILE}"
}

write_version_file() {
  install -d -m 755 "${VERSION_DIR}"
  cat > "${VERSION_FILE}" <<'EOF'
DMF7-NEXTGEN-AI-NODE
Version: 1.0
Build: Autonomous AI Infrastructure
EOF
}

write_motd() {
  cat > "${MOTD_FILE}" <<'EOF'
=============================================
 DMF7 NEXTGEN AI NODE
 Autonomous Intelligence Infrastructure
=============================================

Gateway:  http://72.61.114.167
Console:  http://72.61.114.167/console
AI UI:    http://72.61.114.167/ai

Control:  dmf7-control
Dashboard: dmf7-live

=============================================
EOF
}

write_summary_binary() {
  cat > "${SUMMARY_BIN}" <<'EOF'
#!/bin/bash

echo "=================================="
echo " DMF7 PLATFORM SUMMARY "
echo "=================================="

echo ""
cat /opt/dmf7/VERSION

echo ""
echo "Node:"
hostname -I

echo ""
echo "Services:"
pm2 list

echo ""
echo "Containers:"
docker ps
EOF
  chmod 755 "${SUMMARY_BIN}"
}

enable_orchestrator_service() {
  systemctl daemon-reload
  systemctl enable dmf7-orchestrator
  systemctl start dmf7-orchestrator
}

run_summary_once() {
  if command -v "${SUMMARY_BIN}" >/dev/null 2>&1; then
    set +e
    "${SUMMARY_BIN}" || echo "dmf7-summary encountered issues (check pm2/docker availability)."
    set -e
  fi
}

final_activation_banner() {
  cat <<'EOF'
====================================================
 DMF7 GLOBAL AI SUPER NODE ONLINE
====================================================

Node:
72.61.114.167

Capabilities:
- AI Runtime
- Redis Worker Queue
- Vector Search
- Graph Intelligence
- Monitoring
- Self-Healing
- Orchestrated Infrastructure

Control:
dmf7-control

STATUS: AUTONOMOUS INTELLIGENCE NODE ACTIVE
====================================================
EOF
}

main() {
  require_root
  require_systemctl
  write_orchestrator_binary
  write_service_file
  write_version_file
  write_motd
  write_summary_binary
  enable_orchestrator_service
  run_summary_once
  final_activation_banner
}

main "$@"
