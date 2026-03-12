# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 stack helpers
Run `sudo bash scripts/dmf7_stack_tools.sh` to install global helpers for operating the DMF7 node. The script creates:
- `/usr/local/bin/dmf7-status` for uptime, memory, disk, PM2, and Docker status
- `/usr/local/bin/dmf7-start` to start Docker containers and resurrect PM2
- `/usr/local/bin/dmf7-stop` to stop PM2 and running containers
- `/usr/local/bin/dmf7-logs` to tail PM2 logs
- `/usr/local/bin/dmf7-check` to curl key local endpoints

By default it runs the status and health checks and performs `pm2 startup`/`pm2 save` (best effort). Use `--skip-verify` or `--skip-pm2-startup` to bypass those steps if you need a quiet install.
