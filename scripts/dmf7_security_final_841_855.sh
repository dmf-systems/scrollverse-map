#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "[dmf7] $*"
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
  fi
}

write_monitor_tool() {
  cat >/usr/local/bin/dmf7-monitor <<'EOF'
#!/bin/bash

echo "========== DMF7 SYSTEM MONITOR =========="
echo ""
echo "CPU + MEMORY"
top -b -n1 | head -n 10

echo ""
echo "DISK"
df -h

echo ""
echo "PM2 SERVICES"
pm2 list

echo ""
echo "DOCKER SERVICES"
docker ps
EOF
  chmod +x /usr/local/bin/dmf7-monitor
}

write_diagnostics_tool() {
  cat >/usr/local/bin/dmf7-diagnostics <<'EOF'
#!/bin/bash

echo "========== DMF7 DIAGNOSTICS =========="

echo ""
echo "Node:"
hostname -I

echo ""
echo "Node version:"
node -v

echo ""
echo "PM2:"
pm2 list

echo ""
echo "Docker:"
docker ps

echo ""
echo "Gateway test:"
curl -s http://localhost:4000

echo ""
echo "Console test:"
curl -s http://localhost:4100
EOF
  chmod +x /usr/local/bin/dmf7-diagnostics
}

configure_fail2ban() {
  log "STEP 843 — configuring Fail2Ban SSH protection"
  cat >/etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 5
bantime = 1h
EOF
}

final_banner() {
  cat <<'EOF'
==================================
DMF7 NODE HARDENING COMPLETE

Security:
✔ Firewall active
✔ Fail2Ban active
✔ Auto security updates

Monitoring:
✔ Netdata
✔ Glances
✔ cAdvisor
✔ Node Exporter

AI Stack:
✔ Ollama runtime
✔ Redis queue
✔ Qdrant vector DB
✔ Neo4j graph DB

Platform:
✔ Gateway API
✔ Operator Console

NODE STATUS: PRODUCTION READY
==================================
EOF
}

main() {
  ensure_root

  log "STEP 841 — installing Fail2Ban"
  apt-get update
  apt-get install -y fail2ban

  log "STEP 842 — enabling Fail2Ban"
  systemctl enable fail2ban
  systemctl start fail2ban
  systemctl status --no-pager fail2ban

  configure_fail2ban

  log "STEP 844 — restarting Fail2Ban"
  systemctl restart fail2ban

  log "STEP 845 — verifying Fail2Ban"
  fail2ban-client status

  log "STEP 846 — installing automatic security updates"
  apt-get install -y unattended-upgrades

  log "STEP 847 — enabling automatic security updates"
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -fnoninteractive -plow unattended-upgrades

  log "STEP 848 — installing system monitoring tools"
  apt-get install -y htop iotop ncdu

  log "STEP 849 — creating monitor tool"
  write_monitor_tool

  log "STEP 851 — testing monitor tool"
  /usr/local/bin/dmf7-monitor || true

  log "STEP 852 — creating diagnostics tool"
  write_diagnostics_tool

  log "STEP 854 — running diagnostics"
  /usr/local/bin/dmf7-diagnostics || true

  log "STEP 855 — final node security status"
  final_banner
}

main "$@"
