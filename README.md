# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 GitHub sync automation (steps 856-870)
Use `scripts/dmf7_github_sync_856_870.sh` to provision the DMF7 GitHub/CI pipeline steps outlined in the runbook.

**Usage**
- Run as root: `sudo bash scripts/dmf7_github_sync_856_870.sh [--verify]`
- Optional env vars:
  - `DMF7_DIR` (default `~/DMF7`) to point at the DMF7 repo clone.
  - `GITHUB_TOKEN` to allow non-interactive `gh auth login`; otherwise you will be prompted to authenticate manually later.
- Add `--verify` to execute the generated `dmf7-sync` and `dmf7-copilot` helpers once after installation.

**What it does**
- Installs GitHub CLI, jq, pnpm, and turbo.
- Ensures GitHub CLI authentication (manual or via `GITHUB_TOKEN`).
- Pulls the latest `main` from the DMF7 repository.
- Creates `/usr/local/bin/dmf7-sync` and `/usr/local/bin/dmf7-copilot`.
- Adds a cron entry to run `dmf7-sync` every 30 minutes, logging to `/opt/dmf7/sync.log`.
