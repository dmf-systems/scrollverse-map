# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Global Control (Steps 673-688)

A helper installer is provided to create the DMF7 global control center, queue test, cleanup timer/service, node ID, and activation banner.

```bash
sudo bash scripts/dmf7_global_control_setup_673_688.sh [--verify]
```

- Without flags it provisions the scripts and systemd units, then prints the activation banner.
- `--verify` runs a quick control menu check (auto-selects 0 to exit), attempts the queue test if `ollama` is present, lists the cleanup timer, and prints node info.
