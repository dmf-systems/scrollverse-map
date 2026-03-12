#!/usr/bin/env bash
set -euo pipefail

mkdir -p /opt/dmf7 /opt/dmf7/workspace /opt/dmf7/tasks /opt/dmf7/queue /opt/dmf7/logs /opt/dmf7/runtime
mkdir -p "$HOME/DMF7" "$HOME/DMF7/workspace" "$HOME/DMF7/tasks"

cat <<"EOF" > /usr/local/bin/dmf7-task
#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: dmf7-task \"task description\"" >&2
  exit 1
fi

timestamp=$(date +'%Y%m%d_%H%M%S')
task_dir="/opt/dmf7/queue"
task_file="${task_dir}/task_${timestamp}.job"

mkdir -p "$task_dir"
printf '%s\n' "$*" > "$task_file"
echo "$task_file"
EOF
