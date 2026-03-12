#!/usr/bin/env bash
set -euo pipefail

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
DMF7_DIR="${DMF7_DIR:-$HOME/DMF7}"
NODE_VERSION="${NODE_VERSION:-20}"
PUBLIC_HOST="${PUBLIC_HOST:-72.61.114.167}"

log_step() {
  printf "\n==== %s ====\n" "$1"
}

warn() {
  printf "WARNING: %s\n" "$1" >&2
}

command_available() {
  command -v "$1" >/dev/null 2>&1
}

curl_check() {
  local label="$1"
  local url="$2"
  printf "-- %s (%s)\n" "$label" "$url"
  if curl --fail --silent --show-error --max-time 10 "$url" >/dev/null; then
    echo "   OK"
  else
    warn "Check failed for $url"
  fi
}

log_step "STEP 64 — Fix Node version for project"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"
else
  echo "nvm not found at $NVM_DIR/nvm.sh" >&2
  exit 1
fi
nvm install "$NODE_VERSION"
nvm use "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
node -v

log_step "STEP 65 — Rebuild DMF7 project"
if ! command_available git; then
  echo "git is required for pulling the DMF7 project" >&2
  exit 1
fi
if ! command_available pnpm; then
  echo "pnpm is required to rebuild the DMF7 project" >&2
  exit 1
fi
if [ ! -d "$DMF7_DIR" ]; then
  echo "DMF7 directory not found: $DMF7_DIR" >&2
  exit 1
fi
(
  cd "$DMF7_DIR"
  git pull
  pnpm install
  pnpm build
)

log_step "STEP 66 — Restart PM2 services cleanly"
if command_available pm2; then
  pm2 delete all >/dev/null 2>&1 || true
  pm2 start pnpm --name dmf7-gateway -- run start --filter "@dmf7/gateway"
  pm2 start pnpm --name dmf7-console -- run start --filter "@dmf7/operator-console"
  pm2 start pnpm --name dmf7-ingest -- run start --filter "@dmf7/ingest"
  pm2 start pnpm --name dmf7-retrieval -- run start --filter "@dmf7/retrieval"
  pm2 save
else
  warn "pm2 not installed; skipping process restart"
fi

log_step "STEP 67 — Verify services"
if command_available pm2; then
  pm2 list
else
  warn "pm2 not installed; cannot show process list"
fi

log_step "STEP 68 — Verify docker stack"
if command_available docker; then
  docker ps
else
  warn "docker not installed; skipping docker stack check"
fi

log_step "STEP 69 — Test API services (localhost)"
curl_check "DMF7 Gateway" "http://localhost:4000"
curl_check "DMF7 Console" "http://localhost:4100"

log_step "STEP 70 — Verify AI engine"
curl_check "AI Engine" "http://localhost:11435/api/tags"

log_step "STEP 71 — Verify vector database"
curl_check "Qdrant" "http://localhost:6333/collections"

log_step "STEP 72 — Verify graph database"
curl_check "Neo4j" "http://localhost:7474"

log_step "STEP 73 — Verify Redis"
if command_available docker; then
  if docker exec redis-ai redis-cli ping; then
    echo "Redis responded with PONG"
  else
    warn "Redis ping failed"
  fi
else
  warn "docker not installed; cannot check redis-ai container"
fi

log_step "STEP 74 — Check system resources"
if command_available htop; then
  if [ -t 1 ]; then
    echo "Launching htop (press q to exit)..."
    htop
  else
    warn "Skipping htop because no TTY is available"
  fi
else
  warn "htop not installed"
fi

log_step "STEP 75 — Verify NGINX proxy"
if command_available systemctl; then
  systemctl status --no-pager nginx || warn "NGINX status check failed"
else
  warn "systemctl not available; cannot check NGINX"
fi

log_step "STEP 76 — Verify firewall"
if command_available ufw; then
  ufw status || warn "ufw status check failed"
else
  warn "ufw not installed"
fi

log_step "STEP 77 — Test public endpoints"
curl_check "Public Gateway" "http://${PUBLIC_HOST}:4000"
curl_check "Public Console" "http://${PUBLIC_HOST}:4100"

log_step "STEP 78 — Test AI through Open WebUI"
curl_check "Open WebUI" "http://${PUBLIC_HOST}:3001"

log_step "STEP 79 — Run system status"
if command_available dmf7; then
  dmf7 status
else
  warn "dmf7 CLI not installed; skipping status check"
fi

log_step "STEP 80 — Final node confirmation"
cat <<EOF
==================================
 DMF7 PRODUCTION NODE OPERATIONAL
==================================
Gateway  : http://${PUBLIC_HOST}:4000
Console  : http://${PUBLIC_HOST}:4100
AI UI    : http://${PUBLIC_HOST}:3001
Grafana  : http://${PUBLIC_HOST}:3000
Neo4j    : http://${PUBLIC_HOST}:7474
Portainer: http://${PUBLIC_HOST}:9000
==================================
EOF
