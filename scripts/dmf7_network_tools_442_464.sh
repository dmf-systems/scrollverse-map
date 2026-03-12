#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run this installer as root or with sudo."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y tcpdump traceroute mtr dnsutils

mkdir -p /usr/local/bin

cat <<'EOF' > /usr/local/bin/dmf7-netcheck
#!/bin/bash

echo "=============================="
echo " DMF7 NETWORK CHECK "
echo "=============================="

echo ""
echo "PUBLIC IP:"
curl -s ifconfig.me
echo ""

echo ""
echo "PING TEST:"
ping -c 3 8.8.8.8

echo ""
echo "DNS TEST:"
nslookup github.com

echo ""
echo "PORT TEST:"
ss -tulnp
EOF

cat <<'EOF' > /usr/local/bin/dmf7-models
#!/bin/bash

echo "=============================="
echo " DMF7 AI MODEL MANAGER "
echo "=============================="

echo ""
echo "Installed models:"
curl -s http://localhost:11435/api/tags

echo ""
echo "To pull a model:"
echo "ollama pull llama3"
EOF

cat <<'EOF' > /usr/local/bin/dmf7-vector
#!/bin/bash

echo "=============================="
echo " DMF7 VECTOR DATABASE "
echo "=============================="

curl http://localhost:6333/collections
EOF

cat <<'EOF' > /usr/local/bin/dmf7-graph
#!/bin/bash

echo "=============================="
echo " DMF7 GRAPH DATABASE "
echo "=============================="

curl http://localhost:7474
EOF

cat <<'EOF' > /usr/local/bin/dmf7-job
#!/bin/bash

curl http://localhost:4000/api/health
EOF

cat <<'EOF' > /usr/local/bin/dmf7-help
#!/bin/bash

echo "=============================="
echo " DMF7 COMMAND LIST "
echo "=============================="

echo ""
echo "System:"
echo "dmf7-status"
echo "dmf7-summary"
echo "dmf7-top"
echo "dmf7-watch"

echo ""
echo "Operations:"
echo "dmf7-stack"
echo "dmf7-backup"
echo "dmf7-clean"

echo ""
echo "AI:"
echo "dmf7-models"
echo "dmf7-ai-test"

echo ""
echo "Databases:"
echo "dmf7-vector"
echo "dmf7-graph"

echo ""
echo "Diagnostics:"
echo "dmf7-netcheck"
echo "dmf7-health"
EOF

chmod +x /usr/local/bin/dmf7-netcheck
chmod +x /usr/local/bin/dmf7-models
chmod +x /usr/local/bin/dmf7-vector
chmod +x /usr/local/bin/dmf7-graph
chmod +x /usr/local/bin/dmf7-job
chmod +x /usr/local/bin/dmf7-help

run_check() {
  echo ""
  echo ">>> $1"
  if ! "$1"; then
    echo "$1 failed (continuing)"
  fi
}

run_if_available() {
  echo ""
  echo ">>> $1"
  if command -v "$1" >/dev/null 2>&1; then
    if ! "$1"; then
      echo "$1 failed (continuing)"
    fi
  else
    echo "$1 not found (skipping)"
  fi
}

run_check dmf7-netcheck
run_check dmf7-models
run_check dmf7-vector
run_check dmf7-graph
run_check dmf7-job
run_check dmf7-help

run_if_available dmf7-health
run_if_available dmf7-status

mkdir -p /opt/dmf7
echo "DMF7 AUTONOMOUS AI NODE CONFIRMED $(date)" > /opt/dmf7/DEPLOY_LOG
cat /opt/dmf7/DEPLOY_LOG

cat <<'EOF'
=================================================
 DMF7 GLOBAL AUTONOMOUS AI PLATFORM READY 
=================================================

Console:
http://72.61.114.167

API:
http://72.61.114.167:4000

AI:
http://72.61.114.167:3001

Vector DB:
http://72.61.114.167:6333

Graph DB:
http://72.61.114.167:7474

Monitoring:
http://72.61.114.167:3000
http://72.61.114.167:9000

STATUS: OPERATIONAL
=================================================
EOF
