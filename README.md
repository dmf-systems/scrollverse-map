# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Federation setup (steps 1040-1056)
Run the installer as root to provision the federation directories, helper tools, and cron worker:

```bash
sudo bash scripts/dmf7_global_federation_1040_1056.sh [--verify]
```

It will create `/opt/dmf7/federation` (nodes, jobs, results), seed `registry.txt` with `72.61.114.167`, install `dmf7-*` helpers into `/usr/local/bin`, add the worker cron at `/etc/cron.d/dmf7-federation-worker`, and print the final activation banner. Pass `--verify` to print `dmf7-federation-status` after installation.
