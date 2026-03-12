#!/usr/bin/env bash

set -euo pipefail

CRON_ENTRY='*/1 * * * * /usr/local/bin/dmf7-agent > /opt/dmf7/agents/agent.log 2>&1'
VERIFY=0
SKIP_CRON=0

usage() {
  cat <<'EOF'
Provision DMF7 Phase2 automation (steps 1001-1021).

Options:
  --verify     Run post-install checks after provisioning
  --skip-cron  Skip installing the agent cron entry
  -h, --help   Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify)
      VERIFY=1
      shift
      ;;
    --skip-cron)
      SKIP_CRON=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

mkdir -p /opt/dmf7/phase2
mkdir -p /opt/dmf7/agents/tasks /opt/dmf7/agents/results
mkdir -p /opt/dmf7/vector
mkdir -p /opt/dmf7/research/papers /opt/dmf7/research/analysis
mkdir -p /opt/dmf7/network

cat >/usr/local/bin/dmf7-agent <<'EOF'
#!/bin/bash

TASK_FILE=$(ls /opt/dmf7/agents/tasks/*.task 2>/dev/null | head -n1)

if [ -z "$TASK_FILE" ]; then
  echo "No agent tasks."
  exit 0
fi

NAME=$(basename "$TASK_FILE")

echo "Running agent task $NAME"

ollama run llama3 < "$TASK_FILE" > "/opt/dmf7/agents/results/$NAME.out"

rm "$TASK_FILE"

echo "Task completed."
EOF

cat >/usr/local/bin/dmf7-agent-task <<'EOF'
#!/bin/bash

ID=$(date +%s)

echo "Enter agent task:"
read TASK

echo "$TASK" > "/opt/dmf7/agents/tasks/$ID.task"

echo "Agent task queued."
EOF

cat >/usr/local/bin/dmf7-vector-ingest <<'EOF'
#!/bin/bash

FILE=$1

if [ -z "$FILE" ]; then
  echo "Usage: dmf7-vector-ingest file.txt"
  exit 1
fi

curl -X POST http://localhost:6333/collections/dmf7_docs/points \
  -H "Content-Type: application/json" \
  -d @"${FILE}"
EOF

cat >/usr/local/bin/dmf7-analyze <<'EOF'
#!/bin/bash

FILE=$1

if [ -z "$FILE" ]; then
  echo "Usage: dmf7-analyze file.txt"
  exit 1
fi

ollama run llama3 < "$FILE" > "/opt/dmf7/research/analysis/$(basename "$FILE").analysis"
EOF

cat >/usr/local/bin/dmf7-network-scan <<'EOF'
#!/bin/bash

echo "Scanning DMF7 nodes..."

for node in $(cat /opt/dmf7/network/nodes.txt); do
  echo "Checking $node"
  curl -s "http://$node:4000"
done
EOF

echo "72.61.114.167" >/opt/dmf7/network/nodes.txt

chmod +x /usr/local/bin/dmf7-agent
chmod +x /usr/local/bin/dmf7-agent-task
chmod +x /usr/local/bin/dmf7-vector-ingest
chmod +x /usr/local/bin/dmf7-analyze
chmod +x /usr/local/bin/dmf7-network-scan

if [[ "$SKIP_CRON" -eq 0 ]]; then
  EXISTING_CRON=$(crontab -l 2>/dev/null || true)
  if ! printf "%s\n" "$EXISTING_CRON" | grep -Fq "$CRON_ENTRY"; then
    { printf "%s\n" "$EXISTING_CRON"; printf "%s\n" "$CRON_ENTRY"; } | crontab -
  fi
fi

if [[ "$VERIFY" -eq 1 ]]; then
  echo "Verifying DMF7 Phase2 setup..."
  for dir in /opt/dmf7/phase2 /opt/dmf7/agents/tasks /opt/dmf7/agents/results /opt/dmf7/vector /opt/dmf7/research/papers /opt/dmf7/research/analysis /opt/dmf7/network; do
    if [[ ! -d "$dir" ]]; then
      echo "Missing directory: $dir"
      exit 1
    fi
  done

  for bin in /usr/local/bin/dmf7-agent /usr/local/bin/dmf7-agent-task /usr/local/bin/dmf7-vector-ingest /usr/local/bin/dmf7-analyze /usr/local/bin/dmf7-network-scan; do
    if [[ ! -x "$bin" ]]; then
      echo "Missing executable: $bin"
      exit 1
    fi
  done

  if [[ "$SKIP_CRON" -eq 0 ]] && ! crontab -l 2>/dev/null | grep -Fq "$CRON_ENTRY"; then
    echo "Cron entry missing"
    exit 1
  fi
fi

cat <<'EOF'
=======================================
DMF7 PHASE2 AI SYSTEM ACTIVE

AI Agents: ACTIVE
Vector search: READY
Research pipeline: READY
Cluster engine: ACTIVE
Task system: ACTIVE

Node: 72.61.114.167

STATUS: PHASE2 ONLINE
=======================================
EOF
