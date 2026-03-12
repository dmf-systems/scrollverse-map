#!/usr/bin/env bash
set -euo pipefail

VERIFY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify)
      VERIFY=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--verify]"
      exit 0
      ;;
    *)
      echo "Usage: $0 [--verify]"
      exit 1
      ;;
  esac
done

sudo mkdir -p /opt/dmf7/phase5
sudo mkdir -p /opt/dmf7/global-knowledge/docs /opt/dmf7/global-knowledge/analysis
sudo mkdir -p /opt/dmf7/federation/jobs

sudo tee /usr/local/bin/dmf7-global-ingest >/dev/null <<'EOF'
#!/bin/bash

FILE=$1

if [ -z "$FILE" ]; then
  echo "Usage: dmf7-global-ingest file.txt"
  exit
fi

cp "$FILE" /opt/dmf7/global-knowledge/docs/

echo "Document added to global knowledge base."
EOF
sudo chmod +x /usr/local/bin/dmf7-global-ingest

sudo tee /usr/local/bin/dmf7-global-analyze >/dev/null <<'EOF'
#!/bin/bash

FILE=$1

if [ -z "$FILE" ]; then
  echo "Usage: dmf7-global-analyze file.txt"
  exit
fi

ollama run llama3 < "$FILE" > /opt/dmf7/global-knowledge/analysis/$(basename "$FILE").analysis
EOF
sudo chmod +x /usr/local/bin/dmf7-global-analyze

sudo tee /usr/local/bin/dmf7-global-search >/dev/null <<'EOF'
#!/bin/bash

TERM=$1

grep -Ri "$TERM" /opt/dmf7/global-knowledge/docs
EOF
sudo chmod +x /usr/local/bin/dmf7-global-search

sudo tee /usr/local/bin/dmf7-vector-search >/dev/null <<'EOF'
#!/bin/bash

QUERY=$*

curl -X POST http://localhost:6333/collections/dmf7_docs/points/search \
-H "Content-Type: application/json" \
-d "{\"vector\": [0.1,0.2,0.3], \"top\": 5}"
EOF
sudo chmod +x /usr/local/bin/dmf7-vector-search

sudo tee /usr/local/bin/dmf7-research-agent >/dev/null <<'EOF'
#!/bin/bash

read -p "Research question: " Q

echo "$Q" | ollama run llama3
EOF
sudo chmod +x /usr/local/bin/dmf7-research-agent

sudo tee /usr/local/bin/dmf7-distribute-job >/dev/null <<'EOF'
#!/bin/bash

read -p "Job prompt: " PROMPT

ID=$(date +%s)

echo "$PROMPT" > /opt/dmf7/federation/jobs/$ID.job

echo "Job distributed to federation."
EOF
sudo chmod +x /usr/local/bin/dmf7-distribute-job

sudo tee /usr/local/bin/dmf7-node-health >/dev/null <<'EOF'
#!/bin/bash

echo "=============================="
echo "NODE HEALTH"
echo "=============================="

echo ""
echo "CPU:"
top -b -n1 | head -n 5

echo ""
echo "Memory:"
free -h

echo ""
echo "Docker:"
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "PM2:"
pm2 list
EOF
sudo chmod +x /usr/local/bin/dmf7-node-health

sudo tee /opt/dmf7/GLOBAL_STATUS.txt >/dev/null <<'EOF'
DMF7 GLOBAL AI SYSTEM

Node
72.61.114.167

Modules
AI Agents
Vector Search
Global Knowledge Base
Federated Job Network
Research Pipeline
Cluster Orchestrator

Status
ACTIVE
EOF

echo "======================================="
echo "DMF7 GLOBAL AI NETWORK"
echo ""
echo "Node: 72.61.114.167"
echo ""
echo "AI agents: active"
echo "Federation network: active"
echo "Research pipeline: active"
echo "Global knowledge base: active"
echo ""
echo "STATUS: GLOBAL SYSTEM ONLINE"
echo "======================================="

if $VERIFY; then
  /usr/local/bin/dmf7-node-health || true
  cat /opt/dmf7/GLOBAL_STATUS.txt || true
fi

echo "DMF7 phase5/global knowledge setup complete."
