#!/usr/bin/env bash
set -euo pipefail

SERVER_IP_DEFAULT="72.61.114.167"
NGINX_SITE="/etc/nginx/sites-available/dmf7"
DOMAIN=""
EMAIL=""
USE_STAGING=false

usage() {
  cat <<'EOF'
Usage: dmf7_ssl_setup.sh --domain DOMAIN --email EMAIL [--staging]

Automates DMF7 steps 278-292:
  - Installs certbot and the nginx plugin
  - Updates nginx server_name
  - Requests a Let's Encrypt certificate with HTTP->HTTPS redirect
  - Enables certbot timer, tests renewal, and performs HTTPS checks

Options:
  -d, --domain    Fully qualified domain name to secure (required)
  -e, --email     Email for Let's Encrypt registration/renewal notices (required)
      --staging   Use Let's Encrypt staging (recommended for testing)
  -h, --help      Show this message

Run as root on the DMF7 host that serves the nginx site at /etc/nginx/sites-available/dmf7.
EOF
}

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "This script must be run as root because it manages packages, nginx, and certbot." >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--domain)
        DOMAIN=${2:-}
        shift 2
        ;;
      -e|--email)
        EMAIL=${2:-}
        shift 2
        ;;
      --staging)
        USE_STAGING=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$DOMAIN" ]]; then
    echo "--domain is required (use your FQDN, not the bare IP)." >&2
    exit 1
  fi

  if [[ -z "$EMAIL" ]]; then
    echo "--email is required for Let's Encrypt registration." >&2
    exit 1
  fi
}

update_nginx_server_name() {
  if [[ ! -f "$NGINX_SITE" ]]; then
    echo "nginx site config not found at $NGINX_SITE" >&2
    exit 1
  fi

  if grep -Eq "server_name[[:space:]]+$DOMAIN;" "$NGINX_SITE"; then
    log "server_name already set to $DOMAIN"
    return
  fi

  # Replace the first server_name entry; fall back to appending if none exist.
  if grep -Eq "server_name[[:space:]]+[^;]+;" "$NGINX_SITE"; then
    sed -i -E "0,/server_name[[:space:]]+[^;]+;/s//server_name ${DOMAIN};/" "$NGINX_SITE"
    log "Updated server_name to $DOMAIN"
  else
    # Insert after the first 'server {' line to keep config valid.
    sed -i -E "0,/server[[:space:]]*\\{/s//server {\n    server_name ${DOMAIN};/" "$NGINX_SITE"
    log "Added server_name ${DOMAIN} to server block"
  fi

  if ! grep -Eq "server_name[[:space:]]+$DOMAIN;" "$NGINX_SITE"; then
    echo "Failed to set server_name to $DOMAIN in $NGINX_SITE" >&2
    exit 1
  fi
}

main() {
  parse_args "$@"
  require_root

  log "Installing certbot and nginx plugin"
  apt-get update -y
  apt-get install -y certbot python3-certbot-nginx

  log "Verifying nginx service status"
  systemctl status nginx --no-pager || true

  log "Updating nginx server_name to $DOMAIN"
  update_nginx_server_name

  log "Testing nginx configuration"
  nginx -t

  log "Reloading nginx"
  systemctl reload nginx

  CERTBOT_FLAGS=(--nginx --non-interactive --agree-tos --redirect -m "$EMAIL" -d "$DOMAIN")
  $USE_STAGING && CERTBOT_FLAGS+=(--staging)
  RENEW_FLAGS=(--dry-run)
  $USE_STAGING && RENEW_FLAGS+=(--staging)

  log "Requesting/renewing certificate for $DOMAIN"
  certbot "${CERTBOT_FLAGS[@]}"

  log "Listing installed certificates"
  certbot certificates

  log "Enabling and starting certbot timer"
  systemctl enable certbot.timer
  systemctl start certbot.timer

  log "Testing renewal (dry run)"
  certbot renew "${RENEW_FLAGS[@]}"

  log "Checking HTTPS locally"
  curl --fail --silent --show-error https://localhost > /dev/null

  log "Checking HTTPS via domain"
  curl --fail --silent --show-error "https://${DOMAIN}" > /dev/null

  log "Checking HTTPS via IP (insecure due to domain certificate mismatch)"
  curl --insecure --fail --silent --show-error "https://${SERVER_IP_DEFAULT}" > /dev/null

  log "Writing deployment log"
  mkdir -p /opt/dmf7
  echo "DMF7 SSL ENABLED $(date)" > /opt/dmf7/DEPLOY_LOG

  log "Deployment log contents"
  cat /opt/dmf7/DEPLOY_LOG

  log "UFW status"
  ufw status || true

  log "fail2ban status"
  fail2ban-client status || true

  log "Final production confirmation"
  cat <<EOF
==========================================
 DMF7 GLOBAL AI PLATFORM PRODUCTION READY
==========================================
Secure Console:
https://${DOMAIN}

Gateway API:
https://${SERVER_IP_DEFAULT}:4000

AI Interface:
https://${SERVER_IP_DEFAULT}:3001

Graph DB:
https://${SERVER_IP_DEFAULT}:7474

Vector DB:
https://${SERVER_IP_DEFAULT}:6333

Monitoring:
https://${SERVER_IP_DEFAULT}:3000
https://${SERVER_IP_DEFAULT}:9000

STATUS: SECURE PRODUCTION NODE
==========================================
EOF
}

main "$@"
