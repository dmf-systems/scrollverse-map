import fs from "fs";
import path from "path";
import dotenv from "dotenv";

export type RedisConfig = {
  url?: string;
  host?: string;
  port?: number;
  username?: string;
  password?: string;
  tls?: boolean;
};

export type QdrantConfig = {
  url?: string;
  apiKey?: string;
  collection?: string;
};

export type Neo4jConfig = {
  url?: string;
  username?: string;
  password?: string;
};

export type OllamaConfig = {
  url?: string;
  model?: string;
};

export type GatewayConfig = {
  url?: string;
  port?: number;
  apiKey?: string;
};

export type AuthConfig = {
  issuer?: string;
  audience?: string;
  jwtSecret?: string;
};

export type LimitsConfig = {
  maxConcurrentJobs?: number;
  maxTokens?: number;
  requestTimeoutMs?: number;
};

export type Config = {
  redis: RedisConfig;
  qdrant: QdrantConfig;
  neo4j: Neo4jConfig;
  ollama: OllamaConfig;
  gateway: GatewayConfig;
  auth: AuthConfig;
  limits: LimitsConfig;
};

const defaultEnvFiles = [".env", ".env.production", ".env.local"];

const truthy = new Set(["1", "true", "yes", "on"]);
const falsy = new Set(["0", "false", "no", "off"]);

function toNumber(value: string | undefined): number | undefined {
  if (value === undefined || value.trim() === "") return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function toBoolean(value: string | undefined): boolean | undefined {
  if (value === undefined) return undefined;
  const normalized = value.trim().toLowerCase();
  if (truthy.has(normalized)) return true;
  if (falsy.has(normalized)) return false;
  return undefined;
}

function loadEnvFiles(baseDir: string, files: string[]): void {
  files.forEach((file) => {
    const fullPath = path.resolve(baseDir, file);
    if (fs.existsSync(fullPath)) {
      dotenv.config({ path: fullPath, override: true });
    }
  });
}

export function buildConfig(baseDir = process.cwd()): Config {
  loadEnvFiles(baseDir, defaultEnvFiles);

  const redis: RedisConfig = {};
  if (process.env.REDIS_URL) redis.url = process.env.REDIS_URL;
  if (process.env.REDIS_HOST) redis.host = process.env.REDIS_HOST;
  const redisPort = toNumber(process.env.REDIS_PORT);
  if (redisPort !== undefined) redis.port = redisPort;
  if (process.env.REDIS_USERNAME) redis.username = process.env.REDIS_USERNAME;
  if (process.env.REDIS_PASSWORD) redis.password = process.env.REDIS_PASSWORD;
  const redisTls = toBoolean(process.env.REDIS_TLS);
  if (redisTls !== undefined) redis.tls = redisTls;

  const qdrant: QdrantConfig = {};
  if (process.env.QDRANT_URL) qdrant.url = process.env.QDRANT_URL;
  if (process.env.QDRANT_API_KEY) qdrant.apiKey = process.env.QDRANT_API_KEY;
  if (process.env.QDRANT_COLLECTION) qdrant.collection = process.env.QDRANT_COLLECTION;

  const neo4j: Neo4jConfig = {};
  if (process.env.NEO4J_URL) neo4j.url = process.env.NEO4J_URL;
  if (process.env.NEO4J_USERNAME) neo4j.username = process.env.NEO4J_USERNAME;
  if (process.env.NEO4J_PASSWORD) neo4j.password = process.env.NEO4J_PASSWORD;

  const ollama: OllamaConfig = {};
  if (process.env.OLLAMA_URL) ollama.url = process.env.OLLAMA_URL;
  if (process.env.OLLAMA_MODEL) ollama.model = process.env.OLLAMA_MODEL;

  const gateway: GatewayConfig = {};
  if (process.env.GATEWAY_URL) gateway.url = process.env.GATEWAY_URL;
  const gatewayPort = toNumber(process.env.GATEWAY_PORT);
  if (gatewayPort !== undefined) gateway.port = gatewayPort;
  if (process.env.GATEWAY_API_KEY) gateway.apiKey = process.env.GATEWAY_API_KEY;

  const auth: AuthConfig = {};
  if (process.env.AUTH_ISSUER) auth.issuer = process.env.AUTH_ISSUER;
  if (process.env.AUTH_AUDIENCE) auth.audience = process.env.AUTH_AUDIENCE;
  if (process.env.AUTH_JWT_SECRET) auth.jwtSecret = process.env.AUTH_JWT_SECRET;

  const limits: LimitsConfig = {};
  const maxConcurrentJobs = toNumber(process.env.LIMITS_MAX_CONCURRENT_JOBS);
  if (maxConcurrentJobs !== undefined) limits.maxConcurrentJobs = maxConcurrentJobs;
  const maxTokens = toNumber(process.env.LIMITS_MAX_TOKENS);
  if (maxTokens !== undefined) limits.maxTokens = maxTokens;
  const requestTimeoutMs = toNumber(process.env.LIMITS_REQUEST_TIMEOUT_MS);
  if (requestTimeoutMs !== undefined) limits.requestTimeoutMs = requestTimeoutMs;

  return { redis, qdrant, neo4j, ollama, gateway, auth, limits };
}

export const config: Config = buildConfig();
