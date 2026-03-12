#!/usr/bin/env bash
set -euo pipefail

# DMF7 automation steps 753-768: task scheduler, diagnostics timer, pipeline test, and capability report.

VERIFY="${1:-}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Please run this script as root." >&2
  exit 1
fi

mkdir -p /usr/local/bin
mkdir -p /opt/dmf7

cat >/usr/local/bin/dmf7-scheduler <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 TASK SCHEDULER "
echo "================================="

echo ""
echo "1) Run Platform Selftest"
echo "2) Run AI Benchmark"
echo "3) Run Diagnostics"
echo "4) Restart Platform"
echo "5) Run Cluster Health"
echo "0) Exit"

read -p "Select task: " TASK

case $TASK in

1)
dmf7-selftest
;;

2)
dmf7-ai-bench
;;

3)
dmf7-diagnose
;;

4)
dmf7-restart-all
;;

5)
dmf7-cluster-health
;;

0)
exit
;;

*)
echo "Invalid option"
;;

esac
EOF
chmod +x /usr/local/bin/dmf7-scheduler

cat >/etc/systemd/system/dmf7-diagnostics.service <<'EOF'
[Unit]
Description=DMF7 Automated Diagnostics

[Service]
Type=oneshot
ExecStart=/usr/local/bin/dmf7-selftest
EOF

cat >/etc/systemd/system/dmf7-diagnostics.timer <<'EOF'
[Unit]
Description=Run DMF7 Diagnostics Every Hour

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

SYSTEMCTL_BIN="$(command -v systemctl || true)"
if [[ -n "${SYSTEMCTL_BIN}" ]]; then
  systemctl daemon-reload
  systemctl enable dmf7-diagnostics.timer
  systemctl start dmf7-diagnostics.timer
else
  echo "systemctl not available; skipping timer enable/start." >&2
fi

cat >/usr/local/bin/dmf7-pipeline <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 AI PIPELINE TEST "
echo "================================="

echo ""
echo "Step 1 - Gateway"
curl -s http://localhost:4000

echo ""
echo "Step 2 - Vector DB"
curl -s http://localhost:6333/collections

echo ""
echo "Step 3 - Graph DB"
curl -s http://localhost:7474

echo ""
echo "Step 4 - AI Runtime"
ollama run llama3 "Confirm DMF7 AI pipeline working."
EOF
chmod +x /usr/local/bin/dmf7-pipeline

cat >/usr/local/bin/dmf7-capabilities <<'EOF'
#!/bin/bash

echo "================================="
echo " DMF7 PLATFORM CAPABILITIES "
echo "================================="

echo ""
echo "AI:"
echo " - Local LLM inference"
echo " - Job submission"
echo " - AI pipeline"

echo ""
echo "Data:"
echo " - Vector search (Qdrant)"
echo " - Graph database (Neo4j)"

echo ""
echo "Platform:"
echo " - Gateway API"
echo " - Operator console"
echo " - Monitoring"

echo ""
echo "Automation:"
echo " - Self healing"
echo " - Orchestrator"
echo " - Backup timers"
EOF
chmod +x /usr/local/bin/dmf7-capabilities

touch /opt/dmf7/NODE_READY

if [[ "${VERIFY}" == "--verify" ]]; then
  echo "Verifying diagnostics timer..."
  if [[ -n "${SYSTEMCTL_BIN}" ]]; then
    systemctl list-timers --all | grep dmf7 || true
  else
    echo "systemctl unavailable; cannot list timers." >&2
  fi

  echo "Checking helper scripts..."
  for helper in /usr/local/bin/dmf7-scheduler /usr/local/bin/dmf7-pipeline /usr/local/bin/dmf7-capabilities; do
    if [[ -x "${helper}" ]]; then
      echo " - ${helper} is present."
    else
      echo " - ${helper} missing or not executable." >&2
    fi
  done
fi

echo "===================================================="
echo " DMF7 AUTONOMOUS AI SUPER NODE "
echo "===================================================="
echo ""
echo "Node:"
echo "72.61.114.167"
echo ""
echo "State:"
echo "READY"
echo ""
echo "Capabilities:"
echo " - AI inference"
echo " - AI pipeline"
echo " - Vector intelligence"
echo " - Graph intelligence"
echo " - Monitoring"
echo " - Self-healing orchestration"
echo ""
echo "Control:"
echo "dmf7-control"
echo ""
echo "STATUS: AUTONOMOUS AI PLATFORM READY"
echo "===================================================="
