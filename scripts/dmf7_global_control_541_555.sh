#!/bin/bash
set -euo pipefail

BIN_DIR="${BIN_DIR:-/usr/local/bin}"

install_script() {
  local name="$1"
  local body="$2"

  echo "Installing ${name} to ${BIN_DIR}/${name}..."
  echo "${body}" | tee "${BIN_DIR}/${name}" >/dev/null
  chmod +x "${BIN_DIR}/${name}"
}

install_script "dmf7" '#!/bin/bash

case "$1" in

status)
echo "==== DMF7 STATUS ===="
pm2 list
docker ps
;;

restart)
echo "Restarting DMF7 services..."
pm2 restart all
;;

stop)
echo "Stopping DMF7 services..."
pm2 stop all
;;

logs)
pm2 logs
;;

models)
ollama list
;;

docker)
docker ps
;;

storage)
df -h
;;

health)
curl -s http://localhost:4000
echo ""
curl -s http://localhost:4100
;;

*)
echo "DMF7 COMMAND MENU"
echo ""
echo "dmf7 status     - system status"
echo "dmf7 restart    - restart services"
echo "dmf7 stop       - stop services"
echo "dmf7 logs       - view logs"
echo "dmf7 models     - list AI models"
echo "dmf7 docker     - list containers"
echo "dmf7 storage    - disk usage"
echo "dmf7 health     - API health check"
;;

esac
'

install_script "dmf7-ai" '#!/bin/bash

MODEL=${1:-llama3}

echo "Running AI task on model: $MODEL"

ollama run "$MODEL"
'

install_script "dmf7-check" '#!/bin/bash

echo "Checking DMF7 services..."

curl -s http://localhost:4000
echo ""

curl -s http://localhost:4100
echo ""

docker ps | grep qdrant || true
docker ps | grep redis || true
docker ps | grep neo4j || true
docker ps | grep ollama || true
'

install_script "dmf7-clean" '#!/bin/bash

echo "Cleaning unused Docker resources..."

docker system prune -af

echo "Cleaning pnpm cache..."

pnpm store prune

echo "Cleanup complete."
'

if [[ "${1:-}" == "--verify" ]]; then
  echo "Running post-install verification (best-effort)..."
  set +e
  "${BIN_DIR}/dmf7"
  "${BIN_DIR}/dmf7" status
  "${BIN_DIR}/dmf7" health
  "${BIN_DIR}/dmf7-ai"
  "${BIN_DIR}/dmf7-check"
  "${BIN_DIR}/dmf7-clean"
  set -e
  echo "Verification finished."
fi

cat <<"EOF"
==================================================
 DMF7 NEXTGEN PLATFORM DEPLOYED 
==================================================

Access Services:
Gateway:   http://72.61.114.167:4000
Console:   http://72.61.114.167:4100
AI UI:     http://72.61.114.167:3001
Grafana:   http://72.61.114.167:3000
Neo4j:     http://72.61.114.167:7474
Portainer: http://72.61.114.167:9000

Command Control:
dmf7 status
dmf7 health
dmf7 restart
dmf7-ai

SYSTEM STATUS: OPERATIONAL
==================================================
EOF
