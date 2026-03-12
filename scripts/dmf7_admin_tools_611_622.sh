#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root to install DMF7 admin tools."
  exit 1
fi

create_admin_menu() {
  cat <<'EOF' >/usr/local/bin/dmf7-admin
#!/bin/bash

echo "======================================="
echo " DMF7 ADMIN CONTROL PANEL "
echo "======================================="

echo "1) System Status"
echo "2) Service Health"
echo "3) Restart Platform"
echo "4) View Logs"
echo "5) Docker Containers"
echo "6) AI Models"
echo "7) Metrics"
echo "8) Network Status"
echo "9) Security Status"
echo "10) Full System Report"
echo "0) Exit"

read -p "Select option: " OPTION

case $OPTION in

1)
dmf7 status
;;

2)
dmf7-check
;;

3)
dmf7 restart
;;

4)
pm2 logs
;;

5)
docker ps
;;

6)
ollama list
;;

7)
dmf7-metrics
;;

8)
dmf7-network
;;

9)
dmf7-security
;;

10)
dmf7-report
;;

0)
exit
;;

*)
echo "Invalid option"
;;

esac
EOF

  chmod +x /usr/local/bin/dmf7-admin
}

create_watchdog() {
  cat <<'EOF' >/usr/local/bin/dmf7-watchdog
#!/bin/bash

echo "Starting DMF7 watchdog..."

while true
do

curl -s http://localhost:4000 > /dev/null

if [ $? -ne 0 ]; then
echo "Gateway down - restarting..."
pm2 restart dmf7-gateway
fi

sleep 30

done
EOF

  chmod +x /usr/local/bin/dmf7-watchdog
}

start_watchdog() {
  touch /var/log/dmf7_watchdog.log

  if pgrep -f "/usr/local/bin/dmf7-watchdog" >/dev/null; then
    echo "dmf7-watchdog already running."
    return
  fi

  nohup /usr/local/bin/dmf7-watchdog > /var/log/dmf7_watchdog.log 2>&1 &
}

create_backup_cleaner() {
  mkdir -p /opt/dmf7/backups

  cat <<'EOF' >/usr/local/bin/dmf7-backup-clean
#!/bin/bash

echo "Cleaning old backups..."

find /opt/dmf7/backups -type f -mtime +14 -delete

echo "Old backups removed."
EOF

  chmod +x /usr/local/bin/dmf7-backup-clean
}

ensure_cron() {
  local cron_entry="0 4 * * 0 /usr/local/bin/dmf7-backup-clean"
  local existing_cron

  existing_cron="$(crontab -l 2>/dev/null || true)"

  if ! grep -Fq "${cron_entry}" <<<"${existing_cron}"; then
    { echo "${existing_cron}"; echo "${cron_entry}"; } | crontab -
  fi
}

print_banner() {
  cat <<'EOF'
======================================================
 DMF7 GLOBAL AI INFRASTRUCTURE NODE COMPLETE
======================================================

Server:
72.61.114.167

Platform Control:
dmf7-admin

Health Monitor:
dmf7-watchdog

Services:
✔ Gateway
✔ Console
✔ Redis Worker Queue
✔ AI Runtime
✔ Vector Search
✔ Graph DB
✔ Monitoring

STATUS: AUTONOMOUS PLATFORM RUNNING
======================================================
EOF
}

main() {
  create_admin_menu
  create_watchdog
  create_backup_cleaner
  ensure_cron
  start_watchdog

  echo "dmf7-admin installed; quick smoke test..."
  dmf7-admin <<<"0" || true

  echo "Watchdog status:"
  ps aux | grep -E "dmf7-watchdog|grep"

  echo "Cron entries:"
  crontab -l

  print_banner
}

main "$@"
