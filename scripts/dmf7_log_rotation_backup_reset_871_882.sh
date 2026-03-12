#!/usr/bin/env bash
set -euo pipefail

# DMF7 steps 871-882 automation:
#  - Install logrotate and configure DMF7 log rotation
#  - Create and schedule backup command
#  - Install platform reset tool
#  - Print final status banner
# Defaults run the full sequence; flags allow skipping disruptive steps.

LOGROTATE_CONF="/etc/logrotate.d/dmf7"
BACKUP_SCRIPT="/usr/local/bin/dmf7-backup"
RESET_SCRIPT="/usr/local/bin/dmf7-reset"
CRON_LINE="0 2 * * * /usr/local/bin/dmf7-backup > /opt/dmf7/backup.log 2>&1"

RUN_RESET=0
SKIP_BACKUP_RUN=0
SKIP_LOGROTATE_TEST=0
SKIP_CRON=0

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: dmf7_log_rotation_backup_reset_871_882.sh [options]
Options:
  --skip-backup-run       Skip running the initial backup after installing the script
  --skip-logrotate-test   Skip the logrotate dry run (logrotate -d /etc/logrotate.conf)
  --skip-cron             Do not install the daily backup cron job
  --run-reset             Run the reset tool once after installation (restarts PM2, docker, nginx)
  -h, --help              Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-backup-run) SKIP_BACKUP_RUN=1 ;;
      --skip-logrotate-test) SKIP_LOGROTATE_TEST=1 ;;
      --skip-cron) SKIP_CRON=1 ;;
      --run-reset) RUN_RESET=1 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "Unknown option: $1" ;;
    esac
    shift
  done
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "Run this script as root (sudo)."
  fi
}

install_logrotate() {
  if dpkg -s logrotate >/dev/null 2>&1; then
    info "logrotate already installed."
    return
  fi

  info "Installing logrotate..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y logrotate
}

write_logrotate_config() {
  info "Writing DMF7 logrotate config to ${LOGROTATE_CONF}..."
  cat > "${LOGROTATE_CONF}" <<'EOF'
/opt/dmf7/*.log
/root/.pm2/logs/*.log
{
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
}

test_logrotate() {
  info "Testing logrotate configuration (dry run)..."
  logrotate -d /etc/logrotate.conf
}

write_backup_script() {
  info "Creating DMF7 backup script at ${BACKUP_SCRIPT}..."
  cat > "${BACKUP_SCRIPT}" <<'EOF'
#!/bin/bash
set -euo pipefail

DATE="$(date +%F)"

echo "Starting DMF7 backup..."

mkdir -p /opt/dmf7/backups

tar -czf "/opt/dmf7/backups/dmf7-backup-${DATE}.tar.gz" \
  --ignore-failed-read \
  --warning=no-file-changed \
  ~/DMF7 \
  /opt/dmf7 \
  /root/.pm2

echo "Backup completed:"
echo "/opt/dmf7/backups/dmf7-backup-${DATE}.tar.gz"
EOF
  chmod +x "${BACKUP_SCRIPT}"
}

run_initial_backup() {
  info "Running initial DMF7 backup..."
  "${BACKUP_SCRIPT}"
}

ensure_cron_job() {
  if (( SKIP_CRON )); then
    warn "Skipping cron installation per flag."
    return
  fi

  info "Ensuring daily backup cron entry exists..."
  local existing
  existing="$(crontab -l 2>/dev/null || true)"
  if grep -Fq "${CRON_LINE}" <<< "${existing}"; then
    info "Cron entry already present."
    return
  fi

  {
    [[ -n "${existing}" ]] && printf "%s\n" "${existing}"
    printf "%s\n" "${CRON_LINE}"
  } | crontab -
  info "Cron entry added."
}

write_reset_script() {
  info "Creating DMF7 reset tool at ${RESET_SCRIPT}..."
  cat > "${RESET_SCRIPT}" <<'EOF'
#!/bin/bash
set -euo pipefail

echo "Restarting DMF7 platform..."

pm2 restart all
docker restart redis-ai
docker restart qdrant
docker restart neo4j
docker restart ollama

systemctl restart nginx

echo "DMF7 platform restarted."
EOF
  chmod +x "${RESET_SCRIPT}"
}

run_reset_once() {
  if (( RUN_RESET )); then
    info "Running DMF7 reset tool..."
    "${RESET_SCRIPT}"
  else
    warn "Reset tool installed; skipping execution (use --run-reset to run)."
  fi
}

print_final_status() {
  cat <<'EOF'
=======================================
DMF7 NODE OPERATIONS COMPLETE

Gateway: http://72.61.114.167:4000
Console: http://72.61.114.167:4100
AI UI: http://72.61.114.167:3001
Neo4j: http://72.61.114.167:7474
Grafana: http://72.61.114.167:3000
Portainer: http://72.61.114.167:9000

Maintenance Commands:
dmf7-reset
dmf7-backup
dmf7-sync
dmf7-monitor

STATUS: NODE ONLINE AND SELF-MANAGED
=======================================
EOF
}

main() {
  parse_args "$@"
  require_root
  install_logrotate
  write_logrotate_config
  (( SKIP_LOGROTATE_TEST )) || test_logrotate
  write_backup_script
  (( SKIP_BACKUP_RUN )) || run_initial_backup
  ensure_cron_job
  write_reset_script
  run_reset_once
  print_final_status
}

main "$@"
