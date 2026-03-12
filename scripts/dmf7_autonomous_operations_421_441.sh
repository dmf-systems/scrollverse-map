#!/usr/bin/env bash
set -euo pipefail

# Automates DMF7 steps 421-441: tmux session, quick aliases, benchmark,
# snapshot, boot script, rc.local hook, and final status messaging.

APT_UPDATED=0

log() {
  echo "[dmf7-ops] $*"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "Please run as root."
    exit 1
  fi
}

maybe_update_apt() {
  if [[ $APT_UPDATED -eq 0 ]]; then
    log "Updating apt package index..."
    apt-get update -y
    APT_UPDATED=1
  fi
}

ensure_package() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    maybe_update_apt
    log "Installing ${pkg}..."
    apt-get install -y "$pkg"
  else
    log "${pkg} already installed."
  fi
}

setup_tmux_session() {
  ensure_package tmux
  if tmux has-session -t dmf7 2>/dev/null; then
    log "tmux session 'dmf7' already exists."
  else
    log "Creating tmux session 'dmf7' and running dmf7-status."
    tmux new-session -d -s dmf7
    tmux send-keys -t dmf7 "dmf7-status || echo 'dmf7-status not found'" C-m
  fi
}

setup_aliases() {
  local alias_file="${HOME}/.bash_aliases"
  declare -A aliases=(
    [dmf7s]="dmf7-status"
    [dmf7h]="dmf7-health"
    [dmf7m]="dmf7-metrics"
    [dmf7r]="dmf7-stack restart"
    [dmf7b]="dmf7-backup"
    [dmf7w]="dmf7-watch"
    [dmf7c]="dmf7-clean"
    [dmf7t]="dmf7-top"
  )

  touch "$alias_file"
  local added=0
  for key in "${!aliases[@]}"; do
    local line="alias ${key}='${aliases[$key]}'"
    if ! grep -Fxq "$line" "$alias_file"; then
      echo "$line" >>"$alias_file"
      added=1
    fi
  done

  if [[ $added -eq 1 ]]; then
    log "Aliases written to ${alias_file}."
  else
    log "Aliases already present in ${alias_file}."
  fi

  if [[ -f "${HOME}/.bashrc" ]]; then
    # shellcheck disable=SC1090
    . "${HOME}/.bashrc" || true
  fi

  # shellcheck disable=SC1090
  . "$alias_file" || true

  if alias dmf7s >/dev/null 2>&1; then
    log "Alias dmf7s verified."
  else
    log "Alias dmf7s not active; open a new shell to load ~/.bash_aliases."
  fi
}

install_benchmark_script() {
  ensure_package sysbench

  cat <<'EOF' >/usr/local/bin/dmf7-benchmark
#!/bin/bash
set -e

WORKDIR="${TMPDIR:-/tmp}"
TESTFILE="${WORKDIR}/dmf7-benchmark-disk-test"

echo "=============================="
echo " DMF7 VPS BENCHMARK "
echo "=============================="

echo ""
echo "CPU TEST"
sysbench cpu --cpu-max-prime=20000 run

echo ""
echo "MEMORY TEST"
sysbench memory run

echo ""
echo "DISK TEST (writing to ${TESTFILE})"
dd if=/dev/zero of="${TESTFILE}" bs=1G count=1 oflag=dsync
rm -f "${TESTFILE}"
EOF

  chmod +x /usr/local/bin/dmf7-benchmark
  log "Installed /usr/local/bin/dmf7-benchmark."
}

run_benchmark() {
  if command -v dmf7-benchmark >/dev/null 2>&1; then
    log "Running dmf7-benchmark..."
    /usr/local/bin/dmf7-benchmark
  else
    log "dmf7-benchmark not found."
  fi
}

install_snapshot_script() {
  mkdir -p /opt/dmf7/backups

  cat <<'EOF' >/usr/local/bin/dmf7-snapshot
#!/bin/bash
set -e

DATE=$(date +%F-%H%M)
TARGET_DIR="/opt/dmf7"
BACKUP_DIR="/opt/dmf7/backups"

mkdir -p "$TARGET_DIR" "$BACKUP_DIR"

echo "Creating DMF7 snapshot..."
tar -czf "${BACKUP_DIR}/snapshot-${DATE}.tar.gz" "$TARGET_DIR"

echo "Snapshot created:"
echo "${BACKUP_DIR}/snapshot-${DATE}.tar.gz"
EOF

  chmod +x /usr/local/bin/dmf7-snapshot
  log "Installed /usr/local/bin/dmf7-snapshot."
}

create_snapshot() {
  if command -v dmf7-snapshot >/dev/null 2>&1; then
    log "Creating initial snapshot..."
    /usr/local/bin/dmf7-snapshot
    ls -lh /opt/dmf7/backups || true
  else
    log "dmf7-snapshot not found."
  fi
}

install_boot_script() {
  cat <<'EOF' >/usr/local/bin/dmf7-boot
#!/bin/bash
set -e

echo "Starting DMF7 platform..."

if command -v dmf7-stack >/dev/null 2>&1; then
  dmf7-stack start
else
  echo "dmf7-stack not found; skipping stack start."
fi

if command -v pm2 >/dev/null 2>&1; then
  pm2 resurrect
else
  echo "pm2 not found; skipping process resurrection."
fi

echo "DMF7 node online."
EOF

  chmod +x /usr/local/bin/dmf7-boot
  log "Installed /usr/local/bin/dmf7-boot."
}

update_rc_local() {
  if [[ ! -f /etc/rc.local ]]; then
    cat <<'EOF' >/etc/rc.local
#!/bin/sh -e
/usr/local/bin/dmf7-boot
exit 0
EOF
  else
    if ! grep -Fq "/usr/local/bin/dmf7-boot" /etc/rc.local; then
      sed -i '/^exit 0/i /usr/local/bin/dmf7-boot' /etc/rc.local
    fi

    if ! head -n 1 /etc/rc.local | grep -q "^#\!"; then
      sed -i '1i #!/bin/sh -e' /etc/rc.local
    fi
  fi

  chmod +x /etc/rc.local
  log "Current /etc/rc.local:"
  cat /etc/rc.local
}

run_summary_check() {
  if command -v dmf7-summary >/dev/null 2>&1; then
    log "Running dmf7-summary..."
    dmf7-summary || true
  else
    log "dmf7-summary not found; skipping final node summary."
  fi
}

write_deploy_log() {
  mkdir -p /opt/dmf7
  echo "DMF7 GLOBAL NODE ONLINE $(date)" >/opt/dmf7/DEPLOY_LOG
  log "Deployment log:"
  cat /opt/dmf7/DEPLOY_LOG
}

print_final_message() {
  cat <<'EOF'
=================================================
 DMF7 NEXTGEN AUTONOMOUS AI NODE FULLY DEPLOYED
=================================================

Public Interfaces:
Console:  http://72.61.114.167
API:      http://72.61.114.167:4000
AI UI:    http://72.61.114.167:3001

Databases:
Neo4j:    http://72.61.114.167:7474
Qdrant:   http://72.61.114.167:6333

Monitoring:
Grafana:  http://72.61.114.167:3000
Portainer:http://72.61.114.167:9000

STATUS: GLOBAL AI NODE LIVE
=================================================
EOF
}

main() {
  require_root
  setup_tmux_session
  setup_aliases
  install_benchmark_script
  run_benchmark
  install_snapshot_script
  create_snapshot
  install_boot_script
  update_rc_local
  run_summary_check
  write_deploy_log
  print_final_message
}

main "$@"
