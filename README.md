# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Orchestrator (steps 689-701)

A provisioning helper is provided to install the DMF7 orchestrator service, supporting tooling, and banners described in steps 689-701.

Run as root:

```bash
chmod +x scripts/dmf7_orchestrator_setup_689_701.sh
sudo scripts/dmf7_orchestrator_setup_689_701.sh
```

The script writes the orchestrator and summary binaries, installs the systemd unit, reloads/enables/starts the service, updates `/opt/dmf7/VERSION`, and refreshes `/etc/motd`.
