#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Please run as root (sudo) to install DMF7 agent memory tools."
  exit 1
fi

PHASE_DIR="/opt/dmf7/phase3"
MEMORY_DIR="/opt/dmf7/agents/memory"
TASK_DIR="/opt/dmf7/agents/tasks"

mkdir -p "${PHASE_DIR}" "${MEMORY_DIR}" "${TASK_DIR}"

cat <<'EOF' > /usr/local/bin/dmf7-agent-memory
#!/bin/bash
set -euo pipefail

ID=$(date +%s)

echo "Enter memory note:"
read -r NOTE

mkdir -p /opt/dmf7/agents/memory
echo "$NOTE" > /opt/dmf7/agents/memory/memory.log

echo "Memory stored."
EOF
chmod +x /usr/local/bin/dmf7-agent-memory

cat <<'EOF' > /usr/local/bin/dmf7-agent-memory-view
#!/bin/bash
set -euo pipefail

echo "==============================="
echo "AGENT MEMORY"
echo "==============================="

if [[ -f /opt/dmf7/agents/memory/memory.log ]]; then
  cat /opt/dmf7/agents/memory/memory.log
else
  echo "No memory entries found."
fi
EOF
chmod +x /usr/local/bin/dmf7-agent-memory-view

cat <<'EOF' > /usr/local/bin/dmf7-agent-plan
#!/bin/bash
set -euo pipefail

PLAN=$*
mkdir -p /opt/dmf7/agents/tasks

echo "$PLAN" > /opt/dmf7/agents/tasks/plan-$(date +%s).task

echo "Agent plan queued."
EOF
chmod +x /usr/local/bin/dmf7-agent-plan

cat <<'EOF' > /usr/local/bin/dmf7-agent-think
#!/bin/bash
set -euo pipefail

PROMPT=$*

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama is required but not installed."
  exit 1
fi

echo "$PROMPT" | ollama run llama3
EOF
chmod +x /usr/local/bin/dmf7-agent-think

cat <<'EOF' > /usr/local/bin/dmf7-agent-improve
#!/bin/bash
set -euo pipefail

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama is required but not installed."
  exit 1
fi

echo "Reviewing system..."

if [[ $# -gt 0 && -f "$1" ]]; then
  ollama run llama3 < "$1"
else
  ollama run llama3
fi
EOF
chmod +x /usr/local/bin/dmf7-agent-improve

echo "DMF7 agent memory tools installed for steps 1022-1032."
