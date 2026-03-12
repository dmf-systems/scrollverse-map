#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[dmf7-ai] $*"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log "This installer must run as root (sudo)."
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_ollama() {
  if command_exists ollama; then
    log "Ollama already installed."
  else
    log "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
  fi

  log "Pulling embedding model (nomic-embed-text)..."
  ollama pull nomic-embed-text
}

setup_python() {
  if ! command_exists python3; then
    log "Installing Python 3..."
    apt-get update
    apt-get install -y python3
  fi

  if ! command_exists pip3; then
    log "Installing pip..."
    apt-get update
    apt-get install -y python3-pip
  fi

  log "Installing Python dependencies..."
  pip3 install --upgrade ollama numpy fastapi uvicorn qdrant-client
}

write_embed_service() {
  install -d /opt/dmf7/ai

  cat >/opt/dmf7/ai/embed_server.py <<'PY'
from fastapi import FastAPI
import ollama

app = FastAPI()

@app.post("/embed")
async def embed(text: str):
    result = ollama.embeddings(
        model="nomic-embed-text",
        prompt=text
    )
    return {"embedding": result["embedding"]}
PY
}

write_ingest_script() {
  cat >/opt/dmf7/ai/ingest_to_qdrant.py <<'PY'
from qdrant_client import QdrantClient
import ollama
import uuid
import sys

client = QdrantClient("localhost", port=6333)

collection = "dmf7"

client.recreate_collection(
    collection_name=collection,
    vectors_config={"size": 768, "distance": "Cosine"}
)

text = sys.argv[1]

embedding = ollama.embeddings(
    model="nomic-embed-text",
    prompt=text
)["embedding"]

client.upsert(
    collection_name=collection,
    points=[
        {
            "id": str(uuid.uuid4()),
            "vector": embedding,
            "payload": {"text": text}
        }
    ]
)

print("Inserted")
PY
}

ensure_qdrant() {
  install -d /opt/dmf7/qdrant

  if ! command_exists docker; then
    log "Docker is required for Qdrant. Please install Docker and rerun."
    exit 1
  fi

  if docker ps --format '{{.Names}}' | grep -q '^qdrant$'; then
    log "Qdrant container already running."
  else
    log "Starting Qdrant container..."
    docker run -d \
      --name qdrant \
      -p 6333:6333 \
      -v /opt/dmf7/qdrant:/qdrant/storage \
      qdrant/qdrant
  fi
}

print_next_steps() {
  cat <<'EOF'
Embedding API:
  uvicorn embed_server:app --host 0.0.0.0 --port 8090

Test embedding endpoint:
  curl -X POST http://localhost:8090/embed \
    -H "Content-Type: application/json" \
    -d '{"text":"hello world"}'

Ingest sample text into Qdrant:
  python3 /opt/dmf7/ai/ingest_to_qdrant.py "DMF7 knowledge graph system"
EOF
}

main() {
  require_root
  install_ollama
  setup_python
  write_embed_service
  write_ingest_script
  ensure_qdrant
  log "AI embedding stack ready."
  print_next_steps
}

main "$@"
