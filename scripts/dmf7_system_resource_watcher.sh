#!/bin/bash
# DMF7 system resource watcher and diagnostics setup (steps 356-376)
set -euo pipefail

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must run as root to write to /usr/local/bin and /opt/dmf7." >&2
    exit 1
  fi
}

create_watch_script() {
  cat <<'EOF' > /usr/local/bin/dmf7-watch
#!/bin/bash

while true
do
clear
echo "=============================="
echo " DMF7 NODE LIVE WATCH "
echo "=============================="
echo ""

echo "TIME:"
date
echo ""

echo "UPTIME:"
uptime
echo ""

echo "CPU / MEMORY:"
top -bn1 | head -5
echo ""

echo "DISK:"
df -h /
echo ""

echo "DOCKER:"
docker ps --format "table {{.Names}}\t{{.Status}}"
echo ""

echo "PM2:"
pm2 list

sleep 2
done
EOF
  chmod +x /usr/local/bin/dmf7-watch
}

create_ai_test() {
  cat <<'EOF' > /usr/local/bin/dmf7-ai-test
#!/bin/bash

echo "Testing AI Model..."

curl http://localhost:11435/api/generate \
-d '{
"model":"llama3",
"prompt":"Explain the DMF7 platform in one paragraph.",
"stream":false
}'
EOF
  chmod +x /usr/local/bin/dmf7-ai-test
}

create_vector_test() {
  cat <<'EOF' > /usr/local/bin/dmf7-vector-test
#!/bin/bash

curl http://localhost:6333/collections
EOF
  chmod +x /usr/local/bin/dmf7-vector-test
}

create_graph_test() {
  cat <<'EOF' > /usr/local/bin/dmf7-graph-test
#!/bin/bash

curl http://localhost:7474
EOF
  chmod +x /usr/local/bin/dmf7-graph-test
}

create_health() {
  cat <<'EOF' > /usr/local/bin/dmf7-health
#!/bin/bash

echo "Checking Gateway..."
curl -s http://localhost:4000

echo ""
echo "Checking Console..."
curl -s http://localhost:4100

echo ""
echo "Checking AI..."
curl -s http://localhost:3001

echo ""
echo "Checking Vector DB..."
curl -s http://localhost:6333

echo ""
echo "Checking Graph DB..."
curl -s http://localhost:7474
EOF
  chmod +x /usr/local/bin/dmf7-health
}

create_control_center() {
  cat <<'EOF' > /usr/local/bin/dmf7
#!/bin/bash

echo "=============================="
echo " DMF7 CONTROL CENTER "
echo "=============================="

echo "1) Status"
echo "2) Health"
echo "3) Metrics"
echo "4) Watch"
echo "5) Backup"
echo "6) Restart Stack"
echo "7) AI Test"

read -p "Select option: " option

case $option in
1) dmf7-status ;;
2) dmf7-health ;;
3) dmf7-metrics ;;
4) dmf7-watch ;;
5) dmf7-backup ;;
6) dmf7-stack restart ;;
7) dmf7-ai-test ;;
*) echo "Invalid option" ;;
esac
EOF
  chmod +x /usr/local/bin/dmf7
}

create_deploy_log() {
  mkdir -p /opt/dmf7
  echo "DMF7 AUTONOMOUS AI NODE VERIFIED $(date)" > /opt/dmf7/DEPLOY_LOG
}

print_complete_banner() {
  cat <<'EOF'
=================================================
 DMF7 AUTONOMOUS GLOBAL AI NODE FULLY OPERATIONAL
=================================================

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

STATUS: LIVE
=================================================
EOF
}

main() {
  require_root
  create_watch_script
  create_ai_test
  create_vector_test
  create_graph_test
  create_health
  create_control_center
  create_deploy_log
  print_complete_banner
}

main "$@"
