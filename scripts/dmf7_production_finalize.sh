#!/bin/bash
set -euo pipefail

# Automates DMF7 production steps 81-97:
# - GitHub CLI install and auth validation
# - Repo branch preparation
# - Git sync helper + cron
# - Health checks and monitoring verification
# - Final backup + announcement banner

DMF7_DIR="${DMF7_DIR:-/root/DMF7}"
GIT_SYNC_SCRIPT="/usr/local/bin/dmf7-git-sync"
HEALTH_SCRIPT="/usr/local/bin/dmf7-health"
LOG_DIR="/opt/dmf7/logs"
CRON_SPEC="*/10 * * * * ${GIT_SYNC_SCRIPT} > ${LOG_DIR}/git-sync.log 2>&1"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root because it writes to /usr/local/bin and configures cron."
    exit 1
  fi
}

run_cmd() {
  local desc="$1"
  shift
  echo ">>> ${desc}"
  "$@"
}

ensure_directories() {
  mkdir -p "${LOG_DIR}"
}

ensure_gh_cli() {
  run_cmd "Updating apt indexes" apt-get update -y
  run_cmd "Installing GitHub CLI" apt-get install -y gh
  run_cmd "GitHub CLI version" gh --version

  if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated."
    echo "Run: gh auth login --hostname github.com --web --git-protocol https"
    echo "Then rerun this script."
    exit 1
  fi
}

verify_repo_access() {
  if [[ ! -d "${DMF7_DIR}/.git" ]]; then
    echo "DMF7 repository not found at ${DMF7_DIR}"
    exit 1
  fi

  pushd "${DMF7_DIR}" >/dev/null
  run_cmd "Viewing repository with gh" gh repo view

  if git rev-parse --verify production-node >/dev/null 2>&1; then
    run_cmd "Switching to existing production-node branch" git checkout production-node
  else
    run_cmd "Creating production-node branch" git checkout -b production-node
  fi

  run_cmd "Pushing production-node branch" git push -u origin production-node
  popd >/dev/null
}

write_git_sync_script() {
  cat > "${GIT_SYNC_SCRIPT}" <<'EOF'
#!/bin/bash
set -euo pipefail

DMF7_DIR="${DMF7_DIR:-/root/DMF7}"

cd "${DMF7_DIR}"

git fetch origin
git reset --hard origin/main

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
  # shellcheck source=/dev/null
  source "${NVM_DIR}/nvm.sh"
fi

nvm use 20

pnpm install
pnpm build

pm2 restart all

echo "DMF7 synced with GitHub"
EOF

  chmod +x "${GIT_SYNC_SCRIPT}"
}

ensure_cron_job() {
  local current_cron
  current_cron="$(crontab -l 2>/dev/null || true)"

  if ! grep -F "${GIT_SYNC_SCRIPT}" <<<"${current_cron}" >/dev/null; then
    printf "%s\n%s\n" "${current_cron}" "${CRON_SPEC}" | crontab -
    echo "Cron entry added: ${CRON_SPEC}"
  else
    echo "Cron entry already present for ${GIT_SYNC_SCRIPT}"
  fi

  echo "Current crontab:"
  crontab -l
}

write_health_script() {
  cat > "${HEALTH_SCRIPT}" <<'EOF'
#!/bin/bash
set -euo pipefail

echo "Checking DMF7 services..."

curl -s http://localhost:4000
curl -s http://localhost:4100
curl -s http://localhost:6333
curl -s http://localhost:11435

echo ""
echo "Health check complete"
EOF

  chmod +x "${HEALTH_SCRIPT}"
}

run_health_and_monitoring() {
  run_cmd "Running dmf7-health" "${HEALTH_SCRIPT}"
  run_cmd "Netdata build info" docker exec netdata netdata -W buildinfo
  run_cmd "Netdata dashboard check" curl http://localhost:19999
  run_cmd "Docker resource monitor check" curl http://localhost:8080
}

run_backup_and_status() {
  run_cmd "Running dmf7-backup" dmf7-backup
  run_cmd "Listing backups" ls -lh /opt/dmf7/backups
  run_cmd "Listing snapshots" ls -lh /opt/dmf7/snapshots
  run_cmd "Running dmf7-status" dmf7-status
}

final_announcement() {
  cat <<'EOF'
================================================
 DMF7 AUTONOMOUS AI INFRASTRUCTURE ONLINE
================================================

Primary Console:
http://72.61.114.167

API:
http://72.61.114.167/api

AI Interface:
http://72.61.114.167:3001

Monitoring:
Grafana   : http://72.61.114.167:3000
Netdata   : http://72.61.114.167:19999
Portainer : http://72.61.114.167:9000

Graph DB:
Neo4j : http://72.61.114.167:7474

Vector DB:
Qdrant : http://72.61.114.167:6333
================================================
EOF
}

main() {
  require_root
  ensure_directories
  ensure_gh_cli
  verify_repo_access
  write_git_sync_script
  ensure_cron_job
  write_health_script
  run_health_and_monitoring
  run_backup_and_status
  final_announcement
}

main "$@"
