#!/usr/bin/env bash
set -euo pipefail

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NODE_VERSION="${NODE_VERSION:-20}"
PLATFORM_DIR="${PLATFORM_DIR:-/opt/dmf7/platform}"
STATUS_FILE="${STATUS_FILE:-/opt/dmf7/STATUS}"

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
  set +e
  if curl --fail --silent --show-error --max-time 10 "$url" >/dev/null; then
    echo "   OK"
  else
    warn "Check failed for $url"
  fi
  set -e
}

log_step "STEP 227 — Fix Node version (required by DMF7)"
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

log_step "STEP 228 — Verify Node version"
node -v

log_step "STEP 229 — Rebuild platform with Node $NODE_VERSION"
if [ ! -d "$PLATFORM_DIR" ]; then
  echo "DMF7 platform directory not found: $PLATFORM_DIR" >&2
  exit 1
fi
if ! command_available pnpm; then
  echo "pnpm is required to rebuild the DMF7 platform" >&2
  exit 1
fi
(
  cd "$PLATFORM_DIR"
  pnpm install
  pnpm build
)

log_step "STEP 230 — Restart all PM2 services"
if command_available pm2; then
  pm2 restart all
else
  warn "pm2 not installed; skipping restart"
fi

log_step "STEP 231 — Verify PM2 services"
if command_available pm2; then
  pm2 list
else
  warn "pm2 not installed; cannot list processes"
fi

log_step "STEP 232 — Fix failed services (ingest + retrieval)"
if command_available pm2; then
  pm2 delete dmf7-ingest >/dev/null 2>&1 || true
  pm2 delete dmf7-retrieval >/dev/null 2>&1 || true
  pm2 start pnpm --name dmf7-ingest -- run start --filter "@dmf7/ingest"
  pm2 start pnpm --name dmf7-retrieval -- run start --filter "@dmf7/retrieval"
  pm2 save
else
  warn "pm2 not installed; cannot restart ingest/retrieval"
fi

log_step "STEP 233 — Verify services again"
if command_available pm2; then
  pm2 list
else
  warn "pm2 not installed; cannot list processes"
fi

log_step "STEP 234 — Verify API"
curl_check "Gateway API" "http://localhost:4000"

log_step "STEP 235 — Verify console"
curl_check "Operator Console" "http://localhost:4100"

log_step "STEP 236 — Verify vector database"
curl_check "Qdrant" "http://localhost:6333"

log_step "STEP 237 — Verify Neo4j"
curl_check "Neo4j" "http://localhost:7474"

log_step "STEP 238 — Verify AI model server"
curl_check "AI Model Server" "http://localhost:11435/api/tags"

log_step "STEP 239 — Verify Web UI"
curl_check "Web UI" "http://localhost:3001"

log_step "STEP 240 — Final stack check"
if command_available dmf7-status; then
  dmf7-status
else
  warn "dmf7-status command not available"
fi

log_step "STEP 241 — Final system report"
if command_available dmf7-report; then
  dmf7-report
else
  warn "dmf7-report command not available"
fi

log_step "STEP 242 — Save server state"
if command_available pm2; then
  pm2 save
else
  warn "pm2 not installed; cannot save process list"
fi

log_step "STEP 243 — Final production flag"
STATUS_DIR="$(dirname "$STATUS_FILE")"
if ! mkdir -p "$STATUS_DIR"; then
  echo "Failed to create status directory: $STATUS_DIR" >&2
  exit 1
fi
echo "DMF7-NEXTGEN-AI-NODE-PRODUCTION" > "$STATUS_FILE"

log_step "STEP 244 — Verify production status"
cat "$STATUS_FILE"
