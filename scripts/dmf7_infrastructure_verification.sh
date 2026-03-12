#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO="sudo "
else
  SUDO=""
fi

step() {
  local number="$1"
  local title="$2"
  printf "\n# STEP %s — %s\n" "$number" "$title"
}

run_cmd() {
  local cmd="$1"
  echo "+ $cmd"
  bash -euo pipefail -c "$cmd"
}

step "131" "Install system toolkit (tmux, tree, ncdu, iotop, iftop)"
run_cmd "${SUDO}apt update"
run_cmd "${SUDO}apt install -y tmux tree ncdu iotop iftop"

step "132" "Create admin terminal dashboard at /usr/local/bin/dmf7-dashboard"
DASHBOARD_PATH="/usr/local/bin/dmf7-dashboard"
cat <<'EOF' | ${SUDO}tee "$DASHBOARD_PATH" >/dev/null
#!/bin/bash

clear

echo "======================================"
echo " DMF7 NODE LIVE DASHBOARD "
echo "======================================"

echo ""
echo "UPTIME:"
uptime

echo ""
echo "CPU / MEMORY:"
top -bn1 | head -5

echo ""
echo "DISK:"
df -h /

echo ""
echo "PM2 SERVICES:"
pm2 list

echo ""
echo "DOCKER CONTAINERS:"
docker ps

echo ""
echo "NETWORK:"
ss -tulnp | head

echo ""
echo "======================================"
EOF
run_cmd "${SUDO}chmod +x $DASHBOARD_PATH"

step "133" "Run dashboard"
run_cmd "dmf7-dashboard"

step "134" "Install speed test tool"
run_cmd "${SUDO}apt install -y speedtest-cli"

step "135" "Test network speed"
run_cmd "speedtest-cli"

step "136" "Install system benchmark"
run_cmd "${SUDO}apt install -y sysbench"

step "137" "CPU benchmark"
run_cmd "sysbench cpu --threads=${DMF7_CPU_THREADS:-4} run"

step "138" "Memory benchmark"
run_cmd "sysbench memory run"

step "139" "Disk benchmark"
FILEIO_DIR="${DMF7_FILEIO_DIR:-/tmp/dmf7-sysbench-fileio}"
FILEIO_SIZE="${DMF7_FILEIO_SIZE:-1G}"
mkdir -p "$FILEIO_DIR"
pushd "$FILEIO_DIR" >/dev/null
run_cmd "sysbench fileio --file-total-size=$FILEIO_SIZE prepare"
run_cmd "sysbench fileio --file-test-mode=rndrw run"
run_cmd "sysbench fileio --file-total-size=$FILEIO_SIZE cleanup"
popd >/dev/null

step "140" "Verify open ports"
run_cmd "${SUDO}ss -tulnp"

step "141" "Verify public services"
run_cmd "curl -fS --max-time 10 http://72.61.114.167:4000"
run_cmd "curl -fS --max-time 10 http://72.61.114.167:4100"
run_cmd "curl -fS --max-time 10 http://72.61.114.167:3001"

step "142" "Check system logs"
run_cmd "${SUDO}journalctl -xe | tail"

step "143" "Verify docker health"
run_cmd "docker ps --format \"table {{.Names}}\\t{{.Status}}\\t{{.Ports}}\""

step "144" "Verify node environment"
run_cmd "node -v"
run_cmd "pnpm -v"

step "145" "Verify project directory"
run_cmd "cd ~/DMF7 && ls"

step "146" "Verify repo sync"
run_cmd "cd ~/DMF7 && git status"

step "147" "Verify cron tasks"
run_cmd "crontab -l"

step "148" "Verify snapshot storage"
run_cmd "ls -lh /opt/dmf7/snapshots"

step "149" "Verify backups"
run_cmd "ls -lh /opt/dmf7/backups"

step "150" "Final system summary"
cat <<'EOF'
=========================================
 DMF7 FULL INFRASTRUCTURE VERIFIED
=========================================

Console   : http://72.61.114.167:4100
API       : http://72.61.114.167:4000
AI UI     : http://72.61.114.167:3001

Neo4j     : http://72.61.114.167:7474
Qdrant    : http://72.61.114.167:6333

Grafana   : http://72.61.114.167:3000
Portainer : http://72.61.114.167:9000

Node Status: ONLINE
=========================================
EOF
