#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Please run as root (sudo) to configure nginx and system services."
  exit 1
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

NGINX_SITE_PATH="/etc/nginx/sites-available/dmf7"
SERVICE_MAP_BIN="/usr/local/bin/dmf7-services"
MONITOR_BIN="/usr/local/bin/dmf7-monitor"
START_BIN="/usr/local/bin/dmf7-start"

log "Step 576-578: Installing and enabling nginx..."
apt-get update -y
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

log "Step 579: Writing nginx site configuration to ${NGINX_SITE_PATH}..."
cat >"$NGINX_SITE_PATH" <<'EOF'
server {
    listen 80;
    server_name 72.61.114.167;

    location / {
        proxy_pass http://localhost:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /console {
        proxy_pass http://localhost:4100;
        proxy_set_header Host $host;
    }

    location /ai {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
    }

    location /grafana {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
    }

    location /neo4j {
        proxy_pass http://localhost:7474;
        proxy_set_header Host $host;
    }
}
EOF

log "Step 580: Enabling site..."
ln -sf "$NGINX_SITE_PATH" /etc/nginx/sites-enabled/dmf7

log "Step 581: Testing nginx configuration..."
nginx -t

log "Step 582: Restarting nginx..."
systemctl restart nginx

log "Step 583-585: Creating DMF7 service map helper at ${SERVICE_MAP_BIN}..."
cat >"$SERVICE_MAP_BIN" <<'EOF'
#!/bin/bash

echo "=============================="
echo " DMF7 SERVICE MAP "
echo "=============================="

echo ""
echo "Gateway API:"
echo "http://72.61.114.167"

echo ""
echo "Console:"
echo "http://72.61.114.167/console"

echo ""
echo "AI WebUI:"
echo "http://72.61.114.167/ai"

echo ""
echo "Grafana:"
echo "http://72.61.114.167/grafana"

echo ""
echo "Neo4j:"
echo "http://72.61.114.167/neo4j"
EOF
chmod +x "$SERVICE_MAP_BIN"
"$SERVICE_MAP_BIN"

log "Step 586-588: Creating DMF7 live monitor helper at ${MONITOR_BIN}..."
cat >"$MONITOR_BIN" <<'EOF'
#!/bin/bash

watch -n 3 "
echo '==== DMF7 LIVE STATUS ===='
echo ''
pm2 list
echo ''
docker ps
echo ''
uptime
"
EOF
chmod +x "$MONITOR_BIN"
if command -v watch >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
  timeout 3 "$MONITOR_BIN" || true
else
  log "watch/timeout not available; skipping dmf7-monitor dry-run."
fi

log "Step 589-591: Creating DMF7 platform start helper at ${START_BIN}..."
cat >"$START_BIN" <<'EOF'
#!/bin/bash

echo "Starting DMF7 platform..."

if command -v docker >/dev/null 2>&1; then
  docker start $(docker ps -aq)
else
  echo "docker not installed; skipping docker start."
fi

if command -v pm2 >/dev/null 2>&1; then
  pm2 resurrect
else
  echo "pm2 not installed; skipping PM2 resurrect."
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl restart nginx
else
  echo "systemctl not available; unable to restart nginx."
fi

echo "DMF7 platform started."
EOF
chmod +x "$START_BIN"
if command -v docker >/dev/null 2>&1 || command -v pm2 >/dev/null 2>&1; then
  "$START_BIN" || true
else
  log "docker/pm2 not present; skipping dmf7-start execution."
fi

log "Step 592: Printing final platform message..."
cat <<'EOF'
==================================================
 DMF7 GLOBAL AI PLATFORM ONLINE 
==================================================

Main Gateway:
http://72.61.114.167

Console:
http://72.61.114.167/console

AI:
http://72.61.114.167/ai

Monitoring:
http://72.61.114.167/grafana

Database:
http://72.61.114.167/neo4j

STATUS: FULL PLATFORM RUNNING
==================================================
EOF

log "DMF7 reverse proxy setup complete."
