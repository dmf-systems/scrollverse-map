# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 infrastructure verification (steps 131–150)

Run `scripts/dmf7_infrastructure_verification.sh` on the DMF7 host to perform the full checklist (toolkit install, dashboard creation, benchmarks, service checks, and final summary).

Prerequisites:
- Root/sudo access (writes `/usr/local/bin/dmf7-dashboard`, installs apt packages).
- Network access for `apt` and the service health curls.
- Docker/PM2/Node tooling available on `PATH` for their checks.

Usage:
```bash
bash scripts/dmf7_infrastructure_verification.sh
```

Optional environment overrides:
- `DMF7_CPU_THREADS` – CPU threads for sysbench CPU test (default: 4).
- `DMF7_FILEIO_SIZE` – file size for sysbench fileio (default: 1G).
- `DMF7_FILEIO_DIR` – working directory for sysbench fileio (default: `/tmp/dmf7-sysbench-fileio`).
