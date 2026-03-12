#!/usr/bin/env bash
set -euo pipefail

VERIFY_RUN=0
if [[ "${1:-}" == "--verify" ]]; then
  VERIFY_RUN=1
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root so /opt and /usr/local/bin can be updated."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get is required to install dependencies (jq, rsync)."
  exit 1
fi

apt_updated=0
apt_update_once() {
  if [[ $apt_updated -eq 0 ]]; then
    apt-get update -y
    apt_updated=1
  fi
}

ensure_package() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    apt_update_once
    apt-get install -y "$pkg"
  fi
}

mkdir -p /opt/dmf7/cluster

cat >/opt/dmf7/cluster/nodes.json <<'EOF'
{
  "nodes": [
    {
      "id": "DMF7-NODE-72-61-114-167",
      "ip": "72.61.114.167",
      "role": "primary-ai-node",
      "status": "online"
    }
  ]
}
EOF

cat >/usr/local/bin/dmf7-discover <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 NODE DISCOVERY "
echo "================================="

cat /opt/dmf7/cluster/nodes.json
EOF
chmod +x /usr/local/bin/dmf7-discover

ensure_package jq

cat >/usr/local/bin/dmf7-cluster-health <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 CLUSTER HEALTH "
echo "================================="

for IP in $(jq -r '.nodes[].ip' /opt/dmf7/cluster/nodes.json)
do
  echo ""
  echo "Checking node: $IP"

  if ping -c 1 "$IP" > /dev/null 2>&1; then
    echo "Node online"
  else
    echo "Node unreachable"
  fi

done
EOF
chmod +x /usr/local/bin/dmf7-cluster-health

ensure_package rsync

cat >/usr/local/bin/dmf7-cluster-sync <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 CLUSTER SYNC "
echo "================================="

LOCAL_IP=$(hostname -I | awk '{print $1}')

for IP in $(jq -r '.nodes[].ip' /opt/dmf7/cluster/nodes.json)
do

  if [ "$IP" != "$LOCAL_IP" ]; then

    echo "Syncing to $IP"

    rsync -avz /opt/dmf7 "$IP:/opt/"

  fi

done
EOF
chmod +x /usr/local/bin/dmf7-cluster-sync

cat >/usr/local/bin/dmf7-cluster <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 CLUSTER STATUS "
echo "================================="

echo ""
if command -v dmf7-node >/dev/null 2>&1; then
  dmf7-node
else
  echo "dmf7-node command not found"
fi

echo ""
echo "Cluster Nodes:"
cat /opt/dmf7/cluster/nodes.json
EOF
chmod +x /usr/local/bin/dmf7-cluster

if [[ $VERIFY_RUN -eq 1 ]]; then
  echo ""
  echo "[verify] Running node discovery..."
  /usr/local/bin/dmf7-discover || true

  echo ""
  echo "[verify] Running cluster health..."
  /usr/local/bin/dmf7-cluster-health || true

  echo ""
  echo "[verify] Running cluster status..."
  /usr/local/bin/dmf7-cluster || true
fi

cat <<'EOF'
======================================================
 DMF7 DISTRIBUTED AI INFRASTRUCTURE READY
======================================================

Primary Node:
72.61.114.167

Cluster Support:
- Node registry
- Discovery
- Health checks
- Sync engine

Command:
dmf7-cluster

STATUS: DISTRIBUTED AI PLATFORM READY
======================================================
EOF
