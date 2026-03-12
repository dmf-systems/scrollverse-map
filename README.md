# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 control and diagnostics
Provision the DMF7 watch/health/test utilities on a host:

```bash
sudo bash scripts/dmf7_system_resource_watcher.sh
```

The script installs the following commands under `/usr/local/bin`:
- `dmf7` (menu-driven control center)
- `dmf7-watch` (live resource view)
- `dmf7-health` (gateway/console/AI/vector/graph checks)
- `dmf7-ai-test` (LLM smoke test against localhost:11435)
- `dmf7-vector-test` (Qdrant collections check)
- `dmf7-graph-test` (Neo4j reachability check)

It also writes `/opt/dmf7/DEPLOY_LOG` and prints the deployment banner. Run the helpers manually after installation to verify each service in your environment.
