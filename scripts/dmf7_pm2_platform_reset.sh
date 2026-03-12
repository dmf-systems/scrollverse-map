#!/usr/bin/env bash
# DMF7 Steps 245-260: fix PM2 platform path and verify services
set -euo pipefail

PLATFORM_DIR="/opt/dmf7/platform"
NODE_ID_FILE="/opt/dmf7/NODE_ID"
NODE_ID_VALUE="DMF7-AI-NODE-01"
PM2_PROCESSES=("dmf7-gateway" "dmf7-console" "dmf7-ingest" "dmf7-retrieval")
SERVICE_COMMANDS=(
  "pnpm --name dmf7-gateway -- run start --filter @dmf7/gateway"
  "pnpm --name dmf7-console -- run start --filter @dmf7/operator-console"
  "pnpm --name dmf7-ingest -- run start --filter @dmf7/ingest"
  "pnpm --name dmf7-retrieval -- run start --filter @dmf7/retrieval"
)
ENDPOINTS=(
  "Gateway|http://localhost:4000"
  "Console|http://localhost:4100"
  "Vector DB|http://localhost:6333"
  "AI Model Server|http://localhost:11435/api/tags"
  "Graph DB|http://localhost:7474"
  "AI Web UI|http://localhost:3001"
)

log() {
  echo "[dmf7] $*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command '$1' not found in PATH." >&2
    exit 1
  fi
}

check_pm2_status() {
  pm2 jlist | python3 - "${PM2_PROCESSES[@]}" <<'PY'
import json, sys
data = json.load(sys.stdin)
required = set(sys.argv[1:])
missing = set(required)
offline = []
for proc in data:
    name = proc.get("name")
    if name in required:
        missing.discard(name)
        if proc.get("pm2_env", {}).get("status") != "online":
            offline.append(name)

if missing:
    sys.stderr.write(f"Missing PM2 processes: {', '.join(sorted(missing))}\n")
    sys.exit(1)
if offline:
    sys.stderr.write(f"Offline PM2 processes: {', '.join(sorted(offline))}\n")
    sys.exit(1)
PY
  log "All PM2 services are online: ${PM2_PROCESSES[*]}"
}

check_endpoint() {
  local name="$1"
  local url="$2"
  local status

  status="$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" || true)"
  if [[ "$status" =~ ^2[0-9][0-9]$ || "$status" =~ ^3[0-9][0-9]$ ]]; then
    log "Endpoint OK ($status): $name - $url"
  else
    echo "Endpoint check failed for $name ($url) with HTTP $status" >&2
    exit 1
  fi
}

main() {
  require_cmd pm2
  require_cmd pnpm
  require_cmd curl
  require_cmd python3

  if [[ ! -d "$PLATFORM_DIR" ]]; then
    echo "Platform directory not found: $PLATFORM_DIR" >&2
    exit 1
  fi

  log "Changing to production platform directory ($PLATFORM_DIR)"
  cd "$PLATFORM_DIR"

  log "Stopping existing PM2 services"
  pm2 delete all || true

  log "Starting PM2 services from production directory"
  for cmd in "${SERVICE_COMMANDS[@]}"; do
    # shellcheck disable=SC2086
    pm2 start $cmd
  done

  log "Saving PM2 process list"
  pm2 save

  log "Verifying PM2 services are online"
  check_pm2_status

  log "Running PM2 list for visibility"
  pm2 list

  log "Checking service endpoints"
  for item in "${ENDPOINTS[@]}"; do
    IFS="|" read -r name url <<<"$item"
    check_endpoint "$name" "$url"
  done

  log "Running dmf7-status"
  require_cmd dmf7-status
  dmf7-status

  log "Writing node identifier"
  install -d "$(dirname "$NODE_ID_FILE")"
  echo "$NODE_ID_VALUE" >"$NODE_ID_FILE"
  cat "$NODE_ID_FILE"

  log "Running dmf7-report"
  require_cmd dmf7-report
  dmf7-report

  cat <<'BANNER'
======================================
DMF7 NEXTGEN AI NODE FULLY OPERATIONAL
======================================

Gateway:  http://72.61.114.167:4000
Console:  http://72.61.114.167:4100
AI UI:    http://72.61.114.167:3001

Neo4j:    http://72.61.114.167:7474
Qdrant:   http://72.61.114.167:6333

Grafana:  http://72.61.114.167:3000
Portainer:http://72.61.114.167:9000

NODE STATUS: PRODUCTION
======================================
BANNER
}

main "$@"
