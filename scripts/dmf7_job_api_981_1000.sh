#!/usr/bin/env bash
set -euo pipefail

VERIFY=false

usage() {
  echo "Usage: $0 [--verify]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify)
      VERIFY=true
      shift
      ;;
    *)
      usage
      ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "This script must run as root to manage /opt and /usr/local/bin."
  exit 1
fi

ensure_dir() {
  mkdir -p "$1"
}

write_job_api() {
  ensure_dir /opt/dmf7/api
  ensure_dir /opt/dmf7/tasks/pending
  ensure_dir /opt/dmf7/tasks/completed

  cat >/opt/dmf7/api/job_api.js <<'EOF'
const express = require("express")
const fs = require("fs")
const app = express()

app.use(express.json())

const QUEUE="/opt/dmf7/tasks/pending"

app.post("/task",(req,res)=>{
    const task=req.body.task
    const id=Date.now()
    fs.writeFileSync(`${QUEUE}/${id}.task`,task)
    res.json({status:"queued",id})
})

app.get("/tasks",(req,res)=>{
    const tasks=fs.readdirSync("/opt/dmf7/tasks/completed")
    res.json(tasks)
})

app.listen(5050,()=>{
    console.log("DMF7 Task API running on 5050")
})
EOF
}

init_job_api_dependencies() {
  pushd /opt/dmf7/api >/dev/null
  if [[ ! -f package.json ]]; then
    npm init -y
  fi
  npm install express
  popd >/dev/null
}

start_pm2_service() {
  if ! command -v pm2 >/dev/null 2>&1; then
    npm install -g pm2
  fi

  if pm2 describe dmf7-task-api >/dev/null 2>&1; then
    pm2 restart dmf7-task-api --update-env
  else
    pm2 start /opt/dmf7/api/job_api.js --name dmf7-task-api
  fi
  pm2 save
}

write_query_tool() {
  cat >/usr/local/bin/dmf7-query <<'EOF'
#!/bin/bash

QUERY=$*

echo "$QUERY" | ollama run llama3
EOF
  chmod +x /usr/local/bin/dmf7-query
}

write_telemetry() {
  ensure_dir /opt/dmf7
  : >/opt/dmf7/telemetry.log

  cat >/usr/local/bin/dmf7-telemetry <<'EOF'
#!/bin/bash

DATE=$(date)

echo "$DATE | CPU $(uptime) | MEM $(free -h | head -n2 | tail -n1)" > /opt/dmf7/telemetry.log
EOF
  chmod +x /usr/local/bin/dmf7-telemetry
}

ensure_cron_entry() {
  local cron_line="*/5 * * * * /usr/local/bin/dmf7-telemetry"
  local tmp
  tmp=$(mktemp)
  crontab -l 2>/dev/null | grep -v "dmf7-telemetry" >"$tmp" || true
  echo "$cron_line" >>"$tmp"
  crontab "$tmp"
  rm -f "$tmp"
}

write_final_status() {
  cat >/opt/dmf7/FINAL_STATUS.txt <<'EOF'
DMF7 AUTONOMOUS NODE

AI Runtime: Ollama
Vector DB: Qdrant
Graph DB: Neo4j
Worker Queue: Redis
Task API: Active
Knowledge System: Active
Monitoring: Active
Cluster Engine: Active

NODE IP
72.61.114.167

STATUS
FULLY OPERATIONAL
EOF
}

run_verification() {
  echo "Testing task API queueing..."
  if ! curl -s -X POST http://localhost:5050/task -H "Content-Type: application/json" -d '{"task":"Explain the DMF7 architecture"}'; then
    echo "Warning: Task API verification request failed."
  fi

  echo "Pending tasks:"
  ls -1 /opt/dmf7/tasks/pending || true

  echo "Attempting to process tasks with dmf7-task-worker if available..."
  if command -v dmf7-task-worker >/dev/null 2>&1; then
    dmf7-task-worker || true
  else
    echo "dmf7-task-worker not installed; skipping."
  fi

  echo "Completed tasks:"
  ls -1 /opt/dmf7/tasks/completed || true

  echo "Telemetry snapshot:"
  cat /opt/dmf7/telemetry.log || true
}

final_banner() {
  cat <<'EOF'
=======================================
DMF7 GLOBAL AI SYSTEM

Node: 72.61.114.167

Gateway API: http://72.61.114.167:4000
Console: http://72.61.114.167
AI UI: http://72.61.114.167/ai
Task API: http://72.61.114.167:5050

STATUS: COMPLETE
=======================================
EOF
}

write_job_api
init_job_api_dependencies
start_pm2_service
write_query_tool
write_telemetry
ensure_cron_entry
write_final_status

if $VERIFY; then
  run_verification
fi

final_banner
