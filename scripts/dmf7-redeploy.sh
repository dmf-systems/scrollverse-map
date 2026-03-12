#!/usr/bin/env bash
set -euo pipefail

DMF7_DIR="${DMF7_DIR:-"$HOME/DMF7"}"
ENV_FILE="${ENV_FILE:-"$DMF7_DIR/.env"}"
ENV_SAMPLE="${ENV_SAMPLE:-"$DMF7_DIR/.env.example"}"

log() {
  local level="$1"; shift
  printf '[%s] %s\n' "$level" "$*"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Required command '$cmd' is not available in PATH."
    exit 1
  fi
}

load_nvm() {
  export NVM_DIR="${NVM_DIR:-"$HOME/.nvm"}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck disable=SC1090
    . "$NVM_DIR/nvm.sh"
  else
    log_error "nvm is not installed. Install nvm first: https://github.com/nvm-sh/nvm"
    exit 1
  fi
}

install_node() {
  log_info "Ensuring Node.js 20 via nvm"
  load_nvm
  nvm install 20
  nvm use 20
  node -v
}

reset_dependencies() {
  log_info "Reinstalling project dependencies in $DMF7_DIR"
  cd "$DMF7_DIR"
  rm -rf node_modules
  pnpm install
  pnpm build
}

ensure_env_var() {
  local key="$1"
  local value="$2"
  if ! grep -E "^${key}=" "$ENV_FILE" >/dev/null 2>&1; then
    printf '%s=%s\n' "$key" "$value" >>"$ENV_FILE"
    log_info "Added $key to $(basename "$ENV_FILE")"
  else
    log_info "$key already set"
  fi
}

prepare_env() {
  log_info "Ensuring environment variables"
  cd "$DMF7_DIR"
  if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_SAMPLE" ]; then
      cp "$ENV_SAMPLE" "$ENV_FILE"
      log_info "Created $(basename "$ENV_FILE") from example"
    else
      touch "$ENV_FILE"
      log_warn "No .env.example found; created empty $(basename "$ENV_FILE")"
    fi
  fi

  ensure_env_var "REDIS_URL" "redis://127.0.0.1:6380"
  ensure_env_var "QDRANT_URL" "http://127.0.0.1:6333"
  ensure_env_var "NEO4J_URL" "bolt://127.0.0.1:7687"
  ensure_env_var "OLLAMA_URL" "http://127.0.0.1:11435"
}

reset_pm2() {
  log_info "Resetting pm2 services"
  pm2 delete all >/dev/null 2>&1 || true
  pm2 flush
  pm2 kill
}

start_services() {
  log_info "Starting DMF7 services under pm2"
  cd "$DMF7_DIR"
  pm2 start pnpm --name dmf7-gateway -- run start --filter "@dmf7/gateway"
  pm2 start pnpm --name dmf7-console -- run start --filter "@dmf7/operator-console"
  pm2 start pnpm --name dmf7-ingest -- run start --filter "@dmf7/ingest"
  pm2 start pnpm --name dmf7-retrieval -- run start --filter "@dmf7/retrieval"
  pm2 save
}

restart_infra() {
  log_info "Restarting core infrastructure containers"
  docker restart redis-ai qdrant neo4j ollama portainer netdata cadvisor glances grafana
}

verify_services() {
  log_info "pm2 process list"
  pm2 list
  log_info "docker containers"
  docker ps
}

test_apis() {
  log_info "Testing gateway and operator console health endpoints"
  curl --fail --silent http://localhost:4000 || log_warn "Gateway check failed"
  curl --fail --silent http://localhost:4100 || log_warn "Operator console check failed"
}

enable_autostart() {
  log_info "Enabling pm2 startup"
  pm2 startup
  pm2 save
}

main() {
  log_info "Starting DMF7 service recovery sequence"
  install_node
  require_cmd pnpm
  require_cmd pm2
  require_cmd docker
  require_cmd curl

  reset_dependencies
  prepare_env
  reset_pm2
  start_services
  restart_infra
  verify_services
  test_apis
  enable_autostart
  log_info "DMF7 services restored. Verify public access manually if needed."
}

main "$@"
