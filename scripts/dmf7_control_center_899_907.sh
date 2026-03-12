#!/usr/bin/env bash
set -euo pipefail

SUDO_BIN="${SUDO:-sudo}"
DMF7_BIN="/usr/local/bin/dmf7"
SERVICE_FILE="/etc/systemd/system/dmf7.service"
NODE_INFO="/opt/dmf7/NODE_INFO.txt"

ensure_root_tools() {
  if ! command -v "${SUDO_BIN}" >/dev/null 2>&1; then
    echo "sudo is required to install system-wide DMF7 helpers." >&2
    exit 1
  fi
}

write_control_menu() {
  echo "Installing DMF7 control menu at ${DMF7_BIN}"
  ${SUDO_BIN} tee "${DMF7_BIN}" >/dev/null <<'EOF'
#!/bin/bash

clear

echo "========================================"
echo "        DMF7 CONTROL CENTER"
echo "========================================"
echo ""
echo "1  - Platform Status"
echo "2  - System Monitor"
echo "3  - Diagnostics"
echo "4  - Restart Platform"
echo "5  - Maintenance Mode"
echo "6  - Exit Maintenance"
echo "7  - Backup System"
echo "8  - GitHub Sync"
echo "9  - Upgrade Platform"
echo "10 - AI Console"
echo "11 - Install AI Model"
echo "12 - AI Pipeline Test"
echo "13 - View Logs"
echo "14 - Docker Containers"
echo "15 - PM2 Services"
echo "16 - Exit"
echo ""
echo "========================================"
read -p "Select option: " choice

case $choice in

1) dmf7-platform ;;
2) dmf7-monitor ;;
3) dmf7-diagnostics ;;
4) dmf7-reset ;;
5) dmf7-maintenance ;;
6) dmf7-maintenance-exit ;;
7) dmf7-backup ;;
8) dmf7-sync ;;
9) dmf7-upgrade ;;
10) dmf7-ai ;;
11) read -p "Model name: " model; dmf7-install-model "$model" ;;
12) dmf7-ai-test ;;
13) pm2 logs ;;
14) docker ps ;;
15) pm2 list ;;
16) exit ;;

*) echo "Invalid option" ;;

esac
EOF
  ${SUDO_BIN} chmod +x "${DMF7_BIN}"
}

write_service_unit() {
  echo "Configuring systemd service at ${SERVICE_FILE}"
  ${SUDO_BIN} tee "${SERVICE_FILE}" >/dev/null <<'EOF'
[Unit]
Description=DMF7 Platform Auto Start
After=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/dmf7-start-all
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

  if command -v systemctl >/dev/null 2>&1; then
    ${SUDO_BIN} systemctl daemon-reload
    ${SUDO_BIN} systemctl enable dmf7
    ${SUDO_BIN} systemctl restart dmf7
  else
    echo "systemctl not found; skipping enable/start. Please configure manually." >&2
  fi
}

write_node_info() {
  echo "Writing node info to ${NODE_INFO}"
  ${SUDO_BIN} mkdir -p "$(dirname "${NODE_INFO}")"
  ${SUDO_BIN} tee "${NODE_INFO}" >/dev/null <<'EOF'
DMF7 GLOBAL NODE

IP: 72.61.114.167
HOSTNAME: srv1111819

SERVICES

Gateway API
Operator Console
Redis Worker Queue
Ollama AI Runtime
Qdrant Vector Database
Neo4j Graph Database

Monitoring

Netdata
Glances
cAdvisor
Node Exporter
Grafana

Management Commands

dmf7
dmf7-platform
dmf7-monitor
dmf7-diagnostics
dmf7-reset
dmf7-sync
dmf7-backup
dmf7-ai
EOF
}

print_final_status() {
  cat <<'EOF'
========================================
DMF7 GLOBAL AI PLATFORM

Control Center:
dmf7

Public Access:
http://72.61.114.167

API:
http://72.61.114.167/api

AI Interface:
http://72.61.114.167/ai

Vector DB:
http://72.61.114.167:6333

Graph DB:
http://72.61.114.167:7474

STATUS: FULLY DEPLOYED
========================================
EOF
}

main() {
  ensure_root_tools
  write_control_menu
  write_service_unit
  write_node_info
  print_final_status
}

main "$@"
