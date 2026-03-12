export interface RateLimitConfig {
  requests: number;
  windowMs: number;
}

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: number;
}

export interface RateLimiter {
  check(key: string): RateLimitResult | Promise<RateLimitResult>;
}

type Bucket = {
  count: number;
  resetAt: number;
};

export type RateLimitContext = {
  userId?: string;
  ip?: string;
  scope?: "global" | "user" | "ip";
};

const defaultConfig = (): RateLimitConfig => {
  const requests = Number(process.env.RATE_LIMIT_REQUESTS ?? 100);
  const windowMs = Number(process.env.RATE_LIMIT_WINDOW ?? 60_000);
  return { requests: Number.isFinite(requests) ? requests : 100, windowMs: Number.isFinite(windowMs) ? windowMs : 60_000 };
};

export class InMemoryRateLimiter implements RateLimiter {
  private readonly buckets = new Map<string, Bucket>();
  private readonly config: RateLimitConfig;

  constructor(config: Partial<RateLimitConfig> = {}) {
    this.config = { ...defaultConfig(), ...config };
  }

  check(key: string): RateLimitResult {
    const now = Date.now();
    const bucket = this.buckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      const resetAt = now + this.config.windowMs;
      this.buckets.set(key, { count: 1, resetAt });
      return { allowed: true, remaining: this.config.requests - 1, resetAt };
    }

    const nextCount = bucket.count + 1;
    if (nextCount > this.config.requests) {
      return { allowed: false, remaining: 0, resetAt: bucket.resetAt };
    }

    bucket.count = nextCount;
    return { allowed: true, remaining: this.config.requests - nextCount, resetAt: bucket.resetAt };
  }
}

export const rateLimitKey = (ctx: RateLimitContext): string => {
  if (ctx.scope === "global") return "global";
  if (ctx.scope === "user" && ctx.userId) return `user:${ctx.userId}`;
  if (ctx.scope === "ip" && ctx.ip) return `ip:${ctx.ip}`;
  if (ctx.userId) return `user:${ctx.userId}`;
  if (ctx.ip) return `ip:${ctx.ip}`;
  return "global";
};

export const allowGlobal = (limiter: RateLimiter): RateLimitResult | Promise<RateLimitResult> => limiter.check("global");
export const allowUser = (limiter: RateLimiter, userId: string): RateLimitResult | Promise<RateLimitResult> =>
  limiter.check(rateLimitKey({ userId, scope: "user" }));
export const allowIp = (limiter: RateLimiter, ip: string): RateLimitResult | Promise<RateLimitResult> =>
  limiter.check(rateLimitKey({ ip, scope: "ip" }));

type GatewayRequest = {
  ip?: string;
  headers?: Record<string, string | string[] | undefined>;
  user?: { id?: string };
  connection?: { remoteAddress?: string };
};

type GatewayResponse = {
  statusCode?: number;
  setHeader?: (name: string, value: string) => void;
  end?: (body?: string) => void;
};

type NextFunction = () => void;

export const gatewayRateLimitMiddleware =
  (limiter: RateLimiter, scope: "global" | "user" | "ip" | "auto" = "auto") =>
  async (req: GatewayRequest, res: GatewayResponse, next: NextFunction): Promise<void> => {
    const ip = req.ip ?? req.connection?.remoteAddress ?? "unknown";
    const userId = req.user?.id ?? (typeof req.headers?.["x-user-id"] === "string" ? (req.headers["x-user-id"] as string) : undefined);
    const key = scope === "global" ? "global" : scope === "user" ? rateLimitKey({ userId, scope: "user" }) : scope === "ip" ? rateLimitKey({ ip, scope: "ip" }) : rateLimitKey({ userId, ip });

    const result = await limiter.check(key);
    if (!result.allowed) {
      if (res) {
        res.statusCode = 429;
        res.setHeader?.("Retry-After", Math.ceil((result.resetAt - Date.now()) / 1000).toString());
        res.end?.("Rate limit exceeded");
      }
      return;
    }
    next();
  };
