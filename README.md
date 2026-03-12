# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 automation
Run `scripts/dmf7_autoreload_watchdog_setup.sh` as root to automate DMF7 steps 465-483. It installs `inotify-tools`, writes `/usr/local/bin` helpers (`dmf7-autoreload`, `dmf7-watchdog`, `dmf7-pull`, `dmf7-maintenance`), starts the autoreload watcher, schedules the watchdog cron, runs the pull and maintenance commands once, records `/opt/dmf7/DEPLOY_LOG`, and prints the final status banner. The script assumes the DMF7 platform lives at `/opt/dmf7/platform` with `pnpm`, `pm2`, Docker, and the `dmf7-*` helper commands available.
