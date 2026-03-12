# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 System Telemetry Setup

Run the automation script as root to install sensor tools, provision the hardware status helper, and add the AI model pull wrapper:

```bash
sudo bash scripts/dmf7_system_telemetry_tools.sh
```

After running, use `dmf7-hardware` to view CPU, temperature, disk health, and memory info. Use `dmf7-pull-model <model>` to wrap `ollama pull` for fetching local models (requires Ollama to be installed separately).
