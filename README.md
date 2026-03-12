# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 development setup

A helper script now provisions a full DMF7 development environment:

- Ensures Node.js/npm, pnpm, pm2, Docker
- Installs global tooling: typescript, ts-node, nodemon, eslint, prettier, turbo
- Installs GitHub CLI if missing
- Installs helpers: `dmf7-dev` (runs `pnpm install && pnpm dev`, falls back to npm) and `dmf7-health` (pm2 status + docker ps)

Run on your server:

```bash
cd ~/DMF7
git pull
chmod +x scripts/setup-dev-env.sh
./scripts/setup-dev-env.sh

dmf7-health
dmf7-dev
```

Next step for real embeddings (optional):

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull nomic-embed-text
```
