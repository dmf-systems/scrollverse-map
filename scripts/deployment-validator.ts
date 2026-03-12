import { request as httpRequest } from "http";
import { request as httpsRequest } from "https";
import net from "net";

type CheckResult = { name: string; ok: boolean; details?: string };

const checkEnv = (required: string[]): CheckResult => {
  const missing = required.filter((key) => !process.env[key]);
  return { name: "environment variables", ok: missing.length === 0, details: missing.length ? `Missing: ${missing.join(", ")}` : "all present" };
};

const checkPort = (host: string, port: number): Promise<CheckResult> =>
  new Promise((resolve) => {
    const socket = net.connect({ host, port });
    socket
      .on("connect", () => {
        socket.destroy();
        resolve({ name: `port ${host}:${port}`, ok: true });
      })
      .on("error", (err) => {
        resolve({ name: `port ${host}:${port}`, ok: false, details: err.message });
      });
  });

const checkHealthEndpoint = (url: string): Promise<CheckResult> =>
  new Promise((resolve) => {
    const handler = url.startsWith("https") ? httpsRequest : httpRequest;
    const req = handler(url, (res) => {
      const ok = res.statusCode ? res.statusCode >= 200 && res.statusCode < 300 : false;
      resolve({ name: `health ${url}`, ok, details: `status ${res.statusCode}` });
    });
    req.on("error", (err) => resolve({ name: `health ${url}`, ok: false, details: err.message }));
    req.end();
  });

const run = async (): Promise<void> => {
  const results: CheckResult[] = [];
  results.push(
    checkEnv([
      "RATE_LIMIT_REQUESTS",
      "RATE_LIMIT_WINDOW",
      "SECRETS_MASTER_KEY",
      "CONFIG_PORT",
      "SCHEDULER_POLL_INTERVAL",
    ])
  );

  const ports = (process.env.VALIDATE_PORTS ?? "80,443").split(",").map((p) => Number(p.trim())).filter(Number.isFinite);
  for (const port of ports) {
    results.push(await checkPort("127.0.0.1", port));
  }

  const healthUrls = (process.env.HEALTH_ENDPOINTS ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  for (const url of healthUrls) {
    results.push(await checkHealthEndpoint(url));
  }

  const failures = results.filter((r) => !r.ok);
  results.forEach((r) => console.log(`${r.ok ? "✅" : "❌"} ${r.name}${r.details ? ` - ${r.details}` : ""}`));

  if (failures.length > 0) {
    console.error(`Deployment validation failed: ${failures.length} checks failing`);
    process.exitCode = 1;
  } else {
    console.log("Deployment validation passed");
  }
};

if (require.main === module) {
  run().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
