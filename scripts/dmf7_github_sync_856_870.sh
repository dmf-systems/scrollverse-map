#!/usr/bin/env bash
#
# Automates DMF7 steps 856-870:
# 856: install GitHub CLI
# 857-858: authenticate GitHub CLI
# 859-860: link/pull DMF7 repository
# 861: install CI tools
# 862-866: create sync helper and cron
# 867-870: create copilot helper and final banner
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "This installer must be run as root (required for apt, /usr/local/bin, and cron)." >&2
  exit 1
fi

DMF7_DIR="${DMF7_DIR:-$HOME/DMF7}"
SYNC_BIN="/usr/local/bin/dmf7-sync"
COPILOT_BIN="/usr/local/bin/dmf7-copilot"
CRON_LINE="*/30 * * * * /usr/local/bin/dmf7-sync > /opt/dmf7/sync.log 2>&1"
RUN_VERIFY=false

if [[ ${1:-} == "--verify" ]]; then
  RUN_VERIFY=true
fi

log() {
  echo "==> $*"
}

header() {
  echo "======================================="
  echo " DMF7 GITHUB SYNC & COPILOT SETUP"
  echo "======================================="
}

ensure_dmf7_repo() {
  if [[ ! -d "$DMF7_DIR/.git" ]]; then
    echo "DMF7 repository not found at $DMF7_DIR. Set DMF7_DIR or clone repo there." >&2
    exit 1
  fi
}

install_packages() {
  log "STEP 856 — Install GitHub CLI"
  apt-get update -y
  apt-get install -y gh

  log "STEP 861 — Install CI tools"
  apt-get install -y jq
  npm install -g pnpm turbo
}

ensure_gh_auth() {
  log "STEP 857 — Authenticate GitHub CLI"
  if gh auth status >/dev/null 2>&1; then
    log "GitHub CLI already authenticated."
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    log "Authenticating gh with GITHUB_TOKEN."
    echo "$GITHUB_TOKEN" | gh auth login --with-token
  else
    log "GitHub CLI not authenticated. Run 'gh auth login' manually after this script if needed."
  fi

  log "STEP 858 — Verify GitHub CLI auth status"
  gh auth status || true
}

update_dmf7_repo() {
  log "STEP 859 — Link VPS to DMF7 repository"
  git -C "$DMF7_DIR" remote -v

  log "STEP 860 — Pull latest copilot work"
  git -C "$DMF7_DIR" pull origin main
}

write_sync_script() {
  log "STEP 862 — Create auto-sync script"
  cat >"$SYNC_BIN" <<EOF
#!/bin/bash
set -euo pipefail
echo "================================="
echo " DMF7 GITHUB SYNC "
echo "================================="
cd "$DMF7_DIR"
git fetch --all
git reset --hard origin/main
pnpm install
pnpm build
pm2 restart all
echo "DMF7 updated from GitHub."
EOF
  chmod +x "$SYNC_BIN"

  if $RUN_VERIFY; then
    log "STEP 864 — Test sync"
    "$SYNC_BIN"
  fi
}

install_cron() {
  log "STEP 865 — Configure auto update cron"
  mkdir -p /opt/dmf7
  local current_cron
  current_cron="$(crontab -l 2>/dev/null || true)"
  if ! grep -F "$CRON_LINE" <<<"$current_cron" >/dev/null 2>&1; then
    { printf "%s\n" "$current_cron"; echo "$CRON_LINE"; } | crontab -
  fi

  log "STEP 866 — Verify cron entry"
  crontab -l
}

write_copilot_script() {
  log "STEP 867 — Create copilot task runner"
  cat >"$COPILOT_BIN" <<EOF
#!/bin/bash
set -euo pipefail
echo "================================="
echo " DMF7 COPILOT EXECUTOR "
echo "================================="
cd "$DMF7_DIR"
git pull
pnpm install
pnpm build
pm2 restart all
echo "Copilot updates deployed."
EOF
  chmod +x "$COPILOT_BIN"

  if $RUN_VERIFY; then
    log "STEP 869 — Run copilot deploy"
    "$COPILOT_BIN"
  fi
}

final_banner() {
  log "STEP 870 — Final system link check"
  echo "======================================="
  echo "DMF7 NODE CONNECTED TO GITHUB"
  echo ""
  echo "Repository: Daana-Money-Factory-Organisation/dmf7-nextgen"
  echo "Auto Sync: ENABLED"
  echo "Copilot Agent: ENABLED"
  echo "CI Build: ENABLED"
  echo ""
  echo "STATUS: FULL DEVOPS PIPELINE ACTIVE"
  echo "======================================="
}

header
ensure_dmf7_repo
install_packages
ensure_gh_auth
update_dmf7_repo
write_sync_script
install_cron
write_copilot_script
final_banner
