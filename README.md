# scrollverse-map / DMF7 Platform v1.4

A consolidated toolkit containing rate limiting, secrets management, vector optimization, graph integrity checks, configuration APIs, distributed scheduling, query planning, agent skill loading, and deployment validation.

## Getting started

```bash
npm install
npm test          # type-checks the TypeScript code
```

## Commands

- `npm run optimize-vectors` — compact Qdrant vectors, drop stale entries, trigger optimization.
- `npm run graph-check` — validate Neo4j graph health (orphan nodes, missing edges).
- `npm run deploy-check` — validate env vars, health endpoints, and port availability.
- `npm run config-api` — start the configuration API (`GET /config`, `POST /config/update`).
- `npm run scheduler` — run the distributed scheduler with Redis-friendly locks.

## Key modules

- **Rate limiter** (`packages/rate-limit`) — in-memory and Redis-aware global/user/IP throttling, gateway middleware helper. Env: `RATE_LIMIT_REQUESTS`, `RATE_LIMIT_WINDOW`.
- **Secrets manager** (`packages/secrets`) — loads `.env`, handles encrypted vault storage, runtime retrieval. Env: `SECRETS_MASTER_KEY`, `SECRETS_VAULT_FILE`, `SECRETS_ENV_FILE`.
- **Vector optimizer** (`packages/vector-optimizer`) — compacts embeddings and prunes stale vectors; includes Qdrant-style helpers.
- **Graph integrity** (`packages/graph-integrity`) — detects orphan nodes and missing edges; supports repair hooks.
- **System config API** (`services/config/server.ts`) — lightweight HTTP server for live config inspection/updates.
- **Distributed scheduler** (`services/distributed-scheduler`) — cron-like job runner with retry handling and Redis lock keys (`dmf7:scheduler:jobs`).
- **Query planner** (`packages/query-planner`) — chooses between vector, graph, or hybrid strategies plus optimizer defaults.
- **Agent skills** (`packages/agent-skills`) — skill registry/loader with sample skills (document-analysis, vector-search, knowledge-linking).
- **Deployment validator** (`scripts/deployment-validator.ts`) — checks env, health endpoints, and port availability.

## Environment variables

- `RATE_LIMIT_REQUESTS` / `RATE_LIMIT_WINDOW` — throttling limits (defaults: 100 requests per 60s).
- `SECRETS_MASTER_KEY` — required to encrypt/decrypt vault secrets.
- `CONFIG_PORT` — port for the configuration API (default 4000).
- `SCHEDULER_POLL_INTERVAL` — optional scheduler polling override in ms.
- `VALIDATE_PORTS` — comma-separated ports to probe (default `80,443`).
- `HEALTH_ENDPOINTS` — comma-separated URLs for deployment validation.
