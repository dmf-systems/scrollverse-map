import { ScheduleRegistry, ScheduledJob } from "./schedule-registry";

export interface RedisLockClient {
  set?(key: string, value: string, mode?: string, duration?: number): Promise<unknown>;
  setnx?(key: string, value: string): Promise<number>;
  expire?(key: string, ttlSeconds: number): Promise<unknown>;
  del?(key: string): Promise<unknown>;
}

type SchedulerOptions = {
  lockKeyPrefix?: string;
  pollingIntervalMs?: number;
};

export class DistributedScheduler {
  private readonly registry: ScheduleRegistry;
  private readonly redis?: RedisLockClient;
  private readonly options: Required<SchedulerOptions>;
  private timer?: NodeJS.Timeout;
  private readonly lastRun = new Map<string, number>();
  private readonly attempts = new Map<string, number>();

  constructor(registry = new ScheduleRegistry(), redis?: RedisLockClient, options: SchedulerOptions = {}) {
    this.registry = registry;
    this.redis = redis;
    const pollingFromEnv = Number(process.env.SCHEDULER_POLL_INTERVAL ?? 5_000);
    this.options = {
      lockKeyPrefix: "dmf7:scheduler:jobs",
      pollingIntervalMs: Number.isFinite(options.pollingIntervalMs) ? options.pollingIntervalMs! : Number.isFinite(pollingFromEnv) ? pollingFromEnv : 5_000,
      ...options,
    };
  }

  start(): void {
    if (this.timer) return;
    this.timer = setInterval(() => void this.tick(), this.options.pollingIntervalMs);
    // immediate tick for fast startup
    void this.tick();
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = undefined;
  }

  private cronToIntervalMs(cron: string): number {
    const parts = cron.trim().split(/\s+/);
    // Very small parser supporting minute-level specs: "* * * * *" or "*/5 * * * *" or "0 * * * *"
    const minutePart = parts[0] ?? "*";
    if (minutePart.startsWith("*/")) {
      const every = Number(minutePart.replace("*/", ""));
      return Math.max(every, 1) * 60 * 1000;
    }
    if (minutePart === "*") return 60 * 1000;
    const minuteNumber = Number(minutePart);
    if (Number.isFinite(minuteNumber)) {
      const now = new Date();
      const currentMinute = now.getMinutes();
      const delta = (minuteNumber - currentMinute + 60) % 60 || 60;
      return delta * 60 * 1000;
    }
    return 60 * 1000;
  }

  private async lock(job: ScheduledJob): Promise<boolean> {
    const key = `${this.options.lockKeyPrefix}:${job.id}`;
    if (this.redis?.setnx) {
      const result = await this.redis.setnx(key, Date.now().toString());
      if (result === 1) {
        await this.redis.expire?.(key, Math.ceil(this.cronToIntervalMs(job.cron) / 1000));
        return true;
      }
      return false;
    }
    // fallback in-memory lock
    const last = this.lastRun.get(key) ?? 0;
    const now = Date.now();
    if (now - last > this.cronToIntervalMs(job.cron)) {
      this.lastRun.set(key, now);
      return true;
    }
    return false;
  }

  private async tick(): Promise<void> {
    for (const job of this.registry.list()) {
      if (!(await this.lock(job))) continue;
      const last = this.lastRun.get(job.id) ?? 0;
      if (Date.now() - last < this.cronToIntervalMs(job.cron)) continue;
      await this.runJob(job);
    }
  }

  private async runJob(job: ScheduledJob): Promise<void> {
    try {
      await job.task();
      this.lastRun.set(job.id, Date.now());
      this.attempts.delete(job.id);
    } catch (err) {
      const attempts = (this.attempts.get(job.id) ?? 0) + 1;
      this.attempts.set(job.id, attempts);
      const limit = job.retryLimit ?? 3;
      if (attempts <= limit) {
        // simple retry after one interval
        setTimeout(() => void this.runJob(job), this.cronToIntervalMs(job.cron));
      } else {
        // give up after limit
        console.error(`[scheduler] job ${job.id} failed after ${attempts} attempts`, err);
      }
    }
  }
}

if (require.main === module) {
  const registry = new ScheduleRegistry();
  registry.register({
    id: "heartbeat",
    cron: "*/1 * * * *",
    task: () => console.log("[scheduler] heartbeat"),
  });

  const scheduler = new DistributedScheduler(registry);
  scheduler.start();
  console.log("[scheduler] started");
}
