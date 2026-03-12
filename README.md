# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 full system audit

Run `scripts/dmf7_full_system_audit.sh` to install the `dmf7-audit` and `dmf7-clean` helpers, schedule nightly log cleanup, and execute verification steps (services, ports, Docker/PM2, DMF7 checks, databases, Redis, and health). The script finishes by printing the production endpoint summary. Root or sudo privileges are required because it writes to `/usr/local/bin` and updates cron.
