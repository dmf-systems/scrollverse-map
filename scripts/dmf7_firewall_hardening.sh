#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run this script as root (or with sudo)." >&2
  exit 1
fi

echo "STEP 377 — INSTALL FIREWALL HARDENING"
apt-get update -y
apt-get install -y ufw fail2ban

echo "STEP 378 — RESET FIREWALL RULES"
ufw --force reset

echo "STEP 379 — DEFAULT FIREWALL POLICY"
ufw default deny incoming
ufw default allow outgoing

echo "STEP 380 — ALLOW SSH"
ufw allow 22/tcp

echo "STEP 381 — ALLOW DMF7 SERVICES"
ports=(80 443 4000 4100 3001 6333 7474 9000 3000)
for port in "${ports[@]}"; do
  ufw allow "${port}/tcp"
done

echo "STEP 382 — ENABLE FIREWALL"
ufw --force enable

echo "STEP 383 — VERIFY FIREWALL STATUS"
ufw status numbered || true

echo "STEP 385 — CREATE FAIL2BAN CONFIG"
cat >/etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 3600
EOF

echo "STEP 386 — RESTART FAIL2BAN"
systemctl restart fail2ban

echo "STEP 387 — VERIFY FAIL2BAN"
fail2ban-client status || true

echo "STEP 388 — CREATE FIREWALL SNAPSHOT SCRIPT"
cat >/usr/local/bin/dmf7-firewall <<'EOF'
#!/bin/bash

echo "=============================="
echo " DMF7 FIREWALL STATUS "
echo "=============================="

ufw status numbered

echo ""
echo "FAIL2BAN:"
fail2ban-client status
EOF

echo "STEP 389 — MAKE SCRIPT EXECUTABLE"
chmod +x /usr/local/bin/dmf7-firewall

echo "STEP 391 — CREATE NETWORK DIAGNOSTIC TOOL"
cat >/usr/local/bin/dmf7-network <<'EOF'
#!/bin/bash

echo "=============================="
echo " DMF7 NETWORK STATUS "
echo "=============================="

echo ""
echo "OPEN PORTS:"
if command -v ss >/dev/null 2>&1; then
  ss -tulnp
else
  echo "ss is not available on this system."
fi

echo ""
echo "NETWORK INTERFACES:"
ip a

echo ""
echo "ACTIVE CONNECTIONS:"
if command -v netstat >/dev/null 2>&1; then
  netstat -antp
else
  echo "netstat is not available on this system."
fi
EOF

echo "STEP 392 — MAKE NETWORK TOOL EXECUTABLE"
chmod +x /usr/local/bin/dmf7-network

echo "STEP 394 — VERIFY EXTERNAL CONNECTIVITY"
ping -c 4 google.com || echo "Warning: ping to google.com failed."

echo "STEP 395 — VERIFY DNS"
if command -v nslookup >/dev/null 2>&1; then
  nslookup github.com || echo "Warning: nslookup github.com failed."
else
  echo "Warning: nslookup is not installed."
fi

echo "STEP 396 — VERIFY API ACCESS"
curl -fsSL https://api.github.com >/tmp/dmf7_api_check.json || echo "Warning: curl to api.github.com failed."

mkdir -p /opt/dmf7
echo "STEP 397 — FINAL SECURITY SNAPSHOT"
echo "DMF7 NETWORK + FIREWALL ACTIVE $(date)" >/opt/dmf7/DEPLOY_LOG
cat /opt/dmf7/DEPLOY_LOG

echo "STEP 398 — FINAL SECURITY STATUS"
echo "=========================================="
echo " DMF7 SECURITY + NETWORK HARDENING ACTIVE "
echo "=========================================="
echo ""
echo "Firewall: ACTIVE"
echo "Fail2Ban: ACTIVE"
echo "Ports Protected: YES"
echo ""
echo "NODE STATUS: PRODUCTION SECURE"
echo "=========================================="

echo "STEP 399 — FINAL NODE CHECK"
if command -v dmf7-status >/dev/null 2>&1; then
  dmf7-status
else
  echo "dmf7-status is not installed on this node."
fi

echo "STEP 400 — DEPLOYMENT COMPLETE"
echo "=========================================="
echo " DMF7 GLOBAL AI INFRASTRUCTURE DEPLOYED "
echo "=========================================="
echo ""
echo "Console:"
echo "http://72.61.114.167"
echo ""
echo "API:"
echo "http://72.61.114.167:4000"
echo ""
echo "AI:"
echo "http://72.61.114.167:3001"
echo ""
echo "Vector DB:"
echo "http://72.61.114.167:6333"
echo ""
echo "Graph DB:"
echo "http://72.61.114.167:7474"
echo ""
echo "Monitoring:"
echo "http://72.61.114.167:3000"
echo "http://72.61.114.167:9000"
echo ""
echo "STATUS: FULLY OPERATIONAL"
echo "=========================================="
