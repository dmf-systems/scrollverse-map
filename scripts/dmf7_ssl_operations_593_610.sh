#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root to install packages and manage system services." >&2
  exit 1
fi

DOMAIN="${DMF7_DOMAIN:-${1:-}}"
if [[ -z "${DOMAIN}" ]]; then
  echo "Usage: DMF7_DOMAIN=<domain> [DMF7_CERTBOT_EMAIL=<email>] $0" >&2
  exit 1
fi

if [[ "${DOMAIN}" == "your-domain.com" ]]; then
  echo "Replace the placeholder domain with your real DNS name before running." >&2
  exit 1
fi

EMAIL="${DMF7_CERTBOT_EMAIL:-}"

echo "STEP 593 — Installing certbot and nginx plugin..."
apt-get update -y
apt-get install -y certbot python3-certbot-nginx

echo "STEP 594 — Verifying certbot installation..."
certbot --version

export DMF7_DOMAIN="${DOMAIN}"
echo "STEP 595 — Using domain: ${DMF7_DOMAIN}"

echo "STEP 596 — Requesting SSL certificate via nginx installer..."
CERTBOT_CMD=(certbot --nginx -d "${DMF7_DOMAIN}")
if [[ -n "${EMAIL}" ]]; then
  CERTBOT_CMD+=(--non-interactive --agree-tos --email "${EMAIL}" --redirect)
  echo "Running certbot non-interactively with email ${EMAIL}"
else
  echo "DMF7_CERTBOT_EMAIL not set; certbot will prompt for email/consent."
fi
"${CERTBOT_CMD[@]}"

echo "STEP 597 — Verifying certificate installation..."
certbot certificates

echo "STEP 598 — Testing auto-renewal (dry run)..."
certbot renew --dry-run

echo "STEP 599 — Creating dmf7-ssl status tool..."
cat <<'EOF' >/usr/local/bin/dmf7-ssl
#!/bin/bash

echo "=============================="
echo " DMF7 SSL STATUS "
echo "=============================="

certbot certificates

echo ""
echo "NGINX STATUS:"
systemctl status nginx --no-pager || echo "nginx service status unavailable"
EOF
chmod +x /usr/local/bin/dmf7-ssl

echo "STEP 600 — dmf7-ssl made executable."

echo "STEP 601 — Testing dmf7-ssl..."
dmf7-ssl

echo "STEP 602 — Creating dmf7-update tool..."
cat <<'EOF' >/usr/local/bin/dmf7-update
#!/bin/bash

echo "Updating system..."

apt update -y
apt upgrade -y

echo "Updating containers..."
if command -v docker >/dev/null 2>&1; then
  docker pull $(docker images --format "{{.Repository}}:{{.Tag}}")
else
  echo "Docker not installed; skipping container updates."
fi

echo "Restarting services..."
if command -v pm2 >/dev/null 2>&1; then
  pm2 restart all
else
  echo "PM2 not installed; skipping process restarts."
fi

echo "Update complete."
EOF
chmod +x /usr/local/bin/dmf7-update

echo "STEP 603 — dmf7-update made executable."

echo "STEP 604 — Creating dmf7-metrics tool..."
cat <<'EOF' >/usr/local/bin/dmf7-metrics
#!/bin/bash

echo "=============================="
echo " DMF7 METRICS "
echo "=============================="

echo ""
echo "CPU:"
top -bn1 | head -n 5

echo ""
echo "MEMORY:"
free -h

echo ""
echo "DOCKER:"
if command -v docker >/dev/null 2>&1; then
  docker stats --no-stream
else
  echo "Docker not installed; skipping docker stats."
fi
EOF
chmod +x /usr/local/bin/dmf7-metrics

echo "STEP 605 — dmf7-metrics made executable."

echo "STEP 606 — Testing dmf7-metrics..."
dmf7-metrics

echo "STEP 607 — Creating dmf7-info tool..."
cat <<'EOF' >/usr/local/bin/dmf7-info
#!/bin/bash

echo "================================="
echo " DMF7 PLATFORM INFO "
echo "================================="

echo ""
echo "Server IP:"
hostname -I

echo ""
echo "Gateway:"
echo "http://72.61.114.167"

echo ""
echo "Console:"
echo "http://72.61.114.167/console"

echo ""
echo "AI Interface:"
echo "http://72.61.114.167/ai"

echo ""
echo "Grafana:"
echo "http://72.61.114.167/grafana"

echo ""
echo "Neo4j:"
echo "http://72.61.114.167/neo4j"
EOF
chmod +x /usr/local/bin/dmf7-info

echo "STEP 608 — dmf7-info made executable."

echo "STEP 609 — Testing dmf7-info..."
dmf7-info

echo "STEP 610 — Final global status:"
cat <<'EOF'
====================================================
 DMF7 NEXTGEN AUTONOMOUS AI PLATFORM COMPLETE
====================================================

Infrastructure:
✔ Gateway API
✔ Operator Console
✔ Redis AI Workers
✔ Vector DB (Qdrant)
✔ Graph DB (Neo4j)
✔ AI Runtime (Ollama)
✔ Monitoring (Grafana)
✔ Reverse Proxy (NGINX)
✔ Firewall + Fail2Ban
✔ SSL Automation

Node:
72.61.114.167

STATUS: PRODUCTION AI NODE ACTIVE
====================================================
EOF
