#!/bin/bash
set -euo pipefail

# Installs the dmf7-job helper that queues AI prompts for processing.

install -d /usr/local/bin

cat <<'EOF' >/usr/local/bin/dmf7-job
#!/bin/bash
set -euo pipefail

MODEL=${1:-llama3}
PROMPT="${2:-}"

if [ -z "$PROMPT" ]; then
  echo "Usage:"
  echo "dmf7-job [model] \"prompt\""
  exit 1
fi

QUEUE_DIR="/opt/dmf7/ai-jobs"
mkdir -p "$QUEUE_DIR"

JOB_ID="$(date +%Y%m%d%H%M%S)-$RANDOM"
JOB_FILE="${QUEUE_DIR}/${JOB_ID}.json"

cat <<'JOB' >"$JOB_FILE"
{
  "id": "__JOB_ID__",
  "model": "__MODEL__",
  "prompt": "__PROMPT__",
  "created_at": "__CREATED_AT__"
}
JOB

sed -i \
  -e "s/__JOB_ID__/${JOB_ID}/" \
  -e "s/__MODEL__/${MODEL}/" \
  -e "s/__PROMPT__/$(printf '%s' "$PROMPT" | sed 's/[\\/&]/\\&/g')/" \
  -e "s/__CREATED_AT__/$(date -Is)/" \
  "$JOB_FILE"

echo "Queued job ${JOB_ID} for model ${MODEL}"
echo "Job file: ${JOB_FILE}"
EOF

chmod +x /usr/local/bin/dmf7-job

echo "dmf7-job installed at /usr/local/bin/dmf7-job"
