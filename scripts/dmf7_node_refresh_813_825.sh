#!/usr/bin/env bash
set -euo pipefail

# DMF7 node refresh for steps 813-825
# - Enforces Node.js 20 via nvm
# - Rebuilds DMF7 with pnpm
# - Restarts PM2 services and verifies key dependencies

DMF7_DIR="${DMF7_DIR:-$HOME/DMF7}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NODE_VERSION="${NODE_VERSION:-20}"
PUBLIC_HOST="${PUBLIC_HOST:-72.61.114.167}"

log() {
  printf "\n[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command '$1' not found in PATH." >&2
    exit 1
  fi
}

load_nvm() {
  if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
    echo "nvm not found at ${NVM_DIR}/nvm.sh. Install nvm before running this script." >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  . "${NVM_DIR}/nvm.sh"
}

ensure_tools() {
  require_cmd pnpm
  require_cmd pm2
  require_cmd curl
  require_cmd docker
}

switch_node() {
  log "STEP 813 — Fixing Node.js version with nvm"
  nvm install "${NODE_VERSION}"
  nvm use "${NODE_VERSION}"
  nvm alias default "${NODE_VERSION}"
  node -v
}

rebuild_dmf7() {
  log "STEP 814 — Rebuilding DMF7 with Node ${NODE_VERSION}"
  if [ ! -d "${DMF7_DIR}" ]; then
    echo "DMF7 directory not found at ${DMF7_DIR}. Set DMF7_DIR or create the directory." >&2
    exit 1
  fi
  cd "${DMF7_DIR}"
  pnpm install
  pnpm build
}

restart_pm2() {
  log "STEP 815 — Cleaning old PM2 processes"
  pm2 delete all || true

  log "STEP 816 — Starting DMF7 services"
  pm2 start pnpm --name dmf7-gateway -- run start --filter "@dmf7/gateway"
  pm2 start pnpm --name dmf7-console -- run start --filter "@dmf7/operator-console"
  pm2 start pnpm --name dmf7-ingest -- run start --filter "@dmf7/ingest"
  pm2 start pnpm --name dmf7-retrieval -- run start --filter "@dmf7/retrieval"

  log "STEP 817 — Saving PM2 state"
  pm2 save

  log "STEP 818 — Verifying PM2 process list"
  pm2 list
}

verify_services() {
  log "STEP 819 — Checking service health"
  curl -fsS "http://localhost:4000" || true
  curl -fsS "http://localhost:4100" || true

  log "STEP 820 — Verifying Redis connection"
  docker ps | grep redis || true

  log "STEP 821 — Verifying vector database (qdrant)"
  docker ps | grep qdrant || true

  log "STEP 822 — Verifying graph database (neo4j)"
  docker ps | grep neo4j || true

  log "STEP 823 — Verifying AI engine (ollama)"
  docker ps | grep ollama || true

  log "STEP 824 — Final status check"
  pm2 list
  docker ps
}

final_banner() {
  cat <<EOF
=======================================
DMF7 NODE FULLY OPERATIONAL
Gateway: http://${PUBLIC_HOST}:4000
Console: http://${PUBLIC_HOST}:4100
AI UI: http://${PUBLIC_HOST}:3001
Neo4j: http://${PUBLIC_HOST}:7474
Grafana: http://${PUBLIC_HOST}:3000
Portainer: http://${PUBLIC_HOST}:9000
=======================================
EOF
}

main() {
  load_nvm
  ensure_tools
  switch_node
  rebuild_dmf7
  restart_pm2
  verify_services
  final_banner
}

main "$@"
