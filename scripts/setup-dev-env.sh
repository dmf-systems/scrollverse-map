#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[setup-dev-env] $*"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_sudo() {
  if ! has_cmd sudo; then
    log "sudo is required for installations. Please install sudo and rerun."
    exit 1
  fi
}

apt_updated=0
apt_install() {
  require_sudo
  if [[ ${apt_updated} -eq 0 ]]; then
    log "Updating apt package index..."
    sudo apt-get update -y
    apt_updated=1
  fi
  log "Installing packages: $*"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

ensure_node() {
  if has_cmd node && has_cmd npm; then
    log "Node.js already installed (node $(node -v))"
    return
  fi
  log "Node.js not found. Installing Node.js and npm..."
  apt_install nodejs npm
}

ensure_pnpm() {
  if has_cmd pnpm; then
    log "pnpm already installed (pnpm $(pnpm -v))"
    return
  fi
  log "pnpm not found. Installing via npm..."
  require_sudo
  sudo npm install -g pnpm
}

ensure_pm2() {
  if has_cmd pm2; then
    log "pm2 already installed (pm2 $(pm2 -v | head -n 1))"
    return
  fi
  log "pm2 not found. Installing via npm..."
  require_sudo
  sudo npm install -g pm2
}

ensure_docker() {
  if has_cmd docker; then
    log "Docker already installed (docker $(docker --version | head -n 1))"
    return
  fi
  log "Docker not found. Installing docker.io..."
  apt_install docker.io
  log "Enabling and starting docker service..."
  require_sudo
  sudo systemctl enable --now docker
}

ensure_global_tool() {
  local tool="$1"
  local pkg="${2:-$1}"
  if has_cmd "$tool"; then
    log "$tool already installed ($($tool --version 2>/dev/null | head -n 1 || echo "version check unavailable"))"
    return
  fi
  log "$tool not found. Installing $pkg via npm..."
  require_sudo
  sudo npm install -g "$pkg"
}

ensure_gh_cli() {
  if has_cmd gh; then
    log "GitHub CLI already installed (gh $(gh --version | head -n 1))"
    return
  fi
  log "GitHub CLI not found. Installing gh..."
  # Try apt if available; otherwise fallback to npm-based install
  if has_cmd apt-get; then
    apt_install gh || true
    if has_cmd gh; then
      return
    fi
    log "apt-based gh install failed; falling back to script install."
  fi
  if has_cmd curl && has_cmd sudo; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
      sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
      sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gh
  else
    log "curl or sudo unavailable; cannot install gh automatically."
  fi
}

install_helper() {
  local path="$1"
  local content="$2"
  log "Installing helper ${path}..."
  require_sudo
  echo "${content}" | sudo tee "${path}" >/dev/null
  sudo chmod +x "${path}"
}

ensure_helpers() {
  install_helper "/usr/local/bin/dmf7-dev" "#!/usr/bin/env bash
set -euo pipefail

if command -v pnpm >/dev/null 2>&1; then
  pnpm install
  pnpm dev
elif command -v npm >/dev/null 2>&1; then
  npm install
  npm run dev
else
  echo \"pnpm or npm not found; cannot start dev server.\" >&2
  exit 1
fi
"

  install_helper "/usr/local/bin/dmf7-health" "#!/usr/bin/env bash
set -euo pipefail

echo \"== DMF7 Health Check ==\"
if command -v pm2 >/dev/null 2>&1; then
  pm2 status || true
else
  echo \"pm2 not installed\"
fi

if command -v docker >/dev/null 2>&1; then
  docker ps --format \"table {{.Names}}\\t{{.Status}}\\t{{.Ports}}\" || true
else
  echo \"docker not installed\"
fi
"
}

log "Starting DMF7 development environment setup..."

ensure_node
ensure_pnpm
ensure_pm2
ensure_docker

ensure_global_tool "tsc" "typescript"
ensure_global_tool "ts-node" "ts-node"
ensure_global_tool "nodemon" "nodemon"
ensure_global_tool "eslint" "eslint"
ensure_global_tool "prettier" "prettier"

ensure_global_tool "turbo" "turbo"
ensure_gh_cli
ensure_helpers

log "Setup complete."
