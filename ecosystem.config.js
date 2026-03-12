module.exports = {
  apps: [
    {
      name: "dmf7-gateway",
      script: "pnpm",
      args: "run start --filter @dmf7/gateway",
      restart_delay: 5000,
      max_restarts: 10
    },
    {
      name: "dmf7-console",
      script: "pnpm",
      args: "run start --filter @dmf7/operator-console",
      restart_delay: 5000
    },
    {
      name: "dmf7-ingest",
      script: "pnpm",
      args: "run start --filter @dmf7/ingest",
      restart_delay: 5000
    },
    {
      name: "dmf7-retrieval",
      script: "pnpm",
      args: "run start --filter @dmf7/retrieval",
      restart_delay: 5000
    }
  ]
}
