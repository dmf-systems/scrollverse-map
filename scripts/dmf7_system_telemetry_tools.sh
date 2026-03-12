#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

echo "Installing hardware telemetry dependencies..."
apt-get update -y
apt-get install -y lm-sensors smartmontools

echo "Detecting sensors..."
sensors-detect --auto

echo "Verifying sensors..."
sensors

cat >/usr/local/bin/dmf7-hardware <<'EOF'
#!/bin/bash

echo "=============================="
echo " DMF7 HARDWARE STATUS "
echo "=============================="

echo ""
echo "CPU INFO:"
lscpu | grep "Model name"

echo ""
echo "TEMPERATURE:"
sensors

echo ""
echo "DISK HEALTH:"
if [ -b /dev/sda ]; then
  smartctl -H /dev/sda
else
  echo "/dev/sda not found"
fi

echo ""
echo "MEMORY:"
free -h
EOF

chmod +x /usr/local/bin/dmf7-hardware

cat >/usr/local/bin/dmf7-pull-model <<'EOF'
#!/bin/bash
set -euo pipefail

MODEL=${1:-}

if [ -z "$MODEL" ]; then
  echo "Usage: dmf7-pull-model <model>"
  exit 1
fi

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama is not installed; install it before pulling models."
  exit 1
fi

echo "Pulling model $MODEL"
ollama pull "$MODEL"
EOF

chmod +x /usr/local/bin/dmf7-pull-model

echo "Testing hardware status script..."
/usr/local/bin/dmf7-hardware

echo "Setup complete."
