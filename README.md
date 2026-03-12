# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## AI embedding + vector stack (DMF7)

Use `scripts/dmf7_ai_embedding_stack.sh` to install the Ollama embedding runtime, FastAPI embedding server, Qdrant vector DB, and ingestion helper in one shot.

Run as root (or with sudo):

```bash
sudo ./scripts/dmf7_ai_embedding_stack.sh
```

What it does:
- Installs Ollama and pulls the `nomic-embed-text` model
- Creates `/opt/dmf7/ai/embed_server.py` (FastAPI `/embed`)
- Creates `/opt/dmf7/ai/ingest_to_qdrant.py` (simple ingest CLI)
- Starts Qdrant via Docker with storage at `/opt/dmf7/qdrant`
- Prints commands to start the embedding API and ingest sample text

After install, start the API:

```bash
uvicorn embed_server:app --host 0.0.0.0 --port 8090
```

Test it:

```bash
curl -X POST http://localhost:8090/embed \
  -H "Content-Type: application/json" \
  -d '{"text":"hello world"}'
```

Ingest a sample vector:

```bash
python3 /opt/dmf7/ai/ingest_to_qdrant.py "DMF7 knowledge graph system"
```
