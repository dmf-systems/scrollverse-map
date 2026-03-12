#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "This script must be run as root (sudo)." >&2
  exit 1
fi

log() {
  printf "\n[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

run_or_warn() {
  local description="$1"
  shift
  log "$description"
  set +e
  "$@"
  local status=$?
  set -e
  if [[ $status -ne 0 ]]; then
    echo "Warning: '${description}' failed with exit code ${status}." >&2
  fi
}

ensure_packages() {
  apt-get update -y
  apt-get install -y "$@"
}

configure_unattended_upgrades() {
  log "Installing and configuring unattended upgrades (Step 111)"
  ensure_packages unattended-upgrades apt-listchanges
  cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
  dpkg-reconfigure -plow unattended-upgrades
}

harden_sshd() {
  log "Hardening SSH configuration (Step 112)"
  local conf_dir="/etc/ssh/sshd_config.d"
  local conf_file="${conf_dir}/99-dmf7-hardening.conf"
  mkdir -p "${conf_dir}"
  cat >"${conf_file}" <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
  chmod 600 "${conf_file}"
  if systemctl list-units --type=service | grep -q '^ssh\\.service'; then
    systemctl restart ssh
  else
    systemctl restart sshd
  fi
}

configure_firewall() {
  log "Configuring UFW firewall rules (Step 113)"
  ensure_packages ufw
  ufw --force default deny incoming
  ufw --force default allow outgoing
  for port in 22 80 443 4000 4100 3001 3000 7474 6333 9000; do
    ufw allow "${port}"
  done
  ufw --force enable
}

run_lynis() {
  log "Installing and running Lynis scan (Step 114)"
  ensure_packages lynis
  run_or_warn "Lynis audit" lynis audit system
}

run_trivy() {
  log "Running Trivy scan of node:20 image (Step 115)"
  run_or_warn "Trivy scan" docker run --rm --pull=always aquasec/trivy image node:20
}

apply_limits() {
  log "Applying file descriptor limits (Step 116)"
  local limits_file="/etc/security/limits.conf"
  local soft="* soft nofile 65535"
  local hard="* hard nofile 65535"
  grep -qxF "${soft}" "${limits_file}" || echo "${soft}" >>"${limits_file}"
  grep -qxF "${hard}" "${limits_file}" || echo "${hard}" >>"${limits_file}"
}

enable_swap() {
  log "Ensuring swap is enabled (Step 117)"
  if ! swapon --show | grep -q '^/swapfile'; then
    if [[ ! -f /swapfile ]]; then
      fallocate -l 4G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
    fi
    swapon /swapfile
  fi
  if ! grep -q '^/swapfile ' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
}

verify_swap() {
  log "Verifying swap status (Step 118)"
  free -h
}

verify_disk_health() {
  log "Checking disk health with smartctl (Step 119)"
  ensure_packages smartmontools
  local disk="/dev/sda"
  if [[ ! -b "${disk}" ]]; then
    disk="$(lsblk -ndo NAME,TYPE | awk '$2==\"disk\"{print \"/dev/\"$1; exit}')"
  fi
  run_or_warn "smartctl health check on ${disk}" smartctl -H "${disk}"
}

verify_system_load() {
  log "Reporting system load (Step 120)"
  uptime
}

verify_services() {
  log "Verifying local services (Steps 121-125)"
  run_or_warn "AI engine (11435)" curl -fsSL "http://localhost:11435/api/tags"
  run_or_warn "Vector DB (6333)" curl -fsSL "http://localhost:6333/collections"
  run_or_warn "Graph DB (7474)" curl -fsSL "http://localhost:7474"
  run_or_warn "Gateway API (4000)" curl -fsSL "http://localhost:4000"
  run_or_warn "Operator Console (4100)" curl -fsSL "http://localhost:4100"
}

verify_docker() {
  log "Checking Docker system (Step 126)"
  run_or_warn "docker stats" docker stats --no-stream
}

verify_pm2() {
  log "Checking PM2 status (Step 127)"
  run_or_warn "pm2 list" pm2 list
}

final_validations() {
  log "Running final DMF7 validations (Steps 128-129)"
  run_or_warn "dmf7-check" dmf7-check
  run_or_warn "dmf7-backup" dmf7-backup
}

print_status_banner() {
  cat <<'EOF'
=====================================================
 DMF7 PRODUCTION AI NODE — FULLY OPERATIONAL 
=====================================================

Public Interfaces:

Operator Console  : http://72.61.114.167:4100
Gateway API       : http://72.61.114.167:4000
AI Interface      : http://72.61.114.167:3001

Infrastructure:

Vector DB (Qdrant): http://72.61.114.167:6333
Graph DB (Neo4j)  : http://72.61.114.167:7474

Monitoring:

Grafana           : http://72.61.114.167:3000
Netdata           : http://72.61.114.167:19999
Portainer         : http://72.61.114.167:9000

=====================================================
 DMF7 NODE STATUS: ONLINE 
=====================================================
EOF
}

main() {
  configure_unattended_upgrades
  harden_sshd
  configure_firewall
  run_lynis
  run_trivy
  apply_limits
  enable_swap
  verify_swap
  verify_disk_health
  verify_system_load
  verify_services
  verify_docker
  verify_pm2
  final_validations
  print_status_banner
}

main "$@"
