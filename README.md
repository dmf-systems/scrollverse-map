# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 platform automation (steps 641-657)
Use the provisioning script to set up the DMF7 log viewer, backup timer, benchmark, diagnostics, and AI stress tools.

```
sudo bash scripts/dmf7_platform_tools_641_657.sh
```

Add `--verify` to run the created commands (`dmf7-logs`, `systemctl list-timers | grep dmf7`, `dmf7-benchmark`, `dmf7-diagnose`, `dmf7-ai-bench`). Verification triggers CPU, disk, and AI workloads; run only when ready for the load. The script installs binaries in `/usr/local/bin` and systemd units under `/etc/systemd/system`.
