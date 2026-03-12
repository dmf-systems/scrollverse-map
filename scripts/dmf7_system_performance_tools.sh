#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root (sudo)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

install_performance_tools() {
  apt-get update -y
  apt-get install -y dstat nload bmon ncdu
}

install_live_monitor_script() {
  cat <<'EOF' > /usr/local/bin/dmf7-live
#!/usr/bin/env bash
set -euo pipefail

clear
echo "=============================="
echo " DMF7 LIVE NODE MONITOR "
echo "=============================="

while true
do
  clear

  echo "UPTIME:"
  uptime || echo "uptime command unavailable"
  echo ""

  echo "CPU / MEMORY:"
  if command -v top >/dev/null 2>&1; then
    top -bn1 | head -5
  else
    echo "top command unavailable"
  fi
  echo ""

  echo "DISK:"
  df -h / || echo "df command unavailable"
  echo ""

  echo "DOCKER CONTAINERS:"
  if command -v docker >/dev/null 2>&1; then
    docker ps --format "table {{.Names}}\t{{.Status}}" || echo "docker is not running"
  else
    echo "docker not available"
  fi
  echo ""

  echo "PM2 SERVICES:"
  if command -v pm2 >/dev/null 2>&1; then
    pm2 list || echo "pm2 is not running"
  else
    echo "pm2 not available"
  fi
  echo ""

  sleep 3
done
EOF

  chmod +x /usr/local/bin/dmf7-live
}

install_report_script() {
  cat <<'EOF' > /usr/local/bin/dmf7-report
#!/usr/bin/env bash
set -euo pipefail

REPORT="/opt/dmf7/reports/report-$(date +%F).txt"
REPORT_DIR="$(dirname "$REPORT")"
mkdir -p "$REPORT_DIR"

{
  echo "DMF7 SYSTEM REPORT"
  echo "==================="
  echo

  echo "UPTIME:"
  if command -v uptime >/dev/null 2>&1; then
    uptime
  else
    echo "uptime command unavailable"
  fi

  echo
  echo "CPU:"
  if command -v lscpu >/dev/null 2>&1; then
    lscpu | grep -i "Model name" || lscpu | grep -i "Model"
  else
    echo "lscpu not available"
  fi

  echo
  echo "MEMORY:"
  if command -v free >/dev/null 2>&1; then
    free -h
  else
    echo "free command unavailable"
  fi

  echo
  echo "DISK:"
  if command -v df >/dev/null 2>&1; then
    df -h
  else
    echo "df command unavailable"
  fi

  echo
  echo "DOCKER:"
  if command -v docker >/dev/null 2>&1; then
    docker ps || echo "docker is not running"
  else
    echo "docker not available"
  fi

  echo
  echo "PM2:"
  if command -v pm2 >/dev/null 2>&1; then
    pm2 list || echo "pm2 is not running"
  else
    echo "pm2 not available"
  fi

  echo
  echo "NODE:"
  if command -v node >/dev/null 2>&1; then
    node -v
  else
    echo "node not available"
  fi

  echo
  echo "PNPM:"
  if command -v pnpm >/dev/null 2>&1; then
    pnpm -v
  else
    echo "pnpm not available"
  fi

  echo
  echo "END OF REPORT"
} > "$REPORT"

echo "Report created:"
echo "$REPORT"
EOF

  chmod +x /usr/local/bin/dmf7-report
}

generate_sample_report() {
  if /usr/local/bin/dmf7-report; then
    ls -lh /opt/dmf7 || true
  fi
}

main() {
  install_performance_tools
  install_live_monitor_script
  install_report_script
  generate_sample_report

  cat <<'EOF'
Installation complete.

- Run live monitor: dmf7-live (press Ctrl+C to exit)
- Network traffic view: nload (press q to exit)
- Disk usage analysis: ncdu /
- Generate report: dmf7-report
- Verify reports: ls -lh /opt/dmf7/reports
EOF
}

main "$@"
