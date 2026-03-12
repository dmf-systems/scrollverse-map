# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 node refresh (steps 1101-1115)

The helper script `scripts/dmf7_node_version_1101_1115.sh` applies the Node 20 requirement, rebuilds DMF7 with pnpm, refreshes PM2 and Docker services, installs the `dmf7-check` and `dmf7` helpers under `/usr/local/bin`, and prints the final node status banner.

Run it from this repository (nvm, pnpm, pm2, and docker must already be installed and able to write to `/usr/local/bin`):

```bash
DMF7_DIR="$HOME/DMF7" NVM_DIR="$HOME/.nvm" bash scripts/dmf7_node_version_1101_1115.sh
```
