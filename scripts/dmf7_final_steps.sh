#!/usr/bin/env bash
set -euo pipefail

RUN_VALIDATION=false
GRAFANA_CONTAINER=${GRAFANA_CONTAINER:-dmf7-grafana}
MONITOR_LOG=${MONITOR_LOG:-/opt/dmf7/logs/system-monitor.log}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify)
      RUN_VALIDATION=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--verify]" >&2
      exit 1
      ;;
  esac
done

echo "STEP 98 — install Grafana pie chart panel"
docker exec "$GRAFANA_CONTAINER" grafana-cli plugins install grafana-piechart-panel
docker restart "$GRAFANA_CONTAINER"

echo "STEP 99 — verify Grafana at http://localhost:3000"
curl http://localhost:3000

echo "STEP 100 — install dmf7-logs helper"
cat <<'EOF' | tee /usr/local/bin/dmf7-logs >/dev/null
#!/bin/bash

echo "==== PM2 LOGS ===="
pm2 logs --lines 30

echo ""
echo "==== DOCKER LOGS ===="
docker logs redis-ai --tail 20
docker logs qdrant --tail 20
docker logs neo4j --tail 20
docker logs ollama --tail 20
EOF
chmod +x /usr/local/bin/dmf7-logs

echo "STEP 102 — install bc and system monitor"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y bc
cat <<'EOF' | tee /usr/local/bin/dmf7-monitor >/dev/null
#!/bin/bash

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
MEM=$(free | awk '/Mem/{printf("%.2f"), $3/$2 * 100.0}')

if (( $(echo "$CPU > 90" | bc -l) )); then
  echo "WARNING: CPU HIGH"
fi

if (( $(echo "$MEM > 90" | bc -l) )); then
  echo "WARNING: MEMORY HIGH"
fi
EOF
chmod +x /usr/local/bin/dmf7-monitor

echo "STEP 103 — schedule system monitor cron"
mkdir -p "$(dirname "$MONITOR_LOG")"
CRON_LINE="*/5 * * * * /usr/local/bin/dmf7-monitor > $MONITOR_LOG 2>&1"
EXISTING_CRON=$(crontab -l 2>/dev/null || true)
if ! echo "$EXISTING_CRON" | grep -F "$CRON_LINE" >/dev/null; then
  (echo "$EXISTING_CRON"; echo "$CRON_LINE") | crontab -
fi

echo "STEP 104 — create dmf7-check"
cat <<'EOF' | tee /usr/local/bin/dmf7-check >/dev/null
#!/bin/bash

echo "Checking Redis..."
docker exec redis-ai redis-cli ping

echo "Checking Vector DB..."
curl -s http://localhost:6333

echo "Checking Graph DB..."
curl -s http://localhost:7474

echo "Checking AI Engine..."
curl -s http://localhost:11435/api/tags

echo "Checking API..."
curl -s http://localhost:4000

echo "Checking Console..."
curl -s http://localhost:4100
EOF
chmod +x /usr/local/bin/dmf7-check

echo "STEP 106 — create dmf7-stop"
cat <<'EOF' | tee /usr/local/bin/dmf7-stop >/dev/null
#!/bin/bash

echo "Stopping DMF7..."

pm2 stop all

docker stop redis-ai
docker stop qdrant
docker stop neo4j
docker stop ollama
docker stop grafana
docker stop portainer

systemctl stop nginx

echo "DMF7 stopped"
EOF
chmod +x /usr/local/bin/dmf7-stop

echo "STEP 107 — create dmf7-start"
cat <<'EOF' | tee /usr/local/bin/dmf7-start >/dev/null
#!/bin/bash

echo "Starting DMF7..."

docker start redis-ai
docker start qdrant
docker start neo4j
docker start ollama
docker start grafana
docker start portainer

pm2 restart all

systemctl start nginx

echo "DMF7 started"
EOF
chmod +x /usr/local/bin/dmf7-start

if $RUN_VALIDATION; then
  echo "STEP 101 — run dmf7-logs"
  /usr/local/bin/dmf7-logs || true

  echo "STEP 105 — run dmf7-check"
  /usr/local/bin/dmf7-check || true

  echo "STEP 108 — test emergency control"
  /usr/local/bin/dmf7-stop
  sleep 5
  /usr/local/bin/dmf7-start

  echo "STEP 109 — final server performance check"
  uptime
  free -h
  df -h
fi

echo "STEP 110 — final DMF7 platform status"
cat <<'EOF'
==================================================
 DMF7 FULL STACK AI PLATFORM RUNNING
==================================================

Server IP: 72.61.114.167

Gateway API:      http://72.61.114.167:4000
Operator Console: http://72.61.114.167:4100
AI Interface:     http://72.61.114.167:3001

Monitoring:
Grafana  : http://72.61.114.167:3000
Netdata  : http://72.61.114.167:19999

Infrastructure:
Neo4j    : http://72.61.114.167:7474
Qdrant   : http://72.61.114.167:6333
Portainer: http://72.61.114.167:9000

Management:
dmf7 status
dmf7 restart
dmf7 backup
dmf7 update
dmf7 logs
==================================================
EOF

if ! $RUN_VALIDATION; then
  echo "Run with --verify to execute log, health, and emergency control checks."
fi
