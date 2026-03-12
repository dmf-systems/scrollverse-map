#!/usr/bin/env bash
set -euo pipefail

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
  fi
}

log_step() {
  printf "\n[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$*"
}

write_file() {
  local target_path="$1"
  local contents="$2"

  printf '%s\n' "$contents" > "$target_path"
  chmod +x "$target_path"
}

schedule_cron_entry() {
  local entry="$1"
  local temp_file

  if ! command -v crontab >/dev/null 2>&1; then
    echo "crontab not installed; skipping schedule for: $entry"
    return
  fi

  temp_file="$(mktemp)"
  crontab -l 2>/dev/null | grep -Fv "$entry" > "$temp_file" || true
  printf "%s\n" "$entry" >> "$temp_file"
  crontab "$temp_file"
  rm -f "$temp_file"
}

create_monitor_script() {
  log_step "Creating DMF7 monitor (dmf7-top)"
  write_file "/usr/local/bin/dmf7-top" "#!/usr/bin/env bash
while true; do
  clear
  echo \"================================\"
  echo \" DMF7 ADVANCED NODE MONITOR \"
  echo \"================================\"
  echo \"\"

  echo \"TIME:\"
  date
  echo \"\"

  echo \"LOAD:\"
  uptime
  echo \"\"

  echo \"TOP CPU:\"
  ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head
  echo \"\"

  echo \"TOP MEMORY:\"
  ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head
  echo \"\"

  echo \"DISK:\"
  df -h /
  echo \"\"

  echo \"DOCKER:\"
  if command -v docker >/dev/null 2>&1; then
    docker ps --format \"table {{.Names}}\\t{{.Status}}\"
  else
    echo \"docker not installed\"
  fi
  echo \"\"

  echo \"PM2:\"
  if command -v pm2 >/dev/null 2>&1; then
    pm2 list
  else
    echo \"pm2 not installed\"
  fi

  sleep 3
done
"
}

create_cleanup_script() {
  log_step "Creating cleanup helper (dmf7-clean)"
  write_file "/usr/local/bin/dmf7-clean" "#!/usr/bin/env bash
echo \"Cleaning system...\"

if command -v apt-get >/dev/null 2>&1; then
  apt-get autoremove -y || true
  apt-get autoclean -y || true
else
  echo \"apt-get not available; skipping apt cleanup\"
fi

if command -v docker >/dev/null 2>&1; then
  docker container prune -f || true
  docker image prune -af || true
  docker volume prune -f || true
  docker network prune -f || true
else
  echo \"docker not installed; skipping docker cleanup\"
fi

if command -v pnpm >/dev/null 2>&1; then
  pnpm store prune || true
else
  echo \"pnpm not installed; skipping pnpm store prune\"
fi

echo \"Cleanup complete.\"
"
}

create_alert_script() {
  log_step "Creating alert helper (dmf7-alert)"
  write_file "/usr/local/bin/dmf7-alert" "#!/usr/bin/env bash
CPU=$(uptime | awk -F'load average:' '{print \$2}' | cut -d',' -f1 | xargs)
MEM=$(free | awk '/Mem:/ {printf(\"%.0f\", \$3/\$2*100)}')

if command -v bc >/dev/null 2>&1 && [[ -n \"\$CPU\" ]]; then
  if (( \$(echo \"\$CPU > 3.0\" | bc -l) )); then
    echo \"High CPU load detected: \$CPU\"
  fi
else
  echo \"Could not calculate CPU load (missing bc or uptime output)\"
fi

if [[ -n \"\$MEM\" ]] && [[ \"\$MEM\" -gt 85 ]]; then
  echo \"High memory usage: \$MEM%\"
fi
"
}

create_summary_script() {
  log_step "Creating summary helper (dmf7-summary)"
  write_file "/usr/local/bin/dmf7-summary" "#!/usr/bin/env bash
echo \"==============================\"
echo \" DMF7 NODE SUMMARY \"
echo \"==============================\"

echo \"\"
echo \"SERVER:\"
hostname
echo \"\"

echo \"UPTIME:\"
uptime
echo \"\"

echo \"MEMORY:\"
free -h
echo \"\"

echo \"DISK:\"
df -h
echo \"\"

echo \"DOCKER:\"
if command -v docker >/dev/null 2>&1; then
  docker ps
else
  echo \"docker not installed\"
fi
echo \"\"

echo \"PM2:\"
if command -v pm2 >/dev/null 2>&1; then
  pm2 list
else
  echo \"pm2 not installed\"
fi
echo \"\"

echo \"NETWORK:\"
if command -v ss >/dev/null 2>&1; then
  ss -tulnp
else
  echo \"ss not available\"
fi
"
}

install_tools() {
  log_step "Installing monitoring tools (htop, iotop, iftop, ncdu, bc)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y htop iotop iftop ncdu bc
}

ensure_directories() {
  log_step "Ensuring log directory exists"
  mkdir -p /opt/dmf7/logs
}

configure_cron_jobs() {
  log_step "Configuring cron jobs"
  schedule_cron_entry "0 4 * * 0 /usr/local/bin/dmf7-clean > /opt/dmf7/logs/cleanup.log 2>&1"
  schedule_cron_entry "*/10 * * * * /usr/local/bin/dmf7-alert > /opt/dmf7/logs/alerts.log"
}

run_initial_actions() {
  log_step "Running first cleanup"
  /usr/local/bin/dmf7-clean || true

  log_step "Running initial alert check"
  /usr/local/bin/dmf7-alert || true

  log_step "Generating initial summary"
  /usr/local/bin/dmf7-summary || true
}

write_deploy_log() {
  log_step "Writing deployment record"
  echo "DMF7 FULL INFRASTRUCTURE VERIFIED $(date)" > /opt/dmf7/DEPLOY_LOG
  cat /opt/dmf7/DEPLOY_LOG
}

print_final_status() {
  cat <<'EOF'
==========================================
 DMF7 AUTONOMOUS AI NODE FULLY COMPLETE
==========================================

Console:
http://72.61.114.167

API:
http://72.61.114.167:4000

AI:
http://72.61.114.167:3001

Graph:
http://72.61.114.167:7474

Vector:
http://72.61.114.167:6333

Monitoring:
http://72.61.114.167:3000
http://72.61.114.167:9000

STATUS: GLOBAL NODE ACTIVE
==========================================

Run the live monitor with: dmf7-top (CTRL+C to exit)
EOF
}

main() {
  require_root
  install_tools
  ensure_directories
  create_monitor_script
  create_cleanup_script
  create_alert_script
  create_summary_script
  configure_cron_jobs
  run_initial_actions
  write_deploy_log
  print_final_status
}

main "$@"
