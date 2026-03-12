import { RateLimitConfig, RateLimitResult, RateLimiter } from "./rate-limit";

export interface RedisLike {
  incr(key: string): Promise<number>;
  pttl(key: string): Promise<number>;
  expire(key: string, ttlSeconds: number): Promise<number | void>;
}

const configFromEnv = (override: Partial<RateLimitConfig> = {}): RateLimitConfig => {
  const requests = Number(process.env.RATE_LIMIT_REQUESTS ?? 100);
  const windowMs = Number(process.env.RATE_LIMIT_WINDOW ?? 60_000);
  return { requests: Number.isFinite(requests) ? requests : 100, windowMs: Number.isFinite(windowMs) ? windowMs : 60_000, ...override };
};

export class RedisRateLimiter implements RateLimiter {
  private readonly config: RateLimitConfig;
  private readonly prefix: string;

  constructor(private readonly redis: RedisLike, config: Partial<RateLimitConfig> = {}, prefix = "dmf7:rate-limit") {
    this.config = { ...configFromEnv(), ...config };
    this.prefix = prefix.endsWith(":") ? prefix : `${prefix}:`;
  }

  private keyFor(bucket: string): string {
    return `${this.prefix}${bucket}`;
  }

  async checkAsync(key: string): Promise<RateLimitResult> {
    const bucketKey = this.keyFor(key);
    const count = await this.redis.incr(bucketKey);
    let ttl = await this.redis.pttl(bucketKey);

    if (ttl < 0) {
      ttl = this.config.windowMs;
      await this.redis.expire(bucketKey, Math.ceil(ttl / 1000));
    }

    const resetAt = Date.now() + ttl;
    if (count > this.config.requests) {
      return { allowed: false, remaining: 0, resetAt };
    }

    return { allowed: true, remaining: this.config.requests - count, resetAt };
  }

  check(key: string): Promise<RateLimitResult> {
    return this.checkAsync(key);
  }
}
