# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 system metrics automation

Run the helper script to install Prometheus Node Exporter, add the `dmf7-metrics` and `dmf7-node` helpers, and perform the DMF7 verification steps (337-355):

```bash
sudo bash scripts/dmf7_metrics_exporter_setup.sh
```

The script:
- Installs and enables `prometheus-node-exporter`, then checks `http://localhost:9100/metrics`.
- Installs `/usr/local/bin/dmf7-metrics` and `/usr/local/bin/dmf7-node`.
- Runs health checks for the API, Redis, Qdrant, Neo4j, and Ollama endpoints.
- Writes the deploy log to `/opt/dmf7/DEPLOY_LOG` and prints the final DMF7 banner.
