#!/usr/bin/env bash
# DMF7 platform deployment helper for steps 211-226.
# This script installs GitHub CLI, authenticates, prepares the DMF7 directories,
# creates the update helper, wires a nightly cron job, writes the VERSION file,
# and prints a final status banner.

set -euo pipefail

DMF_ROOT="/opt/dmf7"
PLATFORM_SRC="${HOME}/DMF7"
PLATFORM_DIR="${DMF_ROOT}/platform"
UPDATE_SCRIPT="/usr/local/bin/dmf7-update"
LOG_DIR="${DMF_ROOT}/logs"
BACKUP_DIR="${DMF_ROOT}/backups"
SCRIPTS_DIR="${DMF_ROOT}/scripts"
VERSION_FILE="${DMF_ROOT}/VERSION"
CRON_LINE='0 3 * * * /usr/local/bin/dmf7-update > /opt/dmf7/logs/update.log 2>&1'

log() {
  printf "[%s] %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*"
}

ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

with_sudo() {
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

install_github_cli() {
  if command -v gh >/dev/null 2>&1; then
    log "GitHub CLI already installed."
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    log "apt-get not available; cannot install GitHub CLI automatically."
    exit 1
  fi

  log "Installing GitHub CLI..."
  with_sudo apt-get update -y
  with_sudo apt-get install -y gh
}

authenticate_github_cli() {
  if gh auth status >/dev/null 2>&1; then
    log "GitHub CLI already authenticated."
    return
  fi

  log "Authenticating GitHub CLI via browser..."
  gh auth login --hostname github.com --git-protocol https --web
}

prepare_directories() {
  log "Creating DMF7 directories under ${DMF_ROOT}..."
  with_sudo mkdir -p "${DMF_ROOT}" "${BACKUP_DIR}" "${LOG_DIR}" "${SCRIPTS_DIR}"
}

move_repository() {
  if [ -d "${PLATFORM_DIR}" ]; then
    log "Platform directory already present at ${PLATFORM_DIR}; skipping move."
    return
  fi

  if [ -d "${PLATFORM_SRC}" ]; then
    log "Moving repository from ${PLATFORM_SRC} to ${PLATFORM_DIR}..."
    with_sudo mv "${PLATFORM_SRC}" "${PLATFORM_DIR}"
  else
    log "Source repository not found at ${PLATFORM_SRC}; skipping move."
  fi
}

create_update_script() {
  log "Writing update helper to ${UPDATE_SCRIPT}..."
  read -r -d '' SCRIPT_CONTENT <<'EOF'
#!/bin/bash
set -euo pipefail

echo "Updating DMF7 platform..."

cd /opt/dmf7/platform

git pull

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1090
  source "$NVM_DIR/nvm.sh"
fi

pnpm install
pnpm build

pm2 restart all

echo "Update complete."
EOF

  printf "%s\n" "${SCRIPT_CONTENT}" | with_sudo tee "${UPDATE_SCRIPT}" >/dev/null
  with_sudo chmod +x "${UPDATE_SCRIPT}"
}

ensure_cron_job() {
  log "Ensuring nightly update cron job is present..."
  tmp_cron="$(mktemp)"
  crontab -l 2>/dev/null | grep -Fv "${CRON_LINE}" >"${tmp_cron}" || true
  echo "${CRON_LINE}" >>"${tmp_cron}"
  crontab "${tmp_cron}"
  rm -f "${tmp_cron}"
}

write_version_file() {
  log "Writing version marker to ${VERSION_FILE}..."
  echo "DMF7-NEXTGEN-PRODUCTION" | with_sudo tee "${VERSION_FILE}" >/dev/null
}

verify_status() {
  log "Verifying platform directory..."
  with_sudo ls -lh "${DMF_ROOT}" || true

  log "Verifying platform repository..."
  with_sudo ls -lh "${PLATFORM_DIR}" || true

  if command -v docker >/dev/null 2>&1; then
    log "Docker containers:"
    docker ps || true
  else
    log "Docker not installed; skipping docker ps."
  fi

  if command -v pm2 >/dev/null 2>&1; then
    log "PM2 services:"
    pm2 list || true
  else
    log "PM2 not installed; skipping pm2 list."
  fi
}

final_banner() {
  cat <<'EOF'
=======================================
DMF7 NEXTGEN PLATFORM DEPLOYMENT ACTIVE
=======================================

Gateway API: http://72.61.114.167:4000
Operator Console: http://72.61.114.167:4100
AI Interface: http://72.61.114.167:3001

Graph DB: http://72.61.114.167:7474
Vector DB: http://72.61.114.167:6333

Monitoring:
Grafana: http://72.61.114.167:3000
Portainer: http://72.61.114.167:9000

NODE STATUS: LIVE
=======================================
EOF
}

main() {
  ensure_command mktemp
  install_github_cli
  authenticate_github_cli
  prepare_directories
  move_repository
  create_update_script
  ensure_cron_job
  write_version_file
  verify_status
  final_banner
}

main "$@"
