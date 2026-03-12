# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 system automation

Use the included helper to provision monitoring and maintenance tooling (htop/iotop/iftop/ncdu), install DMF7 helpers, and configure cron jobs.

```bash
sudo bash scripts/dmf7_system_tools_setup.sh
```

The script writes helpers to `/usr/local/bin` (`dmf7-top`, `dmf7-clean`, `dmf7-alert`, `dmf7-summary`), primes the cleanup/alert cron tasks, and records the deployment status under `/opt/dmf7`. Running it will prune Docker artifacts and run system cleanup, so execute on the intended host only.
