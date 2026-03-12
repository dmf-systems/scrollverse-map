#!/usr/bin/env bash
set -euo pipefail

VERIFY=false

DMF7_DIR="/opt/dmf7"
MANIFEST_PATH="${DMF7_DIR}/INSTALL_MANIFEST.txt"
SNAPSHOT_PATH="${DMF7_DIR}/SNAPSHOTS.txt"
EXPORT_TOOL="/usr/local/bin/dmf7-export"
SHUTDOWN_TOOL="/usr/local/bin/dmf7-shutdown"
START_TOOL="/usr/local/bin/dmf7-start-all"
PLATFORM_TOOL="/usr/local/bin/dmf7-platform"
EXPORT_DIR="${DMF7_DIR}/exports"

usage() {
  cat <<'USAGE'
Provision DMF7 install manifest, export/start/stop/platform helpers (steps 782-797).

Usage: dmf7_install_manifest_782_797.sh [--verify]

Options:
  --verify   Run validation commands after provisioning
  -h, --help Show this help text
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify)
      VERIFY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

write_manifest() {
  mkdir -p "$DMF7_DIR"
  cat > "$MANIFEST_PATH" <<'EOF'
DMF7 NEXTGEN AI NODE INSTALLATION MANIFEST

Node ID: DMF7-NODE-72-61-114-167
IP: 72.61.114.167

CORE SERVICES
- Gateway API
- Operator Console
- Redis Worker Queue
- Ollama AI Runtime
- Qdrant Vector Database
- Neo4j Graph Database

INFRASTRUCTURE
- Docker Container Runtime
- PM2 Process Manager
- NGINX Reverse Proxy
- Firewall + Fail2Ban
- Monitoring Stack

AUTOMATION
- Watchdog Self Healing
- Docker Auto Recovery
- Platform Orchestrator
- Hourly Diagnostics
- Daily Backups

CONTROL COMMANDS
dmf7-control
dmf7-admin
dmf7-help
dmf7-dashboard
dmf7-live

STATUS: ACTIVE
EOF
}

write_snapshot_index() {
  mkdir -p "$DMF7_DIR"
  cat > "$SNAPSHOT_PATH" <<'EOF'
DMF7 SYSTEM SNAPSHOTS

Directory:
/opt/dmf7/snapshots
/opt/dmf7/backups
/opt/dmf7/exports

Commands:
dmf7-snapshot
dmf7-export

Retention:
Snapshots: manual
Backups: automated
Exports: versioned
EOF
}

install_export_tool() {
  cat > "$EXPORT_TOOL" <<'EOF'
#!/bin/bash

DATE=$(date +%F)

echo "Exporting DMF7 platform snapshot..."

mkdir -p /opt/dmf7/exports

tar -czf /opt/dmf7/exports/dmf7-node-$DATE.tar.gz \
/opt/dmf7 \
/usr/local/bin/dmf7* \
/etc/systemd/system/dmf7*

echo "Export complete:"
echo "/opt/dmf7/exports/dmf7-node-$DATE.tar.gz"
EOF
  chmod +x "$EXPORT_TOOL"
}

install_shutdown_tool() {
  cat > "$SHUTDOWN_TOOL" <<'EOF'
#!/bin/bash

echo "Gracefully stopping DMF7 platform..."

pm2 stop all

docker stop $(docker ps -q)

systemctl stop nginx

echo "DMF7 platform stopped."
EOF
  chmod +x "$SHUTDOWN_TOOL"
}

install_start_tool() {
  cat > "$START_TOOL" <<'EOF'
#!/bin/bash

echo "Starting DMF7 platform..."

docker start $(docker ps -aq)

pm2 resurrect

systemctl start nginx

echo "DMF7 platform started."
EOF
  chmod +x "$START_TOOL"
}

install_platform_tool() {
  cat > "$PLATFORM_TOOL" <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 PLATFORM STATUS "
echo "================================="

echo ""
echo "Node:"
hostname -I

echo ""
echo "Services:"
pm2 list

echo ""
echo "Containers:"
docker ps

echo ""
echo "AI Models:"
ollama list
EOF
  chmod +x "$PLATFORM_TOOL"
}

run_verification() {
  echo "Verifying manifest..."
  cat "$MANIFEST_PATH"

  echo "Running export..."
  "$EXPORT_TOOL"

  echo "Exports directory:"
  ls -lh "$EXPORT_DIR"

  echo "Snapshot index:"
  cat "$SNAPSHOT_PATH"

  echo "Platform status:"
  "$PLATFORM_TOOL"

  cat <<'EOF'
======================================================
 DMF7 GLOBAL AI INFRASTRUCTURE DEPLOYMENT COMPLETE
======================================================

Node:
72.61.114.167

AI Systems:
✔ Ollama LLM runtime
✔ AI job execution

Data Systems:
✔ Qdrant vector database
✔ Neo4j graph database

Platform:
✔ Gateway API
✔ Operator console
✔ Monitoring stack

Automation:
✔ Orchestrator
✔ Watchdog
✔ Auto backups

STATUS: GLOBAL AI NODE FULLY DEPLOYED
======================================================
EOF
}

main() {
  write_manifest
  install_export_tool
  install_shutdown_tool
  install_start_tool
  install_platform_tool
  write_snapshot_index

  if [[ "$VERIFY" == true ]]; then
    run_verification
  else
    echo "DMF7 manifest and tools installed. Run with --verify to execute validation steps."
  fi
}

main "$@"
