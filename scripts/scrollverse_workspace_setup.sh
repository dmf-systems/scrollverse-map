#!/usr/bin/env bash
set -euo pipefail

mkdir -p /opt/scrollverse /opt/scrollverse/workspace /opt/scrollverse/tasks /opt/scrollverse/queue /opt/scrollverse/logs
mkdir -p "$HOME/Scrollverse" "$HOME/Scrollverse/workspace" "$HOME/Scrollverse/tasks"

cat <<'EOF' >/usr/local/bin/scrollverse-task
#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: scrollverse-task \"task description\"" >&2
  exit 1
fi

timestamp="$(date +%Y%m%d%H%M%S)"
queue_dir="/opt/scrollverse/queue"
mkdir -p "$queue_dir"
task_file="${queue_dir}/task_${timestamp}"
printf '%s\n' "$*" >"$task_file"
echo "$task_file"
EOF

chmod +x /usr/local/bin/scrollverse-task
