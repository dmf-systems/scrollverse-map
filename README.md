# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 automation (steps 501-520)

Use the helper script to provision time sync and operational tools on a DMF7 node.

```bash
sudo bash scripts/dmf7_time_sync_tools_501_520.sh
```

This installs chrony, writes the `dmf7-*` helper binaries (time, storage, docker, snapshot, reset), runs the health checks, and prints the final status banner. Ensure you run it as root on the target host.
