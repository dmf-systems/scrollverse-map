#!/usr/bin/env bash
set -euo pipefail

# DMF7 steps 484-500: advanced logging tools, dashboards, health reports, cron, and diagnostics

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run this script as root (required for apt, cron, and /usr/local/bin writes)." >&2
  exit 1
fi

LOG_DIR="/opt/dmf7/logs"
BIN_DIR="/usr/local/bin"
CRON_ENTRY="0 2 * * * ${BIN_DIR}/dmf7-health-report"

mkdir -p "${LOG_DIR}"

echo "Installing logging utilities (jq, multitail)..."
apt-get update -y
apt-get install -y jq multitail

echo "Creating DMF7 log dashboard..."
cat > "${BIN_DIR}/dmf7-logview" <<'EOF'
#!/bin/bash
set -euo pipefail

LOG_DIR="/opt/dmf7/logs"

echo "=============================="
echo " DMF7 LOG DASHBOARD "
echo "=============================="
echo ""

echo "PM2 LOGS:"
if command -v pm2 >/dev/null 2>&1; then
  pm2 logs --nostream --lines 30 || true
else
  echo "pm2 not installed"
fi

echo ""
echo "WATCHDOG LOG:"
if [[ -f "${LOG_DIR}/watchdog.log" ]]; then
  tail -n 20 "${LOG_DIR}/watchdog.log"
else
  echo "missing: ${LOG_DIR}/watchdog.log"
fi

echo ""
echo "BACKUP LOG:"
if [[ -f "${LOG_DIR}/backup.log" ]]; then
  tail -n 20 "${LOG_DIR}/backup.log"
else
  echo "missing: ${LOG_DIR}/backup.log"
fi

echo ""
echo "ALERT LOG:"
if [[ -f "${LOG_DIR}/alerts.log" ]]; then
  tail -n 20 "${LOG_DIR}/alerts.log"
else
  echo "missing: ${LOG_DIR}/alerts.log"
fi
EOF
chmod +x "${BIN_DIR}/dmf7-logview"

echo "Creating live multi-log viewer..."
cat > "${BIN_DIR}/dmf7-logs-live" <<'EOF'
#!/bin/bash
set -euo pipefail

multitail \
  /opt/dmf7/logs/watchdog.log \
  /opt/dmf7/logs/backup.log \
  /opt/dmf7/logs/alerts.log
EOF
chmod +x "${BIN_DIR}/dmf7-logs-live"

echo "Creating health report generator..."
cat > "${BIN_DIR}/dmf7-health-report" <<'EOF'
#!/bin/bash
set -euo pipefail

LOG_DIR="/opt/dmf7/logs"
mkdir -p "${LOG_DIR}"
REPORT="${LOG_DIR}/health-$(date +%F).txt"

{
  echo "DMF7 HEALTH REPORT"
  echo "=================="
  echo ""
  echo "UPTIME:"
  uptime
  echo ""
  echo "MEMORY:"
  free -h
  echo ""
  echo "DISK:"
  df -h
  echo ""
  echo "DOCKER:"
  if command -v docker >/dev/null 2>&1; then
    docker ps
  else
    echo "docker not installed"
  fi
  echo ""
  echo "PM2:"
  if command -v pm2 >/dev/null 2>&1; then
    pm2 list
  else
    echo "pm2 not installed"
  fi
  echo ""
  echo "PORTS:"
  ss -tulnp
  echo ""
  echo "REPORT COMPLETE"
} > "${REPORT}"

echo "Report written to ${REPORT}"
EOF
chmod +x "${BIN_DIR}/dmf7-health-report"

echo "Generating first health report..."
"${BIN_DIR}/dmf7-health-report"
echo "Health reports directory contents:"
ls -lh "${LOG_DIR}"

echo "Scheduling daily health report via cron..."
tmp_cron=$(mktemp)
crontab -l 2>/dev/null > "${tmp_cron}" || true
if ! grep -F "${CRON_ENTRY}" "${tmp_cron}" >/dev/null 2>&1; then
  echo "${CRON_ENTRY}" >> "${tmp_cron}"
  crontab "${tmp_cron}"
fi
rm -f "${tmp_cron}"
echo "Current cron schedule:"
crontab -l

echo "Creating diagnostic command..."
cat > "${BIN_DIR}/dmf7-diagnose" <<'EOF'
#!/bin/bash
set -euo pipefail

echo "=============================="
echo " DMF7 DIAGNOSTIC REPORT "
echo "=============================="

echo ""
echo "SYSTEM:"
uname -a

echo ""
echo "UPTIME:"
uptime

echo ""
echo "MEMORY:"
free -h

echo ""
echo "DISK:"
df -h

echo ""
echo "SERVICES:"
if command -v pm2 >/dev/null 2>&1; then
  pm2 list
else
  echo "pm2 not installed"
fi

echo ""
echo "CONTAINERS:"
if command -v docker >/dev/null 2>&1; then
  docker ps
else
  echo "docker not installed"
fi
EOF
chmod +x "${BIN_DIR}/dmf7-diagnose"

echo "Running diagnostic snapshot..."
"${BIN_DIR}/dmf7-diagnose"

echo "Testing log dashboard (non-streaming)..."
timeout 5 "${BIN_DIR}/dmf7-logview" || true

echo "Testing live log viewer for a short interval..."
timeout 5 "${BIN_DIR}/dmf7-logs-live" || true

echo "================================================="
echo " DMF7 GLOBAL AI NODE INFRASTRUCTURE COMPLETE "
echo "================================================="
echo ""
echo "Server IP:"
echo "72.61.114.167"
echo ""
echo "Console:"
echo "http://72.61.114.167"
echo ""
echo "API:"
echo "http://72.61.114.167:4000"
echo ""
echo "AI:"
echo "http://72.61.114.167:3001"
echo ""
echo "Graph:"
echo "http://72.61.114.167:7474"
echo ""
echo "Vector:"
echo "http://72.61.114.167:6333"
echo ""
echo "Monitoring:"
echo "http://72.61.114.167:3000"
echo "http://72.61.114.167:9000"
echo ""
echo "STATUS: FULLY DEPLOYED"
echo "================================================="
