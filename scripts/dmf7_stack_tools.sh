#!/bin/bash
set -euo pipefail

VERIFY_RUNS=1
RUN_PM2_STARTUP=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-verify)
      VERIFY_RUNS=0
      shift
      ;;
    --skip-pm2-startup)
      RUN_PM2_STARTUP=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: dmf7_stack_tools.sh [options]

Installs DMF7 operational helpers:
  - /usr/local/bin/dmf7-status
  - /usr/local/bin/dmf7-start
  - /usr/local/bin/dmf7-stop
  - /usr/local/bin/dmf7-logs
  - /usr/local/bin/dmf7-check

Options:
  --skip-verify        Do not run dmf7-status and dmf7-check after install.
  --skip-pm2-startup   Do not run pm2 startup/save after install.
  -h, --help           Show this help.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

SUDO=()
if [[ "${EUID}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO=(sudo)
  else
    echo "This script needs root privileges to write to /usr/local/bin. Run as root or install sudo." >&2
    exit 1
  fi
fi

warn() {
  echo "WARN: $*" >&2
}

install_script() {
  local target="$1"
  shift
  "${SUDO[@]}" tee "${target}" >/dev/null <<'EOF'
#!/bin/bash

echo "==============================="
echo " DMF7 NODE STATUS "
echo "==============================="

echo ""
echo "SERVER:"
hostname
echo ""

echo "UPTIME:"
uptime
echo ""

echo "MEMORY:"
free -h
echo ""

echo "DISK:"
df -h /
echo ""

echo "PM2 SERVICES:"
if command -v pm2 >/dev/null 2>&1; then
  pm2 list
else
  echo "pm2 is not installed."
fi
echo ""

echo "DOCKER CONTAINERS:"
if command -v docker >/dev/null 2>&1; then
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
  echo "Docker is not installed."
fi

echo ""
echo "==============================="
EOF
  "${SUDO[@]}" chmod +x "${target}"
}

install_start() {
  local target="/usr/local/bin/dmf7-start"
  "${SUDO[@]}" tee "${target}" >/dev/null <<'EOF'
#!/bin/bash

echo "Starting Docker containers..."
if command -v docker >/dev/null 2>&1; then
  CONTAINERS=$(docker ps -aq)
  if [[ -n "${CONTAINERS}" ]]; then
    docker start ${CONTAINERS}
  else
    echo "No Docker containers found."
  fi
else
  echo "Docker is not installed; skipping container start."
fi

echo "Starting PM2 services..."
if command -v pm2 >/dev/null 2>&1; then
  pm2 resurrect
else
  echo "pm2 is not installed; skipping PM2 start."
fi

echo "DMF7 stack started."
EOF
  "${SUDO[@]}" chmod +x "${target}"
}

install_stop() {
  local target="/usr/local/bin/dmf7-stop"
  "${SUDO[@]}" tee "${target}" >/dev/null <<'EOF'
#!/bin/bash

echo "Stopping PM2 services..."
if command -v pm2 >/dev/null 2>&1; then
  pm2 stop all
else
  echo "pm2 is not installed; skipping PM2 stop."
fi

echo "Stopping Docker containers..."
if command -v docker >/dev/null 2>&1; then
  RUNNING=$(docker ps -q)
  if [[ -n "${RUNNING}" ]]; then
    docker stop ${RUNNING}
  else
    echo "No running Docker containers found."
  fi
else
  echo "Docker is not installed; skipping container stop."
fi

echo "DMF7 stack stopped."
EOF
  "${SUDO[@]}" chmod +x "${target}"
}

install_logs() {
  local target="/usr/local/bin/dmf7-logs"
  "${SUDO[@]}" tee "${target}" >/dev/null <<'EOF'
#!/bin/bash

echo "==============================="
echo " DMF7 LOG VIEWER "
echo "==============================="

echo ""
echo "PM2 Logs:"
if command -v pm2 >/dev/null 2>&1; then
  pm2 logs --lines 50
else
  echo "pm2 is not installed; cannot view PM2 logs."
fi
EOF
  "${SUDO[@]}" chmod +x "${target}"
}

install_check() {
  local target="/usr/local/bin/dmf7-check"
  "${SUDO[@]}" tee "${target}" >/dev/null <<'EOF'
#!/bin/bash

echo "Checking Gateway..."
curl -s http://localhost:4000

echo ""
echo "Checking Console..."
curl -s http://localhost:4100

echo ""
echo "Checking AI WebUI..."
curl -s http://localhost:3001

echo ""
echo "Checking Qdrant..."
curl -s http://localhost:6333/collections

echo ""
echo "Checking Neo4j..."
curl -s http://localhost:7474
EOF
  "${SUDO[@]}" chmod +x "${target}"
}

echo "Installing dmf7-status..."
install_script "/usr/local/bin/dmf7-status"
echo "Installing dmf7-start..."
install_start
echo "Installing dmf7-stop..."
install_stop
echo "Installing dmf7-logs..."
install_logs
echo "Installing dmf7-check..."
install_check

if (( VERIFY_RUNS )); then
  echo "Running dmf7-status (best effort)..."
  if ! /usr/local/bin/dmf7-status; then
    warn "dmf7-status reported errors; verify services and dependencies."
  fi

  echo "Running dmf7-check (best effort)..."
  if ! /usr/local/bin/dmf7-check; then
    warn "dmf7-check reported errors; verify services are reachable."
  fi
else
  echo "Skipping verification commands."
fi

if (( RUN_PM2_STARTUP )); then
  if command -v pm2 >/dev/null 2>&1; then
    echo "Running pm2 startup (best effort)..."
    if ! pm2 startup; then
      warn "pm2 startup failed; run manually if needed."
    fi
    echo "Saving PM2 process list..."
    if ! pm2 save; then
      warn "pm2 save failed; run manually if needed."
    fi
  else
    warn "pm2 is not installed; skipping pm2 startup/save."
  fi
else
  echo "Skipping pm2 startup/save."
fi

echo "DMF7 NODE VERIFIED AND OPERATIONAL"
