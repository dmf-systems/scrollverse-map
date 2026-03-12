#!/usr/bin/env bash

# DMF7 steps 927-942: service map and tooling provisioner.
# Creates service manifest, status/log/performance/network/security helpers,
# node summary, and prints final report. Safe to re-run; optional --verify
# runs the helper commands after installation.

set -euo pipefail

SUDO=""
if [[ ${EUID:-0} -ne 0 ]]; then
  SUDO="sudo"
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

write_file() {
  local path="$1"
  local contents="$2"
  $SUDO mkdir -p "$(dirname "$path")"
  printf "%s" "$contents" | $SUDO tee "$path" >/dev/null
}

make_executable() {
  local path="$1"
  $SUDO chmod +x "$path"
}

create_services_json() {
  local path="/opt/dmf7/services/services.json"
  local contents='{
  "services": [
    {"name":"gateway","port":4000,"type":"api"},
    {"name":"console","port":4100,"type":"ui"},
    {"name":"open-webui","port":3001,"type":"ai-ui"},
    {"name":"qdrant","port":6333,"type":"vector-db"},
    {"name":"neo4j","port":7474,"type":"graph-db"},
    {"name":"grafana","port":3000,"type":"metrics"},
    {"name":"portainer","port":9000,"type":"docker"}
  ]
}
'
  write_file "$path" "$contents"
}

create_services_tool() {
  local path="/usr/local/bin/dmf7-services"
  local contents='#!/bin/bash

echo "================================="
echo " DMF7 SERVICE STATUS "
echo "================================="

jq -r '"'"'.services[] | "\(.name) : \(.port)"'"'"' /opt/dmf7/services/services.json

echo ""
echo "Running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "PM2 processes:"
pm2 list
'
  write_file "$path" "$contents"
  make_executable "$path"
}

create_logs_tool() {
  local path="/usr/local/bin/dmf7-logs"
  local contents='#!/bin/bash

echo "================================="
echo " DMF7 LIVE LOGS "
echo "================================="

pm2 logs --lines 50
'
  write_file "$path" "$contents"
  make_executable "$path"
}

create_performance_tool() {
  local path="/usr/local/bin/dmf7-performance"
  local contents='#!/bin/bash

echo "================================="
echo " DMF7 PERFORMANCE "
echo "================================="

echo ""
echo "CPU / MEMORY"
top -b -n1 | head -n 12

echo ""
echo "DISK"
df -h

echo ""
echo "DOCKER STATS"
docker stats --no-stream
'
  write_file "$path" "$contents"
  make_executable "$path"
}

create_network_tool() {
  local path="/usr/local/bin/dmf7-network"
  local contents='#!/bin/bash

echo "================================="
echo " DMF7 NETWORK STATUS "
echo "================================="

echo "IP:"
hostname -I

echo ""
echo "Open ports:"
ss -tulnp

echo ""
echo "External connectivity:"
ping -c 2 8.8.8.8
'
  write_file "$path" "$contents"
  make_executable "$path"
}

create_security_tool() {
  local path="/usr/local/bin/dmf7-security"
  local contents='#!/bin/bash

echo "================================="
echo " DMF7 SECURITY STATUS "
echo "================================="

echo ""
echo "Firewall:"
ufw status

echo ""
echo "Fail2Ban:"
fail2ban-client status

echo ""
echo "Updates:"
apt list --upgradable
'
  write_file "$path" "$contents"
  make_executable "$path"
}

create_summary() {
  local path="/opt/dmf7/NODE_SUMMARY.txt"
  local contents='DMF7 AI NODE SUMMARY

IP
72.61.114.167

STACK
Gateway API
Operator Console
Redis Worker Queue
Ollama AI Runtime
Qdrant Vector Database
Neo4j Graph Database

OBSERVABILITY
Netdata
Glances
cAdvisor
Grafana

DEVOPS
Docker
PM2
GitHub Sync
Copilot Agents

CLUSTER
Cluster Engine
Orchestrator
AI Worker Queue

STATUS
ACTIVE
'
  write_file "$path" "$contents"
}

final_report() {
  cat <<'EOF'
=======================================
DMF7 NODE STATUS REPORT

Public Console:
http://72.61.114.167

AI Interface:
http://72.61.114.167/ai

Vector Database:
http://72.61.114.167:6333

Graph Database:
http://72.61.114.167:7474

Metrics:
http://72.61.114.167:3000

Docker:
http://72.61.114.167:9000

STATUS: OPERATIONAL
=======================================
EOF
}

verify_tools() {
  local missing=0
  for cmd in jq docker pm2 top df ss ping ufw fail2ban-client; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Warning: $cmd not found; related checks may be unavailable." >&2
      missing=1
    fi
  done

  echo "Services JSON:"
  $SUDO cat /opt/dmf7/services/services.json || true
  echo ""
  echo "Running dmf7-services:"
  (dmf7-services || true)
  echo ""
  echo "Running dmf7-security:"
  (dmf7-security || true)
  echo ""
  echo "Node summary:"
  $SUDO cat /opt/dmf7/NODE_SUMMARY.txt || true

  if [[ $missing -eq 1 ]]; then
    echo ""
    echo "Note: Some tools were not found; install them for full output."
  fi
}

main() {
  local verify=0
  if [[ $# -gt 0 ]]; then
    case "$1" in
      --verify) verify=1 ;;
      *) echo "Usage: $0 [--verify]" ; exit 1 ;;
    esac
  fi

  require_cmd tee
  create_services_json
  create_services_tool
  create_logs_tool
  create_performance_tool
  create_network_tool
  create_security_tool
  create_summary
  final_report

  if [[ $verify -eq 1 ]]; then
    echo ""
    echo "Running verification..."
    verify_tools
  fi
}

main "$@"
