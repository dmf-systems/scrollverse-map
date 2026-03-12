import { createServer, IncomingMessage, ServerResponse } from "http";

type ConfigState = Record<string, unknown>;

class ConfigStore {
  private config: ConfigState;

  constructor(initial: ConfigState = {}) {
    this.config = { ...initial };
  }

  getAll(): ConfigState {
    return { ...this.config };
  }

  update(values: ConfigState): ConfigState {
    this.config = { ...this.config, ...values };
    return this.getAll();
  }
}

const readJson = async (req: IncomingMessage): Promise<unknown> =>
  new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req
      .on("data", (chunk) => chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)))
      .on("end", () => {
        if (chunks.length === 0) return resolve({});
        try {
          resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
        } catch (err) {
          reject(err);
        }
      })
      .on("error", reject);
  });

const defaultConfig = (): ConfigState => ({
  rateLimit: {
    requests: Number(process.env.RATE_LIMIT_REQUESTS ?? 100),
    windowMs: Number(process.env.RATE_LIMIT_WINDOW ?? 60_000),
  },
  scheduler: {
    registryKey: "dmf7:scheduler:jobs",
  },
});

export const startConfigServer = (port = Number(process.env.CONFIG_PORT ?? 4000)): void => {
  const store = new ConfigStore(defaultConfig());

  const server = createServer(async (req: IncomingMessage, res: ServerResponse) => {
    res.setHeader("Content-Type", "application/json");

    if (req.method === "GET" && req.url === "/config") {
      res.writeHead(200);
      res.end(JSON.stringify(store.getAll()));
      return;
    }

    if (req.method === "POST" && req.url === "/config/update") {
      try {
        const body = (await readJson(req)) as ConfigState;
        const updated = store.update(body);
        res.writeHead(200);
        res.end(JSON.stringify({ ok: true, config: updated }));
      } catch (err: any) {
        res.writeHead(400);
        res.end(JSON.stringify({ ok: false, error: err?.message ?? "Invalid JSON" }));
      }
      return;
    }

    res.writeHead(404);
    res.end(JSON.stringify({ ok: false, error: "Not found" }));
  });

  server.listen(port, () => {
    console.log(`[config-api] listening on ${port}`);
  });
};

if (require.main === module) {
  startConfigServer();
}
