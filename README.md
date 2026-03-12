# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Cluster Setup (Steps 702-718)

Run the automation with root privileges:

```bash
sudo bash scripts/dmf7_cluster_setup_702_718.sh [--verify]
```

What it does:
- Creates `/opt/dmf7/cluster/nodes.json` with the primary node `72.61.114.167`
- Installs `jq` and `rsync` (apt-get)
- Installs helper commands: `dmf7-discover`, `dmf7-cluster-health`, `dmf7-cluster-sync`, and `dmf7-cluster`
- Optionally runs discovery, health, and status checks when `--verify` is provided

After installation, use `dmf7-cluster` for a quick cluster overview.
