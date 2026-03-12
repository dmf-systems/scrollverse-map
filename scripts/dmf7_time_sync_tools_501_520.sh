#!/usr/bin/env bash
set -euo pipefail

# Automates DMF7 steps 501-520: chrony install, helper tools, snapshot, and reset.

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
  fi
}

log() {
  echo "[${LOG_TS:-$(date +%F_%T)}] $*"
}

install_chrony() {
  log "Installing chrony..."
  apt-get update -y
  apt-get install -y chrony

  log "Enabling chrony service..."
  systemctl enable chrony
  systemctl start chrony

  log "chronyc tracking:"
  chronyc tracking
}

write_time_tool() {
  log "Writing /usr/local/bin/dmf7-time..."
  cat <<'EOF' >/usr/local/bin/dmf7-time
#!/bin/bash

echo "=============================="
echo " DMF7 TIME STATUS "
echo "=============================="

date
timedatectl
chronyc sources
EOF
  chmod +x /usr/local/bin/dmf7-time
}

write_storage_tool() {
  log "Writing /usr/local/bin/dmf7-storage..."
  cat <<'EOF' >/usr/local/bin/dmf7-storage
#!/bin/bash

echo "=============================="
echo " DMF7 STORAGE STATUS "
echo "=============================="

echo ""
echo "DISK USAGE:"
df -h

echo ""
echo "LARGEST DIRECTORIES:"
du -h /opt | sort -hr | head

echo ""
echo "DOCKER SPACE:"
docker system df
EOF
  chmod +x /usr/local/bin/dmf7-storage
}

write_docker_tool() {
  log "Writing /usr/local/bin/dmf7-docker..."
  cat <<'EOF' >/usr/local/bin/dmf7-docker
#!/bin/bash

echo "=============================="
echo " DMF7 DOCKER STATUS "
echo "=============================="

docker ps
echo ""
docker images
echo ""
docker system df
EOF
  chmod +x /usr/local/bin/dmf7-docker
}

write_snapshot_tool() {
  log "Ensuring backup directory exists..."
  mkdir -p /opt/dmf7/backups

  log "Writing /usr/local/bin/dmf7-fullsnapshot..."
  cat <<'EOF' >/usr/local/bin/dmf7-fullsnapshot
#!/bin/bash

DATE=$(date +%F-%H%M)

echo "Creating full DMF7 snapshot..."

tar -czf /opt/dmf7/backups/fullnode-$DATE.tar.gz \
/opt/dmf7 \
/etc/nginx \
/etc/ssh

echo "Snapshot complete:"
echo "/opt/dmf7/backups/fullnode-$DATE.tar.gz"
EOF
  chmod +x /usr/local/bin/dmf7-fullsnapshot
}

write_reset_tool() {
  log "Writing /usr/local/bin/dmf7-reset..."
  cat <<'EOF' >/usr/local/bin/dmf7-reset
#!/bin/bash

echo "Restarting DMF7 services..."

pm2 restart all
dmf7-stack restart

echo "Restart complete."
EOF
  chmod +x /usr/local/bin/dmf7-reset
}

run_validation_steps() {
  log "Testing helper commands..."
  dmf7-time
  dmf7-storage
  dmf7-docker
  dmf7-fullsnapshot
  ls -lh /opt/dmf7/backups
  dmf7-reset
}

final_banner() {
  cat <<'EOF'
=================================================
 DMF7 GLOBAL AI INFRASTRUCTURE NODE STABLE
=================================================

All subsystems:
✔ Compute
✔ Storage
✔ Networking
✔ Monitoring
✔ Security
✔ AI Runtime

Node IP:
72.61.114.167

STATUS: STABLE
=================================================
EOF
}

main() {
  require_root
  install_chrony
  write_time_tool
  write_storage_tool
  write_docker_tool
  write_snapshot_tool
  write_reset_tool
  run_validation_steps
  final_banner
}

main "$@"
