#!/usr/bin/env bash
set -euo pipefail

MAINTENANCE_SCRIPT="/usr/local/bin/dmf7-maintenance"
INFO_SCRIPT="/usr/local/bin/dmf7-info"
LOG_DIR="/opt/dmf7/logs"
LOG_FILE="${LOG_DIR}/maintenance.log"
CRON_LINE="0 2 * * 0 ${MAINTENANCE_SCRIPT} > ${LOG_FILE} 2>&1"

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "This script must be run as root (it writes to /usr/local/bin and manages services)." >&2
    exit 1
  fi
}

write_maintenance_script() {
  cat <<'EOF' > "${MAINTENANCE_SCRIPT}"
#!/bin/bash

echo "Running DMF7 maintenance..."

apt update -y
apt upgrade -y
apt autoremove -y

docker system prune -f

pm2 flush

echo "Maintenance complete"
EOF
  chmod +x "${MAINTENANCE_SCRIPT}"
}

write_info_script() {
  cat <<'EOF' > "${INFO_SCRIPT}"
#!/bin/bash

echo "===== DMF7 NODE INFO ====="
echo ""
echo "Hostname:"
hostname
echo ""

echo "IP Address:"
hostname -I
echo ""

echo "Node Version:"
node -v
echo ""

echo "PNPM Version:"
pnpm -v
echo ""

echo "Docker Version:"
docker --version
echo ""

echo "PM2 Version:"
pm2 -v
echo ""

echo "Disk:"
df -h /
echo ""

echo "Memory:"
free -h
echo ""

echo "CPU:"
lscpu | grep "Model name"
echo ""
EOF
  chmod +x "${INFO_SCRIPT}"
}

ensure_cron_entry() {
  local current_cron
  current_cron="$(crontab -l 2>/dev/null || true)"

  if ! grep -Fq "${CRON_LINE}" <<< "${current_cron}"; then
    {
      printf "%s\n" "${current_cron}"
      printf "%s\n" "${CRON_LINE}"
    } | crontab -
  fi
}

run_info_and_checks() {
  "${INFO_SCRIPT}"
  ip route
  cat /etc/resolv.conf
  timedatectl
}

install_and_verify_chrony() {
  apt update -y
  apt install -y chrony
  systemctl enable chrony
  systemctl start chrony
  chronyc tracking
}

print_final_banner() {
  cat <<'EOF'
=======================================
 DMF7 NODE STABLE & LOCKED FOR PROD 
=======================================

Management Commands:
dmf7
dmf7-status
dmf7-dashboard
dmf7-restart
dmf7-backup
dmf7-update
dmf7-maintenance
dmf7-info

=======================================
EOF
}

main() {
  require_root
  mkdir -p "${LOG_DIR}"
  write_maintenance_script
  write_info_script
  ensure_cron_entry
  run_info_and_checks
  install_and_verify_chrony
  print_final_banner
}

main "$@"
