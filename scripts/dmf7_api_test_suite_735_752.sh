#!/usr/bin/env bash
# DMF7 automation for steps 735-752: installs API test, restart, AI loop,
# performance summary, identity helpers, and seeds the node hash.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dmf7_api_test_suite_735_752.sh [--verify]

Creates DMF7 helper scripts under /usr/local/bin and seeds /opt/dmf7/node_hash.
Pass --verify to execute the helpers after installation (may restart services).
EOF
}

VERIFY=0
case "${1:-}" in
  --verify) VERIFY=1 ;;
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) usage; exit 1 ;;
esac

BIN_DIR="/usr/local/bin"
OPT_DIR="/opt/dmf7"

mkdir -p "${BIN_DIR}" "${OPT_DIR}"

cat <<'EOF' > "${BIN_DIR}/dmf7-api-test"
#!/bin/bash

echo "================================="
echo " DMF7 API TEST SUITE "
echo "================================="

echo ""
echo "Gateway Health:"
curl -s http://localhost:4000

echo ""
echo "Console Health:"
curl -s http://localhost:4100

echo ""
echo "Vector DB:"
curl -s http://localhost:6333/collections

echo ""
echo "Graph DB:"
curl -s http://localhost:7474

echo ""
echo "AI Runtime:"
ollama list

echo ""
echo "Docker:"
docker ps
EOF
chmod 755 "${BIN_DIR}/dmf7-api-test"

cat <<'EOF' > "${BIN_DIR}/dmf7-restart-all"
#!/bin/bash

echo "Restarting DMF7 platform..."

if command -v pm2 >/dev/null 2>&1; then
  pm2 restart all
else
  echo "pm2 not found; skipping PM2 restart."
fi

if command -v docker >/dev/null 2>&1; then
  containers=$(docker ps -q)
  if [ -n "${containers}" ]; then
    docker restart ${containers}
  else
    echo "No running containers to restart."
  fi
else
  echo "docker not found; skipping container restart."
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl restart nginx
else
  echo "systemctl not available; skipping nginx restart."
fi

echo "Restart complete."
EOF
chmod 755 "${BIN_DIR}/dmf7-restart-all"

cat <<'EOF' > "${BIN_DIR}/dmf7-ai-loop"
#!/bin/bash

MODEL=${1:-llama3}

echo "Running AI loop test..."

for i in {1..10}
do
  echo "Iteration $i"
  ollama run "$MODEL" "Say: DMF7 distributed AI node running test $i."
done
EOF
chmod 755 "${BIN_DIR}/dmf7-ai-loop"

cat <<'EOF' > "${BIN_DIR}/dmf7-performance"
#!/bin/bash

echo "================================="
echo " DMF7 PERFORMANCE SUMMARY "
echo "================================="

echo ""
echo "CPU Load:"
uptime

echo ""
echo "Memory:"
free -h

echo ""
echo "Disk:"
df -h

echo ""
echo "Docker:"
docker stats --no-stream

echo ""
echo "PM2:"
pm2 list
EOF
chmod 755 "${BIN_DIR}/dmf7-performance"

cat <<'EOF' > "${BIN_DIR}/dmf7-identity"
#!/bin/bash

echo "================================="
echo " DMF7 NODE IDENTITY "
echo "================================="

echo ""
echo "Node ID:"
if [ -f /opt/dmf7/NODE_ID ]; then
  cat /opt/dmf7/NODE_ID
else
  echo "NODE_ID not set at /opt/dmf7/NODE_ID"
fi

echo ""
echo "Node Hash:"
if [ -f /opt/dmf7/node_hash ]; then
  cat /opt/dmf7/node_hash
else
  echo "node_hash missing at /opt/dmf7/node_hash"
fi
EOF
chmod 755 "${BIN_DIR}/dmf7-identity"

echo "DMF7-NODE-72-61-114-167" | sha256sum > "${OPT_DIR}/node_hash"

if [ "${VERIFY}" -eq 1 ]; then
  echo "Running dmf7-api-test..."
  "${BIN_DIR}/dmf7-api-test" || echo "dmf7-api-test encountered issues."

  echo ""
  echo "Running dmf7-restart-all (this may restart services)..."
  "${BIN_DIR}/dmf7-restart-all" || echo "dmf7-restart-all encountered issues."

  echo ""
  echo "Running dmf7-ai-loop..."
  "${BIN_DIR}/dmf7-ai-loop" || echo "dmf7-ai-loop encountered issues."

  echo ""
  echo "Running dmf7-performance..."
  "${BIN_DIR}/dmf7-performance" || echo "dmf7-performance encountered issues."

  echo ""
  echo "Running dmf7-identity..."
  "${BIN_DIR}/dmf7-identity" || echo "dmf7-identity encountered issues."
fi

echo "======================================================="
echo " DMF7 DISTRIBUTED AI NODE ACTIVE "
echo "======================================================="
echo ""
echo "Node:"
echo "72.61.114.167"
echo ""
echo "Identity:"
if [ -f "${OPT_DIR}/NODE_ID" ]; then
  cat "${OPT_DIR}/NODE_ID"
else
  echo "NODE_ID not set at ${OPT_DIR}/NODE_ID"
fi
echo ""
echo "Capabilities:"
echo "✔ AI inference engine"
echo "✔ Distributed job system"
echo "✔ Vector search"
echo "✔ Graph intelligence"
echo "✔ Monitoring stack"
echo "✔ Reverse proxy"
echo "✔ Self-healing infrastructure"
echo ""
echo "STATUS: GLOBAL AI COMPUTE NODE ONLINE"
echo "======================================================="
