# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 platform deployment (steps 211-226)
- Run `bash scripts/dmf7_platform_deployment.sh` to automate steps 211-226: install/auth GitHub CLI, create `/opt/dmf7` dirs, move `~/DMF7` to `/opt/dmf7/platform`, create `/usr/local/bin/dmf7-update`, add the nightly cron job, write `VERSION`, and print the status banner.
- The script expects sudo privileges for system changes and requires pnpm/pm2 available for the update helper. GitHub authentication uses the browser-based `gh auth login --web` flow.
