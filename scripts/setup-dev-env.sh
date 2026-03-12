#!/usr/bin/env bash
set -euo pipefail

SUDO=""
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  SUDO="sudo"
fi

APT_UPDATED=0
update_apt() {
  if [ "$APT_UPDATED" -eq 0 ]; then
    $SUDO apt-get update -y
    APT_UPDATED=1
  fi
}

ensure_pkg() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    update_apt
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
  fi
}

for pkg in git curl build-essential docker.io; do
  ensure_pkg "$pkg"
done

NVM_DIR="${HOME}/.nvm"
if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# shellcheck disable=SC1091
if [ -s "${NVM_DIR}/nvm.sh" ]; then
  # shellcheck disable=SC1090
  . "${NVM_DIR}/nvm.sh"
fi

nvm install 20
nvm alias default 20
nvm use 20

ensure_node_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    npm install -g "$tool"
  fi
}

for tool in pnpm pm2 turbo typescript ts-node nodemon eslint prettier; do
  ensure_node_tool "$tool"
done

install_gh() {
  if command -v gh >/dev/null 2>&1; then
    return
  fi

  for dep in ca-certificates gnupg lsb-release; do
    ensure_pkg "$dep"
  done

  if [ ! -f /usr/share/keyrings/githubcli-archive-keyring.gpg ]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    $SUDO chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  fi

  if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  fi

  update_apt
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y gh
}

install_gh

create_helper() {
  local path="$1"
  shift
  echo "$@" | $SUDO tee "$path" >/dev/null
  $SUDO chmod +x "$path"
}

create_helper "/usr/local/bin/dmf7-dev" "#!/usr/bin/env bash
set -euo pipefail

echo \"Node: \$(node -v 2>/dev/null || echo 'not found')\"
echo \"pnpm: \$(pnpm -v 2>/dev/null || echo 'not found')\"

echo \"Docker:\"
if command -v docker >/dev/null 2>&1; then
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active docker >/dev/null 2>&1 && echo \" - service: active\" || echo \" - service: inactive or unavailable\"
  fi
  docker ps --format ' - container {{.Names}} ({{.Status}})' 2>/dev/null || true
else
  echo \" - docker not installed\"
fi

echo \"PM2:\"
if command -v pm2 >/dev/null 2>&1; then
  pm2 status || true
else
  echo \" - pm2 not installed\"
fi
"

create_helper "/usr/local/bin/dmf7-health" "#!/usr/bin/env bash
set -euo pipefail

echo \"CPU Load:\"
cat /proc/loadavg 2>/dev/null || true

echo
echo \"Memory:\"
free -h || true

echo
echo \"Disk:\"
df -h || true

echo
echo \"Docker Containers:\"
if command -v docker >/dev/null 2>&1; then
  docker ps -a --format ' - {{.Names}} ({{.Status}})' || true
else
  echo \" - docker not installed\"
fi

echo
echo \"PM2 Processes:\"
if command -v pm2 >/dev/null 2>&1; then
  pm2 ls || true
else
  echo \" - pm2 not installed\"
fi
"

echo "Development environment setup complete."
