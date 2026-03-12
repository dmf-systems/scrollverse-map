# scrollverse-map

A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Production Finalization (Steps 81-97)

Use `scripts/dmf7_production_finalize.sh` to automate the remaining DMF7 setup steps:

- Installs GitHub CLI, verifies authentication, and prepares the `production-node` branch.
- Installs `/usr/local/bin/dmf7-git-sync` and sets a 10-minute cron that logs to `/opt/dmf7/logs/git-sync.log`.
- Installs `/usr/local/bin/dmf7-health`, runs service health checks, verifies Netdata/Portainer endpoints, runs backup/status, and prints the final announcement banner.

### Run

```
sudo bash scripts/dmf7_production_finalize.sh
```

Environment variables:
- `DMF7_DIR` (optional): path to the DMF7 git repo (default: `/root/DMF7`).

If GitHub CLI is not authenticated, run `gh auth login --hostname github.com --web --git-protocol https` before rerunning.
