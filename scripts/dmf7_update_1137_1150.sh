#!/usr/bin/env bash
# Automates DMF7 steps 1137-1150: installs update, log cleanup, monitor, and watch helpers.
set -euo pipefail

RUN_UPDATE=1
RUN_MONITOR=1
RUN_ENDPOINTS=1

usage() {
  cat <<'EOF'
Usage: dmf7_update_1137_1150.sh [options]

Installs DMF7 helper scripts:
  - /usr/local/bin/dmf7-update     (pull, install, build, restart, pm2 save)
  - /usr/local/bin/dmf7-log-clean  (delete logs older than 7 days)
  - /usr/local/bin/dmf7-monitor    (CPU/mem/disk/docker/pm2 snapshot)
  - /usr/local/bin/dmf7-watch      (10s monitor loop)
  - Cron: 0 3 * * * /usr/local/bin/dmf7-log-clean

Options:
  --skip-update     Skip running dmf7-update after installing it
  --skip-monitor    Skip running dmf7-monitor test after installing it
  --skip-endpoints  Skip curl checks against 4000/4100/6333
  --help            Show this help
EOF
}

log() {
  printf '[DMF7 1137-1150] %s\n' "$1"
}

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    log "Run this script as root (needed for /usr/local/bin, /opt/dmf7, and crontab)."
    exit 1
  fi
}

ensure_dirs() {
  mkdir -p /usr/local/bin
  mkdir -p /opt/dmf7/logs
}

install_update_script() {
  cat <<'EOF' >/usr/local/bin/dmf7-update
#!/bin/bash

echo "Updating DMF7 repository..."

cd ~/DMF7 || exit

git pull

export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

nvm use 20

pnpm install
pnpm build

pm2 restart dmf7-gateway
pm2 restart dmf7-console
pm2 restart dmf7-ingest
pm2 restart dmf7-retrieval

pm2 save

echo "DMF7 updated successfully."
EOF
  chmod +x /usr/local/bin/dmf7-update
  log "Installed /usr/local/bin/dmf7-update"
}

install_log_clean_script() {
  cat <<'EOF' >/usr/local/bin/dmf7-log-clean
#!/bin/bash

find /opt/dmf7/logs -type f -mtime +7 -delete
echo "Old logs cleaned."
EOF
  chmod +x /usr/local/bin/dmf7-log-clean
  log "Installed /usr/local/bin/dmf7-log-clean"
}

install_monitor_script() {
  cat <<'EOF' >/usr/local/bin/dmf7-monitor
#!/bin/bash

echo "===== DMF7 RESOURCE MONITOR ====="

echo ""
echo "CPU:"
top -b -n1 | head -n5

echo ""
echo "Memory:"
free -h

echo ""
echo "Disk:"
df -h

echo ""
echo "Docker:"
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "PM2:"
pm2 list
EOF
  chmod +x /usr/local/bin/dmf7-monitor
  log "Installed /usr/local/bin/dmf7-monitor"
}

install_watch_script() {
  cat <<'EOF' >/usr/local/bin/dmf7-watch
#!/bin/bash

while true
do
clear
dmf7-monitor
sleep 10
done
EOF
  chmod +x /usr/local/bin/dmf7-watch
  log "Installed /usr/local/bin/dmf7-watch"
}

schedule_log_clean_cron() {
  local cron_entry="0 3 * * * /usr/local/bin/dmf7-log-clean"
  local tmp
  tmp=$(mktemp)

  crontab -l 2>/dev/null | grep -v "/usr/local/bin/dmf7-log-clean" >"$tmp" || true
  printf "%s\n" "$cron_entry" >>"$tmp"
  crontab "$tmp"
  rm -f "$tmp"
  log "Scheduled daily log clean at 03:00"
}

run_update_if_requested() {
  if [[ $RUN_UPDATE -eq 0 ]]; then
    log "Skipping dmf7-update run (per flag)."
    return
  fi

  if [[ -d "$HOME/DMF7" ]]; then
    if /usr/local/bin/dmf7-update; then
      log "dmf7-update completed."
    else
      log "dmf7-update finished with errors; check output above."
    fi
  else
    log "Skipping dmf7-update run because ~/DMF7 does not exist."
  fi
}

run_monitor_if_requested() {
  if [[ $RUN_MONITOR -eq 0 ]]; then
    log "Skipping monitor test run (per flag)."
    return
  fi

  if /usr/local/bin/dmf7-monitor; then
    log "dmf7-monitor ran successfully."
  else
    log "dmf7-monitor encountered errors; check output above."
  fi
}

check_endpoints_if_requested() {
  if [[ $RUN_ENDPOINTS -eq 0 ]]; then
    log "Skipping endpoint verification (per flag)."
    return
  fi

  local endpoints=("http://localhost:4000" "http://localhost:4100" "http://localhost:6333")
  for url in "${endpoints[@]}"; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      log "Endpoint reachable: $url"
    else
      log "Endpoint check failed (service may be down): $url"
    fi
  done
}

print_final_banner() {
  cat <<'EOF'
========================================
DMF7 GLOBAL NODE READY

Gateway: http://72.61.114.167:4000
Console: http://72.61.114.167:4100
OpenWebUI: http://72.61.114.167:3001
Neo4j: http://72.61.114.167:7474
Grafana: http://72.61.114.167:3000
Portainer: http://72.61.114.167:9000

STATUS: NODE OPERATIONAL
========================================
EOF
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-update) RUN_UPDATE=0 ;;
      --skip-monitor) RUN_MONITOR=0 ;;
      --skip-endpoints) RUN_ENDPOINTS=0 ;;
      --help) usage; exit 0 ;;
      *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
  done

  require_root
  ensure_dirs

  install_update_script
  install_log_clean_script
  schedule_log_clean_cron
  install_monitor_script
  install_watch_script

  run_update_if_requested
  run_monitor_if_requested
  check_endpoints_if_requested
  print_final_banner
}

main "$@"
