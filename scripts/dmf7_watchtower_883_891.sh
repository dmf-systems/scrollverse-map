#!/usr/bin/env bash
set -euo pipefail

WATCHTOWER_NAME="${WATCHTOWER_NAME:-watchtower}"
WATCHTOWER_IMAGE="${WATCHTOWER_IMAGE:-containrrr/watchtower}"
WATCHTOWER_INTERVAL="${WATCHTOWER_INTERVAL:-3600}"
VERIFY=0

usage() {
  cat <<'EOF'
DMF7 Watchtower + AI setup (steps 883-891)

Usage: ./dmf7_watchtower_883_891.sh [--verify]

Options:
  --verify   Run post-setup checks (dmf7-ai, vector DB, graph DB)
  --help     Show this help text

Environment:
  WATCHTOWER_NAME      Container name (default: watchtower)
  WATCHTOWER_IMAGE     Watchtower image (default: containrrr/watchtower)
  WATCHTOWER_INTERVAL  Update interval seconds (default: 3600)
EOF
}

log() {
  printf '\n[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must run as root (sudo ./dmf7_watchtower_883_891.sh)" >&2
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verify)
        VERIFY=1
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done
}

install_watchtower() {
  log "STEP 883 — Install Docker auto-update (Watchtower)"

  if docker ps -a --format '{{.Names}}' | grep -Fxq "$WATCHTOWER_NAME"; then
    log "Existing $WATCHTOWER_NAME container found; recreating with desired settings"
    docker rm -f "$WATCHTOWER_NAME" >/dev/null 2>&1 || true
  fi

  docker run -d \
    --name "$WATCHTOWER_NAME" \
    --restart unless-stopped \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$WATCHTOWER_IMAGE" \
    --cleanup \
    --interval "$WATCHTOWER_INTERVAL"
}

verify_watchtower() {
  log "STEP 884 — Verify Watchtower"
  if docker ps --format '{{.Names}}' | grep -Fxq "$WATCHTOWER_NAME"; then
    log "Watchtower container \"$WATCHTOWER_NAME\" is running"
  else
    echo "Watchtower container \"$WATCHTOWER_NAME\" is NOT running" >&2
    exit 1
  fi
}

create_global_dirs() {
  log "STEP 885 — Create global DMF7 service directories"
  mkdir -p /opt/dmf7/services
  mkdir -p /opt/dmf7/runtime
  mkdir -p /opt/dmf7/ai-jobs
  mkdir -p /opt/dmf7/vector-cache
  mkdir -p /opt/dmf7/knowledge
}

write_dmf7_ai() {
  log "STEP 886/887 — Install dmf7-ai helper"
  cat <<'EOF' >/usr/local/bin/dmf7-ai
#!/bin/bash

MODEL=${1:-llama3}

echo "================================="
echo " DMF7 AI EXECUTION "
echo "================================="

echo "Model: $MODEL"
echo ""

ollama run "$MODEL"
EOF
  chmod +x /usr/local/bin/dmf7-ai
}

test_ai_engine() {
  log "STEP 888 — Test AI engine via dmf7-ai"
  /usr/local/bin/dmf7-ai
}

vector_db_test() {
  log "STEP 889 — Vector database test (Qdrant expected at 6333)"
  curl -fsS http://localhost:6333/collections || true
}

graph_db_test() {
  log "STEP 890 — Graph database test (Neo4j expected at 7474)"
  curl -fsS http://localhost:7474 || true
}

write_model_installer() {
  log "STEP 891 — Install dmf7-install-model helper"
  cat <<'EOF' >/usr/local/bin/dmf7-install-model
#!/bin/bash

MODEL=$1

if [ -z "$MODEL" ]; then
  echo "Usage: dmf7-install-model <model>"
  exit 1
fi

echo "================================="
echo " DMF7 MODEL INSTALL "
echo "================================="
echo "Model: $MODEL"
echo ""

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama is required but not found on PATH." >&2
  exit 1
fi

ollama pull "$MODEL"
EOF
  chmod +x /usr/local/bin/dmf7-install-model
}

maybe_verify_stack() {
  if [[ $VERIFY -eq 1 ]]; then
    verify_watchtower
    test_ai_engine
    vector_db_test
    graph_db_test
  else
    log "Post-setup checks skipped (use --verify to enable)"
  fi
}

main() {
  parse_args "$@"
  require_root
  require_cmd docker

  install_watchtower
  create_global_dirs
  write_dmf7_ai
  write_model_installer
  maybe_verify_stack
}

main "$@"
