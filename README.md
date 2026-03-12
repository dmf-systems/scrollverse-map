# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 self-heal automation

Use `scripts/dmf7_self_heal_623_640.sh` to automate DMF7 steps 623-640 (watchdog service, Docker self-heal, AI test helper, and snapshot command). The script:
- Writes the required systemd unit files and reloads systemd
- Installs the Docker heal, AI test, and snapshot helpers, making them executable
- Enables/starts the watchdog and Docker heal services and runs best-effort status checks
- Runs the AI test if `ollama` is available and creates a snapshot under `/opt/dmf7/snapshots`

Run as root on the target host:

```bash
sudo bash scripts/dmf7_self_heal_623_640.sh
```
