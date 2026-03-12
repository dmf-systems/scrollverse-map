#!/usr/bin/env bash
set -euo pipefail

# Create required DMF7 directories under /opt
dmf7_dirs=(
  /opt/dmf7
  /opt/dmf7/workspace
  /opt/dmf7/tasks
  /opt/dmf7/queue
  /opt/dmf7/logs
  /opt/dmf7/runtime
)

# Create local development workspace directories
local_dirs=(
  "$HOME/DMF7"
  "$HOME/DMF7/workspace"
  "$HOME/DMF7/tasks"
)

for dir in "${dmf7_dirs[@]}"; do
  mkdir -p "$dir"
done

for dir in "${local_dirs[@]}"; do
  mkdir -p "$dir"
done

# Install the dmf7-task helper to create timestamped queue jobs
cat > /usr/local/bin/dmf7-task <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

queue_dir="/opt/dmf7/queue"
mkdir -p "$queue_dir"

timestamp="$(date -u +"%Y%m%d%H%M%S%N")"
job_file="${queue_dir}/job-${timestamp}.txt"

payload="queued task"
if [ "$#" -gt 0 ]; then
  payload="$*"
fi

printf "%s\n" "$payload" > "$job_file"
echo "Created task: ${job_file}"
EOF

chmod +x /usr/local/bin/dmf7-task

echo "DMF7 workspace and task helper installed."
