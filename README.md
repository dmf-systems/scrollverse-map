# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## Global configuration
`packages/config/config.ts` loads `.env`, `.env.production`, and `.env.local` (later files override earlier ones) and exposes a typed `config` object covering Redis, Qdrant, Neo4j, Ollama, gateway, auth, and limit settings.

## Feature flags
`packages/flags/flags.ts` provides a `FeatureFlagService` that reads flags from environment variables (`FEATURE_*`) with optional Redis-backed overrides. Supported flags: `agent_execution`, `graph_reasoning`, `continuous_ingestion`, `autoscaling_workers`, and `experimental_models`.

## Backup and restore
- `packages/backup/index.ts` can back up Redis, Neo4j, Qdrant snapshots, and documents into `/data/backups` (default) and schedule daily runs.
- `packages/restore/index.ts` restores those snapshots; the CLI `dmf7 restore` accepts `--backup-dir`, `--backup-root`, `--documents`, and `--wipe-neo4j`.

Build the project with `npm run build` before using the generated CLI at `dist/packages/restore/cli.js`.
