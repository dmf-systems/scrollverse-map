# scrollverse-map

A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Node Snapshot
The current DMF7 stack already includes the gateway/console, task and data pipelines, Docker/PM2 runtime, Redis/Postgres backing services, and observability (Grafana, Netdata, node-exporter). See `docs/DMF7-architecture.md` for the full layout and role of each component.

## Real Embeddings (Next Step)
Upgrade the placeholder embedding pipeline by installing Ollama and pulling the `nomic-embed-text` model:

```bash
bash scripts/install_real_embeddings.sh
```

Or run the commands directly:

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull nomic-embed-text
```

## Remaining Pieces to Complete the AI Node
- Vector database (Qdrant or pgvector)
- Retrieval API exposing vector search
- AI agents running as Redis worker reasoning jobs
