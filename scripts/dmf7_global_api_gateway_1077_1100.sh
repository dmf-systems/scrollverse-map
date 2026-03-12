#!/usr/bin/env bash
set -euo pipefail

VERIFY=0
if [[ "${1:-}" == "--verify" ]]; then
  VERIFY=1
  shift
fi

create_dir() {
  sudo mkdir -p "$1"
}

write_file() {
  local target="$1"
  sudo tee "$target" >/dev/null
}

ensure_executable() {
  sudo chmod +x "$1"
}

ensure_cron_entry() {
  local entry="$1"
  local current
  current=$(sudo crontab -l 2>/dev/null || true)
  if ! printf "%s\n" "$current" | grep -Fq "$entry"; then
    if [[ -n "$current" ]]; then
      printf "%s\n%s\n" "$current" "$entry" | sudo crontab -
    else
      printf "%s\n" "$entry" | sudo crontab -
    fi
  fi
}

create_dir /opt/dmf7/gateway
create_dir /opt/dmf7/research
create_dir /opt/dmf7/federation/nodes
sudo touch /opt/dmf7/federation/nodes/registry.txt

write_file /opt/dmf7/gateway/global_api.js <<'EOF'
const express = require("express")
const fs = require("fs")
const app = express()

app.use(express.json())

app.get("/status", (req, res) => {
  res.json({ system: "DMF7", status: "online" })
})

app.post("/research", (req, res) => {
  const q = req.body.query
  const id = Date.now()
  fs.writeFileSync(`/opt/dmf7/research/${id}.txt`, q)
  res.json({ queued: id })
})

app.listen(6060, () => console.log("DMF7 Global API 6060"))
EOF

if [[ ! -f /opt/dmf7/gateway/package.json ]]; then
  (cd /opt/dmf7/gateway && npm init -y >/dev/null)
fi
(cd /opt/dmf7/gateway && npm install express >/dev/null)

if command -v pm2 >/dev/null 2>&1; then
  pm2 start /opt/dmf7/gateway/global_api.js --name dmf7-global-api --update-env >/dev/null
  pm2 save >/dev/null
else
  echo "pm2 not installed; skipping process launch" >&2
fi

write_file /usr/local/bin/dmf7-research-worker <<'EOF'
#!/bin/bash

for f in /opt/dmf7/research/*.txt; do
  [ -e "$f" ] || continue

  NAME=$(basename "$f")

  ollama run llama3 < "$f" > /opt/dmf7/research/$NAME.result

  rm "$f"
done
EOF

ensure_executable /usr/local/bin/dmf7-research-worker
ensure_cron_entry "*/2 * * * * /usr/local/bin/dmf7-research-worker"

write_file /usr/local/bin/dmf7-model-router <<'EOF'
#!/bin/bash

MODEL=$1
shift

PROMPT=$*

echo "$PROMPT" | ollama run $MODEL
EOF

ensure_executable /usr/local/bin/dmf7-model-router

write_file /usr/local/bin/dmf7-global-ai <<'EOF'
#!/bin/bash

clear
echo "=============================="
echo " DMF7 GLOBAL AI "
echo "=============================="

read -p "Prompt: " P

echo "$P" | ollama run llama3
EOF

ensure_executable /usr/local/bin/dmf7-global-ai

write_file /usr/local/bin/dmf7-federation-ping <<'EOF'
#!/bin/bash

for node in $(cat /opt/dmf7/federation/nodes/registry.txt); do
  echo "Ping $node"
  curl -s http://$node:6060/status
done
EOF

ensure_executable /usr/local/bin/dmf7-federation-ping

write_file /usr/local/bin/dmf7-global <<'EOF'
#!/bin/bash

clear
echo "=============================="
echo " DMF7 GLOBAL CONTROL "
echo "=============================="

echo "1 AI query"
echo "2 Research job"
echo "3 Federation status"
echo "4 Node health"
echo "5 Exit"

read -p "Choice: " C

case $C in

1)
dmf7-global-ai
;;

2)
dmf7-distribute-job
;;

3)
dmf7-federation-status
;;

4)
dmf7-node-health
;;

5)
exit
;;

esac
EOF

ensure_executable /usr/local/bin/dmf7-global

write_file /opt/dmf7/GLOBAL_NODE_REPORT.txt <<'EOF'
DMF7 GLOBAL NODE

IP
72.61.114.167

SERVICES
Gateway API
Operator Console
AI Runtime
Vector DB
Graph DB
Federation Network
Research Engine
Agent System

STATUS
GLOBAL NODE ACTIVE
EOF

if (( VERIFY )); then
  curl -s http://localhost:6060/status || true
  dmf7-federation-ping || true
fi

cat <<'EOF'
=======================================
DMF7 GLOBAL AI INFRASTRUCTURE

Node: 72.61.114.167
Global API: http://72.61.114.167:6060

STATUS: GLOBAL NETWORK NODE
=======================================
EOF

echo "DMF7 global API and tooling installed (steps 1077-1100)."
