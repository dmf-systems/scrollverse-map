#!/usr/bin/env bash
set -euo pipefail

# DMF7 Node 20 refresh and service reset (steps 1101-1115)
# This script aligns the node version, rebuilds DMF7, refreshes PM2 and Docker services,
# and installs the dmf7-check and dmf7 master control helpers.

DMF7_DIR="${DMF7_DIR:-"$HOME/DMF7"}"
NVM_DIR="${NVM_DIR:-"$HOME/.nvm"}"

maybe_sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

check_endpoint() {
  local url="$1"
  if curl -fsS "$url" >/dev/null; then
    echo "OK ${url}"
  else
    echo "WARN ${url} unreachable" >&2
  fi
}

write_script() {
  local path="$1"
  shift
  cat <<'EOF' | maybe_sudo tee "$path" >/dev/null
#!/bin/bash

echo "========== DMF7 SYSTEM CHECK =========="

echo ""
echo "PM2 SERVICES"
pm2 list

echo ""
echo "DOCKER CONTAINERS"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "API TEST"
curl -s http://localhost:4000
curl -s http://localhost:4100

echo ""
echo "VECTOR DB"
curl -s http://localhost:6333

echo ""
echo "OLLAMA"
curl -s http://localhost:11435

echo ""
echo "======================================="
echo "DMF7 NODE HEALTH COMPLETE"
EOF
  maybe_sudo chmod +x "$path"
}

write_master() {
  local path="$1"
  cat <<'EOF' | maybe_sudo tee "$path" >/dev/null
#!/bin/bash

clear

echo "=============================="
echo " DMF7 NODE CONTROL "
echo "=============================="

echo "1 System Check"
echo "2 AI Query"
echo "3 Docker Status"
echo "4 PM2 Status"
echo "5 Exit"

read -p "Select: " S

case $S in

1)
dmf7-check
;;

2)
read -p "Prompt: " P
echo "$P" | ollama run llama3
;;

3)
docker ps
;;

4)
pm2 list
;;

5)
exit
;;

esac
EOF
  maybe_sudo chmod +x "$path"
}

require_cmd curl
require_cmd pnpm
require_cmd pm2
require_cmd docker

if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  echo "nvm not found at $NVM_DIR/nvm.sh" >&2
  exit 1
fi

echo "STEP 1101 — FIX NODE VERSION (REQUIRED FOR DMF7 BUILD >=20)"
source "$NVM_DIR/nvm.sh"
nvm install 20
nvm use 20
nvm alias default 20
node -v

echo "STEP 1102 — REBUILD DMF7 WITH CORRECT NODE VERSION"
if [[ ! -d "$DMF7_DIR" ]]; then
  echo "DMF7 directory not found at $DMF7_DIR" >&2
  exit 1
fi
cd "$DMF7_DIR"
rm -rf node_modules .turbo
pnpm install
pnpm build

echo "STEP 1103 — CLEAN PM2 (REMOVE BROKEN SERVICES)"
for svc in dmf7-ingest dmf7-retrieval dmf7-console dmf7-gateway; do
  pm2 delete "$svc" || true
done

echo "STEP 1104 — START DMF7 SERVICES CLEAN"
cd "$DMF7_DIR"
pm2 start pnpm --name dmf7-gateway -- run start --filter "@dmf7/gateway"
pm2 start pnpm --name dmf7-console -- run start --filter "@dmf7/operator-console"
pm2 start pnpm --name dmf7-ingest -- run start --filter "@dmf7/ingest"
pm2 start pnpm --name dmf7-retrieval -- run start --filter "@dmf7/retrieval"
pm2 save

echo "STEP 1105 — VERIFY SERVICES"
pm2 list

echo "STEP 1106 — VERIFY API ENDPOINTS"
check_endpoint "http://localhost:4000"
check_endpoint "http://localhost:4100"

echo "STEP 1107 — FIX DOCKER DMF7 CONTAINERS (RESTART STACK)"
for container in dmf7-gateway dmf7-console dmf7-ingest dmf7-retrieval; do
  if docker restart "$container"; then
    echo "Restarted ${container}"
  else
    echo "WARN could not restart ${container}" >&2
  fi
done

echo "STEP 1108 — VERIFY ALL CONTAINERS"
docker ps

echo "STEP 1109 — CREATE DMF7 SYSTEM CHECK SCRIPT"
write_script "/usr/local/bin/dmf7-check"

echo "STEP 1110 — MAKE SYSTEM CHECK EXECUTABLE"
# Permissions handled in write_script

echo "STEP 1111 — RUN SYSTEM CHECK"
dmf7-check

echo "STEP 1112 — CREATE DMF7 MASTER CONTROL"
write_master "/usr/local/bin/dmf7"

echo "STEP 1113 — MAKE MASTER COMMAND EXECUTABLE"
# Permissions handled in write_master

echo "STEP 1114 — TEST MASTER COMMAND"
dmf7

echo "STEP 1115 — FINAL NODE STATUS"
cat <<'EOF'
=================================
DMF7 NODE ONLINE
Gateway: http://72.61.114.167:4000
Console: http://72.61.114.167:4100
OpenWebUI: http://72.61.114.167:3001
Neo4j: http://72.61.114.167:7474
Grafana: http://72.61.114.167:3000
Portainer: http://72.61.114.167:9000
=================================
EOF
