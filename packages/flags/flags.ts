export type FeatureFlag =
  | "agent_execution"
  | "graph_reasoning"
  | "continuous_ingestion"
  | "autoscaling_workers"
  | "experimental_models";

export type FeatureFlags = Record<FeatureFlag, boolean>;

export type RedisClientLike = {
  get(key: string): Promise<string | null>;
};

export type FeatureFlagOptions = {
  redisClient?: RedisClientLike;
  envPrefix?: string;
  redisPrefix?: string;
  defaults?: Partial<FeatureFlags>;
};

const defaultEnvPrefix = "FEATURE_";
const defaultRedisPrefix = "feature:";

const defaultFlags: FeatureFlags = {
  agent_execution: false,
  graph_reasoning: false,
  continuous_ingestion: false,
  autoscaling_workers: false,
  experimental_models: false,
};

const truthy = new Set(["1", "true", "yes", "on"]);
const falsy = new Set(["0", "false", "no", "off"]);

function parseBoolean(value: string | null | undefined): boolean | undefined {
  if (value === null || value === undefined) return undefined;
  const normalized = value.trim().toLowerCase();
  if (truthy.has(normalized)) return true;
  if (falsy.has(normalized)) return false;
  return undefined;
}

function envKey(flag: FeatureFlag, prefix: string): string {
  return `${prefix}${flag}`.toUpperCase();
}

function redisKey(flag: FeatureFlag, prefix: string): string {
  return `${prefix}${flag}`;
}

async function flagFromRedis(
  flag: FeatureFlag,
  client: RedisClientLike,
  prefix: string,
): Promise<boolean | undefined> {
  const value = await client.get(redisKey(flag, prefix));
  return parseBoolean(value);
}

function flagFromEnv(flag: FeatureFlag, prefix: string): boolean | undefined {
  const value = process.env[envKey(flag, prefix)];
  return parseBoolean(value);
}

export class FeatureFlagService {
  private readonly redisClient: RedisClientLike | undefined;
  private readonly envPrefix: string;
  private readonly redisPrefix: string;
  private readonly defaults: FeatureFlags;

  constructor(options: FeatureFlagOptions = {}) {
    this.redisClient = options.redisClient;
    this.envPrefix = options.envPrefix ?? defaultEnvPrefix;
    this.redisPrefix = options.redisPrefix ?? defaultRedisPrefix;
    this.defaults = { ...defaultFlags, ...(options.defaults ?? {}) };
  }

  async isEnabled(flag: FeatureFlag): Promise<boolean> {
    const envValue = flagFromEnv(flag, this.envPrefix);
    if (envValue !== undefined) return envValue;

    if (this.redisClient) {
      const redisValue = await flagFromRedis(
        flag,
        this.redisClient,
        this.redisPrefix,
      );
      if (redisValue !== undefined) return redisValue;
    }

    return this.defaults[flag];
  }

  async all(): Promise<FeatureFlags> {
    const entries = await Promise.all(
      (Object.keys(defaultFlags) as FeatureFlag[]).map(async (flag) => [
        flag,
        await this.isEnabled(flag),
      ]),
    );

    return Object.fromEntries(entries) as FeatureFlags;
  }
}

export async function resolveFeatureFlags(
  options: FeatureFlagOptions = {},
): Promise<FeatureFlags> {
  const service = new FeatureFlagService(options);
  return service.all();
}
