#!/usr/bin/env bash
set -euo pipefail

echo "[dmf7] Installing Ollama and nomic-embed-text model..."

require_sudo=false
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  require_sudo=true
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required to install Ollama; run as root or install sudo." >&2
    exit 1
  fi
fi

if command -v ollama >/dev/null 2>&1; then
  echo "[dmf7] Ollama already present; skipping installer."
else
  echo "[dmf7] Installing Ollama (https://ollama.com/install.sh)..."
  if [[ "$require_sudo" == true ]]; then
    sudo sh -c "curl -fsSL https://ollama.com/install.sh | sh"
  else
    sh -c "curl -fsSL https://ollama.com/install.sh | sh"
  fi
fi

echo "[dmf7] Pulling nomic-embed-text model (idempotent)..."
ollama pull nomic-embed-text

echo "[dmf7] Done. Verify the ollama service is running before issuing embedding requests."
