#!/usr/bin/env bash
set -euo pipefail

# DMF7 Backup Automation (Steps 311-323)
BACKUP_ROOT="/opt/dmf7/backups"
LOG_DIR="/opt/dmf7/logs"
BACKUP_SCRIPT="/usr/local/bin/dmf7-backup"
CLEAN_SCRIPT="/usr/local/bin/dmf7-backup-clean"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

ensure_packages() {
  log "Updating apt package index..."
  apt-get update -y
  log "Installing backup utilities (rsync, tar)..."
  apt-get install -y rsync tar
}

ensure_directories() {
  log "Creating backup directories..."
  mkdir -p "${BACKUP_ROOT}/system" "${BACKUP_ROOT}/database" "${BACKUP_ROOT}/platform" "${BACKUP_ROOT}/docker"
  mkdir -p "${LOG_DIR}"
}

write_backup_script() {
  log "Writing platform backup script to ${BACKUP_SCRIPT}..."
  cat > "${BACKUP_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/opt/dmf7/backups"
DATE=$(date +%F-%H%M)

mkdir -p "${BACKUP_DIR}/platform" "${BACKUP_DIR}/docker" "${BACKUP_DIR}/system"

echo "Starting DMF7 backup..."

if [ -d /opt/dmf7/platform ]; then
  tar -czf "${BACKUP_DIR}/platform/dmf7-platform-${DATE}.tar.gz" /opt/dmf7/platform
else
  echo "WARNING: /opt/dmf7/platform not found; skipping platform archive."
fi

if command -v docker >/dev/null 2>&1; then
  docker ps -aq | while read -r container; do
    [ -z "${container}" ] && continue
    docker inspect "${container}" > "${BACKUP_DIR}/docker/${container}_${DATE}.json"
  done
else
  echo "Docker not installed; skipping docker inspection backup."
fi

rsync -a /etc/nginx/ "${BACKUP_DIR}/system/nginx-${DATE}" 2>/dev/null || echo "WARNING: nginx config missing or rsync failed."
rsync -a /etc/ssh/ "${BACKUP_DIR}/system/ssh-${DATE}" 2>/dev/null || echo "WARNING: ssh config missing or rsync failed."

echo "Backup completed: ${DATE}"
EOF
  chmod +x "${BACKUP_SCRIPT}"
}

write_cleanup_script() {
  log "Writing backup cleanup script to ${CLEAN_SCRIPT}..."
  cat > "${CLEAN_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

find /opt/dmf7/backups -type f -mtime +14 -delete

echo "Old backups cleaned"
EOF
  chmod +x "${CLEAN_SCRIPT}"
}

run_initial_backup() {
  log "Running initial backup..."
  if "${BACKUP_SCRIPT}"; then
    ls -lh "/opt/dmf7/backups/platform" 2>/dev/null || true
  else
    log "Initial backup encountered an error."
  fi
}

install_cron_jobs() {
  log "Configuring cron jobs..."
  local backup_entry="0 1 * * * ${BACKUP_SCRIPT} > ${LOG_DIR}/backup.log 2>&1"
  local cleanup_entry="30 1 * * * ${CLEAN_SCRIPT}"
  local current_cron

  current_cron="$(crontab -l 2>/dev/null || true)"

  if ! grep -Fq "${backup_entry}" <<< "${current_cron}"; then
    current_cron="${current_cron}"$'\n'"${backup_entry}"
  fi

  if ! grep -Fq "${cleanup_entry}" <<< "${current_cron}"; then
    current_cron="${current_cron}"$'\n'"${cleanup_entry}"
  fi

  printf "%s\n" "${current_cron}" | sed '/^\s*$/d' | crontab -

  log "Cron entries installed:"
  crontab -l
}

print_status_banner() {
  cat <<'EOF'
==========================================
 DMF7 BACKUP SYSTEM ACTIVE
==========================================

Daily Backup: 01:00
Cleanup: 01:30

Backup Directory:
/opt/dmf7/backups

==========================================
EOF
}

main() {
  ensure_packages
  ensure_directories
  write_backup_script
  write_cleanup_script
  run_initial_backup
  install_cron_jobs
  print_status_banner
}

main "$@"
