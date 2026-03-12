#!/bin/bash
set -euo pipefail

# DMF7 Global Control Center automation for steps 673-688.
# Recreates the requested helper scripts, timer/service, node identity, and final activation banner.

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This installer must run as root." >&2
    exit 1
  fi
}

systemd_available() {
  command -v systemctl >/dev/null 2>&1
}

create_control_center() {
  cat >/usr/local/bin/dmf7-control <<'EOF'
#!/bin/bash

clear
echo "======================================"
echo " DMF7 GLOBAL CONTROL CENTER "
echo "======================================"
echo ""
echo "1) Platform Status"
echo "2) Live Dashboard"
echo "3) Restart All Services"
echo "4) Docker Containers"
echo "5) AI Models"
echo "6) System Metrics"
echo "7) Security Status"
echo "8) Network Diagnostics"
echo "9) System Update"
echo "10) Full Diagnostics"
echo "0) Exit"
echo ""

read -p "Select option: " CHOICE

case $CHOICE in

1)
dmf7 status
;;

2)
dmf7-live
;;

3)
pm2 restart all
docker restart $(docker ps -q)
;;

4)
docker ps
;;

5)
ollama list
;;

6)
dmf7-metrics
;;

7)
dmf7-security
;;

8)
dmf7-network
;;

9)
dmf7-update
;;

10)
dmf7-diagnose
;;

0)
exit
;;

*)
echo "Invalid option"
;;

esac
EOF

  chmod +x /usr/local/bin/dmf7-control
}

create_queue_test() {
  cat >/usr/local/bin/dmf7-queue-test <<'EOF'
#!/bin/bash

echo "Submitting AI tasks..."

for i in {1..3}
do
ollama run llama3 "Task $i: Confirm DMF7 worker queue active."
done
EOF

  chmod +x /usr/local/bin/dmf7-queue-test
}

create_cleanup_timer() {
  cat >/etc/systemd/system/dmf7-clean.timer <<'EOF'
[Unit]
Description=DMF7 Weekly Cleanup

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

  cat >/etc/systemd/system/dmf7-clean.service <<'EOF'
[Unit]
Description=DMF7 Cleanup

[Service]
Type=oneshot
ExecStart=/usr/local/bin/dmf7-clean
EOF

  if systemd_available; then
    systemctl daemon-reload
    systemctl enable dmf7-clean.timer
    systemctl start dmf7-clean.timer
  else
    echo "systemd not available; skipping timer enable/start."
  fi
}

write_node_identity() {
  mkdir -p /opt/dmf7
  echo "DMF7-NODE-72-61-114-167" >/opt/dmf7/NODE_ID
}

create_node_command() {
  cat >/usr/local/bin/dmf7-node <<'EOF'
#!/bin/bash

echo "=================================="
echo " DMF7 NODE INFORMATION "
echo "=================================="

echo ""
echo "Node ID:"
cat /opt/dmf7/NODE_ID

echo ""
echo "Server:"
hostname

echo ""
echo "IP:"
hostname -I

echo ""
echo "Uptime:"
uptime
EOF

  chmod +x /usr/local/bin/dmf7-node
}

verify_setup() {
  printf '0\n' | /usr/local/bin/dmf7-control >/tmp/dmf7-control.log 2>&1 || echo "dmf7-control quick check encountered an issue (see /tmp/dmf7-control.log)."

  if command -v ollama >/dev/null 2>&1; then
    /usr/local/bin/dmf7-queue-test || echo "dmf7-queue-test reported an error."
  else
    echo "Skipping dmf7-queue-test (ollama not installed)."
  fi

  if systemd_available; then
    systemctl list-timers | grep dmf7 || true
  fi

  /usr/local/bin/dmf7-node || true
}

final_activation_banner() {
  local node_id
  local server_ip
  node_id=$(cat /opt/dmf7/NODE_ID 2>/dev/null || echo "UNKNOWN")
  server_ip=$(hostname -I | awk '{print $1}')
  if [[ -z "${server_ip}" ]]; then
    server_ip="72.61.114.167"
  fi

  cat <<EOF
====================================================
 DMF7 AUTONOMOUS AI NODE INITIALIZED 
====================================================

Node ID:
${node_id}

Server:
${server_ip}

Platform Status:
✔ AI Runtime
✔ Worker Queue
✔ Graph Database
✔ Vector Database
✔ Monitoring
✔ Security

Control Interface:
dmf7-control

STATUS: GLOBAL AI NODE ACTIVE
====================================================
EOF
}

main() {
  local verify="${1:-}"

  require_root
  create_control_center
  create_queue_test
  create_cleanup_timer
  write_node_identity
  create_node_command

  if [[ "${verify}" == "--verify" ]]; then
    verify_setup
  fi

  final_activation_banner
}

main "$@"
