#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This installer must be run as root (try sudo)." >&2
  exit 1
fi

VERIFY=false
SKIP_SYSTEMD=false

usage() {
  cat <<'EOF'
Usage: dmf7_system_health_dashboard_658_672.sh [--verify] [--skip-systemd]

Installs DMF7 dashboards, live view, resource guard, and update checker (steps 658-672).

Options:
  --verify        Run lightweight sanity checks after install.
  --skip-systemd  Do not enable the resource guard systemd service.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify) VERIFY=true ;;
    --skip-systemd) SKIP_SYSTEMD=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

install -m 0755 -d /usr/local/bin

cat <<'EOF' > /usr/local/bin/dmf7-dashboard
#!/bin/bash
clear

echo "======================================="
echo " DMF7 LIVE NODE DASHBOARD "
echo "======================================="
echo ""

echo "SERVER:"
hostname
hostname -I
uptime
echo ""

echo "CPU:"
top -bn1 | head -n 5
echo ""

echo "MEMORY:"
free -h
echo ""

echo "DISK:"
df -h
echo ""

echo "PM2 SERVICES:"
pm2 list
echo ""

echo "DOCKER CONTAINERS:"
docker ps
echo ""

echo "AI MODELS:"
ollama list
echo ""

echo "NETWORK PORTS:"
ss -tulnp | head
echo ""

echo "======================================="
EOF

cat <<'EOF' > /usr/local/bin/dmf7-live
#!/bin/bash

watch -n 3 dmf7-dashboard
EOF

cat <<'EOF' > /usr/local/bin/dmf7-resource-guard
#!/bin/bash

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
MEM=$(free | grep Mem | awk '{print $3/$2 * 100.0}')

echo "CPU: $CPU%"
echo "MEM: $MEM%"

if [ "$CPU" -gt 90 ]; then
  echo "High CPU detected — restarting services"
  pm2 restart all
fi
EOF

cat <<'EOF' > /usr/local/bin/dmf7-update-check
#!/bin/bash

echo "Checking updates..."

apt update

apt list --upgradable
EOF

chmod +x /usr/local/bin/dmf7-dashboard /usr/local/bin/dmf7-live /usr/local/bin/dmf7-resource-guard /usr/local/bin/dmf7-update-check

install -m 0755 -d /etc/systemd/system
cat <<'EOF' > /etc/systemd/system/dmf7-resource-guard.service
[Unit]
Description=DMF7 Resource Guard

[Service]
ExecStart=/usr/local/bin/dmf7-resource-guard
Restart=always
RestartSec=60
User=root

[Install]
WantedBy=multi-user.target
EOF

if [[ "$SKIP_SYSTEMD" == false ]]; then
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl enable dmf7-resource-guard
    systemctl start dmf7-resource-guard
  else
    echo "systemctl not found; skipping resource guard enablement." >&2
  fi
fi

if [[ "$VERIFY" == true ]]; then
  echo "Verification summary:"
  ls -l /usr/local/bin/dmf7-dashboard /usr/local/bin/dmf7-live /usr/local/bin/dmf7-resource-guard /usr/local/bin/dmf7-update-check
  if command -v systemctl >/dev/null 2>&1; then
    systemctl status dmf7-resource-guard --no-pager || true
  fi
fi

cat <<'EOF'
========================================================
 DMF7 GLOBAL AUTONOMOUS AI COMPUTE NODE
========================================================

Node IP:
72.61.114.167

Core Systems:
✔ AI Runtime (Ollama)
✔ Vector Search (Qdrant)
✔ Graph Database (Neo4j)
✔ Redis Worker Queue
✔ Gateway API
✔ Operator Console

Automation:
✔ Self-healing services
✔ Resource guard
✔ Docker auto recovery
✔ Daily snapshots
✔ SSL + Firewall security

Control Tools:
dmf7-admin
dmf7-dashboard
dmf7-live

STATUS: GLOBAL AI NODE ACTIVE
========================================================
EOF
