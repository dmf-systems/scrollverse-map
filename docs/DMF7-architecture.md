# DMF7 Architecture Overview

## System Map
- Users and APIs reach the DMF7 Gateway (API orchestrator) on :4000 and the Console on :4100.
- Task pipeline runs a Redis queue with worker runtimes handling async jobs.
- Data pipeline includes bulk ingest scripts and an embedding generator under `/tools`, persisting to vector storage at `/opt/dmf7/data` (placeholder).
- Future AI runtime layers Ollama embeddings and vector search on top of the stored vectors.
- System infrastructure: Docker containers, PM2 services, Node.js 20 runtime, pnpm workspace, Redis, Postgres.
- Observability stack: Grafana (:3000), Netdata (:19999), node-exporter (:9100).
- Dev automation helpers: `scripts/setup-dev-env.sh`, `dmf7-dev`, `dmf7-health`.

## Current Capabilities
- Compute layer: Node runtime, Docker orchestration, PM2 service management.
- AI pipeline: ingestion scripts, embedding generator, async worker queue, Redis task runtime.
- Infrastructure: gateway, console, and supporting microservices.
- Observability: Grafana dashboards, Netdata metrics, node-exporter telemetry.
- Dev automation: environment bootstrap, health commands, service control.

## Missing Pieces to Finalize the AI Node
1. **Real embeddings** via Ollama `nomic-embed-text`.
2. **Vector database** such as Qdrant or pgvector.
3. **Retrieval API** that exposes vector search endpoints.
4. **AI agents** using Redis workers to run reasoning jobs.

## Immediate Next Step (Most Important)
Run the real embedding install to swap the placeholder pipeline for a semantic engine:

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull nomic-embed-text
```

Ensure you have privileges to install system packages (use `sudo` when required) and confirm the `ollama` service is active after installation.
