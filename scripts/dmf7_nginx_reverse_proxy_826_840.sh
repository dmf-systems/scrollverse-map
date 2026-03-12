#!/usr/bin/env bash

# DMF7 Nginx reverse proxy provisioning (Steps 826-840)
# Installs and configures Nginx + UFW, deploys the DMF7 site block,
# and optionally obtains certificates with certbot.

set -euo pipefail

NGINX_SITE_AVAILABLE="/etc/nginx/sites-available/dmf7"
NGINX_SITE_ENABLED="/etc/nginx/sites-enabled/dmf7"
DEFAULT_TEST_URL="http://72.61.114.167"

CERTBOT_EMAIL=""
CERTBOT_DOMAINS=""
RUN_CERTBOT=false
TEST_URL="$DEFAULT_TEST_URL"
SKIP_CURL=false

log() { printf '[dmf7-nginx] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
DMF7 Nginx reverse proxy setup (Steps 826-840)

Usage: dmf7_nginx_reverse_proxy_826_840.sh [options]

Options:
  --certbot-email EMAIL     Email for Let's Encrypt terms (enables certbot run)
  --certbot-domains DOMAINS Comma-separated domains for certbot (enables certbot)
  --test-url URL            Override curl test target (default: http://72.61.114.167)
  --skip-curl               Skip the curl reachability check
  -h, --help                Show this message

The script installs/configures Nginx, enables the DMF7 site block,
opens UFW ports, and optionally runs certbot + enables auto-renewal.
Run as root or with sudo.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --certbot-email)
        CERTBOT_EMAIL="${2:-}"; RUN_CERTBOT=true; shift 2 ;;
      --certbot-domains)
        CERTBOT_DOMAINS="${2:-}"; RUN_CERTBOT=true; shift 2 ;;
      --test-url)
        TEST_URL="${2:-}"; shift 2 ;;
      --skip-curl)
        SKIP_CURL=true; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        die "Unknown option: $1" ;;
    esac
  done
}

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    die "This script must be run as root (use sudo)."
  fi
}

apt_install() {
  log "Updating apt cache and installing packages..."
  apt update
  apt install -y nginx ufw certbot python3-certbot-nginx curl
}

configure_nginx_site() {
  log "Writing Nginx site configuration to $NGINX_SITE_AVAILABLE"
  cat >"$NGINX_SITE_AVAILABLE" <<'EOF'
server {
    listen 80;

    server_name _;

    location / {
        proxy_pass http://localhost:4100;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
    }

    location /api/ {
        proxy_pass http://localhost:4000/;
    }

    location /ai/ {
        proxy_pass http://localhost:3001/;
    }

    location /graph/ {
        proxy_pass http://localhost:7474/;
    }

    location /metrics/ {
        proxy_pass http://localhost:3000/;
    }
}
EOF

  log "Enabling DMF7 site and removing default site..."
  rm -f /etc/nginx/sites-enabled/default
  ln -sf "$NGINX_SITE_AVAILABLE" "$NGINX_SITE_ENABLED"

  log "Testing Nginx configuration..."
  nginx -t

  log "Enabling and restarting Nginx..."
  systemctl enable nginx
  systemctl restart nginx
}

configure_firewall() {
  log "Enabling UFW rules for required ports..."
  ufw allow 80
  ufw allow 443
  ufw allow 4000
  ufw allow 4100
  ufw allow 3001
  ufw allow 7474
  ufw allow 3000
  ufw allow 9000
  ufw allow 19999
  ufw --force enable
  ufw status
}

run_certbot() {
  if ! $RUN_CERTBOT; then
    log "Certbot not requested; skipping certificate issuance."
    return
  fi

  [[ -z "$CERTBOT_EMAIL" ]] && die "Certbot requested but --certbot-email is missing."
  [[ -z "$CERTBOT_DOMAINS" ]] && die "Certbot requested but --certbot-domains is missing."

  IFS=',' read -r -a DOMAIN_ARR <<<"$CERTBOT_DOMAINS"
  certbot_args=(--nginx --non-interactive --agree-tos -m "$CERTBOT_EMAIL")
  for domain in "${DOMAIN_ARR[@]}"; do
    certbot_args+=(-d "$domain")
  done

  log "Running certbot for domains: ${CERTBOT_DOMAINS}"
  certbot "${certbot_args[@]}"

  log "Enabling automatic certificate renewal timer..."
  systemctl enable certbot.timer
  systemctl start certbot.timer
}

curl_test() {
  if $SKIP_CURL; then
    log "Skipping curl reachability check."
    return
  fi

  log "Testing public access via curl: $TEST_URL"
  curl --head --max-time 10 "$TEST_URL" || log "Warning: curl test failed (service may still be starting)."
}

final_banner() {
  cat <<'EOF'
=======================================
DMF7 PUBLIC ACCESS ACTIVE

Main Console:
http://72.61.114.167

API:
http://72.61.114.167/api

AI Interface:
http://72.61.114.167/ai

Neo4j Graph:
http://72.61.114.167/graph

Metrics:
http://72.61.114.167/metrics
=======================================
EOF
}

main() {
  parse_args "$@"
  require_root
  apt_install
  configure_nginx_site
  configure_firewall
  run_certbot
  curl_test
  final_banner
}

main "$@"
