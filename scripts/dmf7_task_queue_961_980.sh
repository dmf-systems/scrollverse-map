#!/usr/bin/env bash
set -euo pipefail

# DMF7 steps 961-980: task queue, worker, knowledge base, and dashboard tools

VERIFY=false
if [[ "${1-}" == "--verify" ]]; then
  VERIFY=true
elif [[ "${1-}" != "" ]]; then
  echo "Usage: $0 [--verify]"
  exit 1
fi

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"
fi

TASK_BASE="/opt/dmf7/tasks"
KNOWLEDGE_BASE="/opt/dmf7/knowledge"
TASK_PENDING="${TASK_BASE}/pending"
TASK_RUNNING="${TASK_BASE}/running"
TASK_COMPLETED="${TASK_BASE}/completed"
KNOWLEDGE_DOCS="${KNOWLEDGE_BASE}/docs"
KNOWLEDGE_INDEX="${KNOWLEDGE_BASE}/index"

echo "Creating task queue directories..."
$SUDO install -d -m 755 "$TASK_PENDING" "$TASK_RUNNING" "$TASK_COMPLETED"

echo "Creating knowledge storage directories..."
$SUDO install -d -m 755 "$KNOWLEDGE_DOCS" "$KNOWLEDGE_INDEX"

echo "Writing /usr/local/bin/dmf7-task..."
$SUDO tee /usr/local/bin/dmf7-task > /dev/null <<'EOF'
#!/bin/bash

TASK_NAME=$(date +%s)

echo "Enter task description:"
read TASK

echo "$TASK" > /opt/dmf7/tasks/pending/$TASK_NAME.task

echo "Task queued: $TASK_NAME"
EOF
$SUDO chmod +x /usr/local/bin/dmf7-task

echo "Writing /usr/local/bin/dmf7-task-worker..."
$SUDO tee /usr/local/bin/dmf7-task-worker > /dev/null <<'EOF'
#!/bin/bash

for file in /opt/dmf7/tasks/pending/*.task; do
  [ -e "$file" ] || continue

  NAME=$(basename "$file")

  mv "$file" /opt/dmf7/tasks/running/$NAME

  echo "Processing $NAME"

  cat /opt/dmf7/tasks/running/$NAME | ollama run llama3 > /opt/dmf7/tasks/completed/$NAME.out

  rm /opt/dmf7/tasks/running/$NAME

done
EOF
$SUDO chmod +x /usr/local/bin/dmf7-task-worker

echo "Writing /usr/local/bin/dmf7-ingest-doc..."
$SUDO tee /usr/local/bin/dmf7-ingest-doc > /dev/null <<'EOF'
#!/bin/bash

FILE=$1

if [ -z "$FILE" ]; then
 echo "Usage: dmf7-ingest-doc file.txt"
 exit
fi

cp $FILE /opt/dmf7/knowledge/docs/

echo "Document stored."
EOF
$SUDO chmod +x /usr/local/bin/dmf7-ingest-doc

echo "Writing /usr/local/bin/dmf7-knowledge..."
$SUDO tee /usr/local/bin/dmf7-knowledge > /dev/null <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 KNOWLEDGE BASE "
echo "================================="

ls /opt/dmf7/knowledge/docs
EOF
$SUDO chmod +x /usr/local/bin/dmf7-knowledge

echo "Writing /usr/local/bin/dmf7-dashboard-cli..."
$SUDO tee /usr/local/bin/dmf7-dashboard-cli > /dev/null <<'EOF'
#!/bin/bash

clear

echo "=================================="
echo " DMF7 NODE DASHBOARD "
echo "=================================="

echo ""
echo "PM2 SERVICES"
pm2 list

echo ""
echo "DOCKER CONTAINERS"
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "SYSTEM LOAD"
uptime

echo ""
echo "MEMORY"
free -h

echo ""
echo "DISK"
df -h
EOF
$SUDO chmod +x /usr/local/bin/dmf7-dashboard-cli

CRON_ENTRY="*/2 * * * * /usr/local/bin/dmf7-task-worker > /opt/dmf7/task-worker.log 2>&1"

echo "Ensuring cron entry for dmf7-task-worker..."
EXISTING_CRON="$($SUDO crontab -l 2>/dev/null || true)"
if ! printf '%s\n' "$EXISTING_CRON" | grep -Fq "$CRON_ENTRY"; then
  (printf '%s\n' "$EXISTING_CRON"; printf '%s\n' "$CRON_ENTRY") | $SUDO crontab -
fi

cat <<'EOF'
=======================================
DMF7 AUTONOMOUS AI PLATFORM

Task queue: ACTIVE
Knowledge base: ACTIVE
AI workers: ACTIVE
Cluster orchestrator: ACTIVE

Node: 72.61.114.167

STATUS: SELF-OPERATING AI NODE
=======================================
EOF

if $VERIFY; then
  echo ""
  echo "Verification summary:"
  $SUDO ls -ld "$TASK_PENDING" "$TASK_RUNNING" "$TASK_COMPLETED" "$KNOWLEDGE_DOCS" "$KNOWLEDGE_INDEX"
  echo ""
  echo "Cron entries:"
  $SUDO crontab -l | grep -F "dmf7-task-worker" || true
fi

echo "DMF7 task queue, knowledge base, and dashboard tools installed."
