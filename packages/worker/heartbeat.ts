type RedisLike = {
  set: (key: string, value: string, ...rest: any[]) => Promise<any>;
  pexpire?: (key: string, ttl: number) => Promise<any>;
  expire?: (key: string, ttlSeconds: number) => Promise<any>;
  del?: (key: string) => Promise<any>;
};

export type HeartbeatOptions = {
  redis: RedisLike;
  workerId: string;
  intervalMs?: number;
  ttlMs?: number;
  prefix?: string;
  onError?: (error: unknown) => void;
};

export type HeartbeatHandle = {
  key: string;
  stop: () => Promise<void>;
};

/**
 * Starts a simple heartbeat loop that renews a Redis key for the worker.
 * Returns a handle with the Redis key used and a stop() function to halt the heartbeat.
 */
export function startWorkerHeartbeat({
  redis,
  workerId,
  intervalMs = 5000,
  ttlMs = 15000,
  prefix = "dmf7:worker:",
  onError,
}: HeartbeatOptions): HeartbeatHandle {
  const key = `${prefix}${workerId}`;
  let stopped = false;

  const publishHeartbeat = async () => {
    if (stopped) return;

    try {
      // Use PX (ms) expiry when supported; fall back to expire/pexpire.
      await redis.set(key, Date.now().toString(), "PX", ttlMs);
    } catch (err) {
      onError?.(err);
      // If PX is unsupported, try setting without options then applying TTL.
      try {
        await redis.set(key, Date.now().toString());
        if (redis.pexpire) {
          await redis.pexpire(key, ttlMs);
        } else if (redis.expire) {
          await redis.expire(key, Math.ceil(ttlMs / 1000));
        }
      } catch (ttlErr) {
        onError?.(ttlErr);
      }
    }
  };

  // Fire immediately so the worker registers itself as soon as it starts.
  void publishHeartbeat();
  const timer = setInterval(() => void publishHeartbeat(), intervalMs);

  const stop = async () => {
    stopped = true;
    clearInterval(timer);
    try {
      await redis.del?.(key);
    } catch (err) {
      onError?.(err);
    }
  };

  return { key, stop };
}
