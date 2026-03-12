#!/usr/bin/env bash
set -euo pipefail

# Automates DMF7 steps 798-812: maintenance mode helpers, upgrade helper, health score, changelog, and version command.

verify=0
if [[ ${1-} == "--verify" ]]; then
  verify=1
fi

log() {
  echo "==> $*"
}

write_file() {
  local path="$1"
  sudo mkdir -p "$(dirname "$path")"
  sudo tee "$path" >/dev/null
}

log "Preparing directories..."
sudo mkdir -p /usr/local/bin
sudo mkdir -p /opt/dmf7

log "Installing dmf7-maintenance..."
write_file /usr/local/bin/dmf7-maintenance <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 MAINTENANCE MODE "
echo "================================="

echo "Stopping public services..."

pm2 stop dmf7-gateway
pm2 stop dmf7-console

systemctl stop nginx

echo "Maintenance mode enabled."
EOF
sudo chmod +x /usr/local/bin/dmf7-maintenance

log "Installing dmf7-maintenance-exit..."
write_file /usr/local/bin/dmf7-maintenance-exit <<'EOF'
#!/bin/bash

echo "================================="
echo " EXIT MAINTENANCE MODE "
echo "================================="

pm2 start dmf7-gateway
pm2 start dmf7-console

systemctl start nginx

echo "Platform restored."
EOF
sudo chmod +x /usr/local/bin/dmf7-maintenance-exit

log "Installing dmf7-upgrade..."
write_file /usr/local/bin/dmf7-upgrade <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 NODE UPGRADE "
echo "================================="

cd ~/DMF7

git pull

pnpm install
pnpm build

pm2 restart all

echo "Upgrade complete."
EOF
sudo chmod +x /usr/local/bin/dmf7-upgrade

log "Installing dmf7-health-score..."
write_file /usr/local/bin/dmf7-health-score <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 NODE HEALTH SCORE "
echo "================================="

SCORE=0

curl -s http://localhost:4000 > /dev/null && SCORE=$((SCORE+20))
curl -s http://localhost:4100 > /dev/null && SCORE=$((SCORE+20))

docker ps | grep qdrant > /dev/null && SCORE=$((SCORE+20))
docker ps | grep neo4j > /dev/null && SCORE=$((SCORE+20))

ollama list > /dev/null && SCORE=$((SCORE+20))

echo "Node Health: $SCORE / 100"
EOF
sudo chmod +x /usr/local/bin/dmf7-health-score

if [[ $verify -eq 1 ]]; then
  log "Running dmf7-health-score for verification..."
  /usr/local/bin/dmf7-health-score || true
fi

log "Writing CHANGELOG..."
write_file /opt/dmf7/CHANGELOG.txt <<'EOF'
DMF7 NEXTGEN PLATFORM CHANGELOG

Version 1.0
- Autonomous AI node deployed
- Redis worker system operational
- AI runtime integrated
- Vector + Graph DB online
- Monitoring stack active
- Orchestrator + watchdog active
- Cluster-ready infrastructure
EOF

if [[ ! -s /opt/dmf7/VERSION ]]; then
  log "Initializing VERSION file..."
  echo "1.0" | sudo tee /opt/dmf7/VERSION >/dev/null
fi

log "Installing dmf7-version..."
write_file /usr/local/bin/dmf7-version <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 PLATFORM VERSION "
echo "================================="

cat /opt/dmf7/VERSION

echo ""
cat /opt/dmf7/CHANGELOG.txt
EOF
sudo chmod +x /usr/local/bin/dmf7-version

if [[ $verify -eq 1 ]]; then
  log "Running dmf7-version for verification..."
  /usr/local/bin/dmf7-version || true
fi

log "Displaying final platform status banner..."
cat <<'EOF'
======================================================
 DMF7 NEXTGEN AI INFRASTRUCTURE 
======================================================

Node:
72.61.114.167

Control Commands:
dmf7-control
dmf7-admin
dmf7-help

Monitoring:
dmf7-dashboard
dmf7-live

Maintenance:
dmf7-maintenance
dmf7-maintenance-exit

STATUS: GLOBAL AI NODE STABLE
======================================================
EOF

log "DMF7 maintenance and upgrade tools installed."
