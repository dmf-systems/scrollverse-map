#!/usr/bin/env bash
set -euo pipefail

SERVER_NAME="${SERVER_NAME:-72.61.114.167}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
RUN_CERTBOT="false"
RUN_VERIFY="false"

usage() {
    cat <<EOF
Usage: sudo ./scripts/setup_dmf7_node.sh [options]

Options:
  --server-name <domain_or_ip>   Server name to place in nginx config (default: ${SERVER_NAME})
  --certbot-email <email>        Email address for certbot --agree-tos (required if --run-certbot)
  --run-certbot                  Run certbot --nginx for HTTPS
  --verify                       Run non-fatal post-setup checks (curls, docker logs)
  --help                         Show this help

Environment overrides:
  SERVER_NAME, CERTBOT_EMAIL, RUN_CERTBOT=true, RUN_VERIFY=true
EOF
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "This script must be run as root (sudo)." >&2
        exit 1
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --server-name)
                SERVER_NAME="$2"
                shift 2
                ;;
            --certbot-email)
                CERTBOT_EMAIL="$2"
                shift 2
                ;;
            --run-certbot)
                RUN_CERTBOT="true"
                shift
                ;;
            --verify)
                RUN_VERIFY="true"
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
}

install_packages() {
    echo "Installing nginx and certbot..."
    apt-get update
    apt-get install -y nginx certbot python3-certbot-nginx
    systemctl enable nginx
    systemctl start nginx
}

write_nginx_config() {
    echo "Writing nginx config to /etc/nginx/sites-available/dmf7..."
    cat >/etc/nginx/sites-available/dmf7 <<EOF
server {
    listen 80;
    server_name ${SERVER_NAME};

    location / {
        proxy_pass http://localhost:4100;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /api/ {
        proxy_pass http://localhost:4000/;
    }

    location /ai/ {
        proxy_pass http://localhost:3001/;
    }

    location /grafana/ {
        proxy_pass http://localhost:3000/;
    }

    location /neo4j/ {
        proxy_pass http://localhost:7474/;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/dmf7 /etc/nginx/sites-enabled/dmf7
    nginx -t
    systemctl reload nginx
}

setup_logrotate() {
    echo "Configuring logrotate for /opt/dmf7/logs/*.log..."
    cat >/etc/logrotate.d/dmf7 <<'EOF'
/opt/dmf7/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
}
EOF
}

install_restart_script() {
    echo "Installing /root/dmf7-restart.sh..."
    cat >/root/dmf7-restart.sh <<'EOF'
#!/bin/bash
docker restart redis-ai
docker restart qdrant
docker restart neo4j
docker restart ollama
pm2 restart all
systemctl restart nginx
echo "DMF7 stack restarted"
EOF
    chmod +x /root/dmf7-restart.sh
}

restart_autoheal() {
    if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q '^autoheal$'; then
        echo "Restarting autoheal container..."
        docker restart autoheal || true
    fi
}

maybe_run_certbot() {
    if [[ "${RUN_CERTBOT}" == "true" ]]; then
        if [[ -z "${CERTBOT_EMAIL}" ]]; then
            echo "CERTBOT_EMAIL is required when --run-certbot is set." >&2
            exit 1
        fi
        echo "Requesting certificates with certbot for ${SERVER_NAME}..."
        certbot --nginx -d "${SERVER_NAME}" --non-interactive --agree-tos -m "${CERTBOT_EMAIL}" --redirect
        echo "Dry-running certbot renewal..."
        certbot renew --dry-run
    fi
}

maybe_verify() {
    if [[ "${RUN_VERIFY}" != "true" ]]; then
        return
    fi

    echo "Running verification checks (non-fatal)..."
    set +e
    docker logs qdrant --tail 20 || true
    docker logs neo4j --tail 20 || true
    docker logs redis-ai --tail 20 || true

    curl --fail --silent --show-error http://localhost:11435/api/tags || true
    curl --fail --silent --show-error http://localhost:6333/collections || true
    curl --fail --silent --show-error http://localhost:7474 || true

    curl --fail --silent --show-error http://localhost/api || true
    curl --fail --silent --show-error http://localhost || true
    curl --fail --silent --show-error http://localhost/ai || true

    pm2 list || true
    docker ps || true
    systemctl status nginx --no-pager || true
    set -e
}

print_endpoints() {
    cat <<EOF
DMF7 NODE READY
Console: http://${SERVER_NAME}
API: http://${SERVER_NAME}/api
AI UI: http://${SERVER_NAME}/ai
Grafana: http://${SERVER_NAME}/grafana
Neo4j: http://${SERVER_NAME}/neo4j
Portainer: http://${SERVER_NAME}:9000
EOF
}

main() {
    parse_args "$@"
    require_root
    install_packages
    write_nginx_config
    setup_logrotate
    install_restart_script
    restart_autoheal
    maybe_run_certbot
    maybe_verify
    print_endpoints
}

main "$@"
