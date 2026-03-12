#!/usr/bin/env bash

set -euo pipefail

if [[ ${EUID:-0} -ne 0 ]]; then
  echo "This installer must run as root (try sudo)."
  exit 1
fi

VERIFY=0
if [[ "${1:-}" == "--verify" ]]; then
  VERIFY=1
fi

CLUSTER_DIR="/opt/dmf7/cluster"
NODES_FILE="${CLUSTER_DIR}/nodes.json"
ORCH_LOG="/opt/dmf7/orchestrator.log"
AI_QUEUE="/opt/dmf7/ai-jobs/queue"
AI_RESULTS="/opt/dmf7/ai-jobs/results"
AI_LOG="/opt/dmf7/ai-worker.log"

ensure_dir() {
  install -d -m 755 "$1"
}

write_nodes_registry() {
  cat >"${NODES_FILE}" <<'EOF'
{
  "nodes": [
    {
      "id": "dmf7-node-01",
      "ip": "72.61.114.167",
      "role": "primary",
      "status": "online"
    }
  ]
}
EOF
}

write_cluster_tool() {
  cat >/usr/local/bin/dmf7-cluster <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 CLUSTER STATUS "
echo "================================="

cat /opt/dmf7/cluster/nodes.json
EOF
  chmod 755 /usr/local/bin/dmf7-cluster
}

write_add_node_tool() {
  cat >/usr/local/bin/dmf7-add-node <<'EOF'
#!/bin/bash

NODE_IP=$1

if [ -z "$NODE_IP" ]; then
  echo "Usage: dmf7-add-node <node-ip>"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to add nodes. Please install jq."
  exit 1
fi

echo "Registering node $NODE_IP"

jq '.nodes += [{"id":"dmf7-node","ip":"'"$NODE_IP"'","role":"worker","status":"online"}]' \
  /opt/dmf7/cluster/nodes.json > /opt/dmf7/cluster/tmp.json

mv /opt/dmf7/cluster/tmp.json /opt/dmf7/cluster/nodes.json

echo "Node added."
EOF
  chmod 755 /usr/local/bin/dmf7-add-node
}

write_orchestrator() {
  cat >/usr/local/bin/dmf7-orchestrator <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 CLUSTER ORCHESTRATOR "
echo "================================="

echo "Checking services..."

if command -v pm2 >/dev/null 2>&1; then
  pm2 list
else
  echo "pm2 not installed"
fi

if command -v docker >/dev/null 2>&1; then
  docker ps
else
  echo "docker not installed"
fi

echo "Cluster nodes:"
cat /opt/dmf7/cluster/nodes.json

echo "Orchestrator run complete."
EOF
  chmod 755 /usr/local/bin/dmf7-orchestrator
}

write_ai_worker() {
  cat >/usr/local/bin/dmf7-ai-worker <<'EOF'
#!/bin/bash

echo "Scanning AI job queue..."

for file in /opt/dmf7/ai-jobs/queue/*.txt; do
  [ -e "$file" ] || continue

  NAME=$(basename "$file")

  echo "Processing $NAME"

  ollama run llama3 < "$file" > /opt/dmf7/ai-jobs/results/$NAME.out

  rm "$file"

done

echo "Worker finished."
EOF
  chmod 755 /usr/local/bin/dmf7-ai-worker
}

upsert_cron_entry() {
  local entry=$1
  local current
  current=$(crontab -l 2>/dev/null || true)

  if echo "$current" | grep -Fq "$entry"; then
    return
  fi

  {
    [ -n "$current" ] && printf "%s\n" "$current"
    printf "%s\n" "$entry"
  } | crontab -
}

print_banner() {
  cat <<'EOF'
=======================================
DMF7 CLUSTER CONTROL ACTIVE

Node:
72.61.114.167

Cluster commands:
dmf7-cluster
dmf7-add-node
dmf7-orchestrator

AI Worker:
dmf7-ai-worker

STATUS: CLUSTER ENGINE ACTIVE
=======================================
EOF
}

echo "[908] Creating cluster directory..."
ensure_dir "$CLUSTER_DIR"

echo "[909] Writing node registry..."
write_nodes_registry

echo "[910-912] Installing cluster status tool..."
write_cluster_tool

echo "[913-914] Installing add-node tool..."
write_add_node_tool

echo "[915-917] Installing orchestrator..."
write_orchestrator

echo "[918-919] Registering orchestrator cron (every 10 minutes)..."
upsert_cron_entry "*/10 * * * * /usr/local/bin/dmf7-orchestrator > ${ORCH_LOG} 2>&1"

echo "[920] Creating AI job directories..."
ensure_dir "$AI_QUEUE"
ensure_dir "$AI_RESULTS"

echo "[921-923] Installing AI worker..."
write_ai_worker

echo "[924-925] Registering AI worker cron (every 5 minutes)..."
upsert_cron_entry "*/5 * * * * /usr/local/bin/dmf7-ai-worker > ${AI_LOG} 2>&1"

if [[ $VERIFY -eq 1 ]]; then
  echo "Running verification commands..."
  /usr/local/bin/dmf7-cluster || true
  /usr/local/bin/dmf7-orchestrator || true
  /usr/local/bin/dmf7-ai-worker || true
fi

print_banner
