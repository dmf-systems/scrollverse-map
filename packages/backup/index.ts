import fs from "fs/promises";
import path from "path";
import cron from "node-cron";

export type RedisBackupClient = {
  scan(cursor: string, ...args: Array<string | number>): Promise<[string, string[]]>;
  dump(key: string): Promise<Buffer | null>;
  pttl?(key: string): Promise<number>;
};

export type RedisRestoreClient = RedisBackupClient & {
  restore?(key: string, ttl: number, value: Buffer, mode?: string): Promise<void>;
  set?(key: string, value: string): Promise<void>;
};

export type Neo4jSessionLike = {
  run: (
    query: string,
    params?: Record<string, unknown>,
  ) => Promise<{
    records: Array<{ get: (key: string) => any }>;
  }>;
  close?: () => Promise<void> | void;
};

export type Neo4jDriverLike = {
  session: () => Neo4jSessionLike;
};

export type QdrantClientLike = {
  createFullSnapshot?: () => Promise<{ result?: { name?: string; path?: string } }>;
  createSnapshot?: (collection?: string) => Promise<{ result?: { name?: string; path?: string } }>;
};

export type BackupOptions = {
  backupRoot?: string;
  redisClient?: RedisBackupClient;
  neo4jDriver?: Neo4jDriverLike;
  qdrantClient?: QdrantClientLike;
  qdrantCollection?: string;
  documentsPath?: string;
};

export type BackupPaths = {
  root: string;
  redis?: string;
  neo4j?: string;
  qdrant?: string;
  documents?: string;
};

export type BackupResult = {
  timestamp: string;
  paths: BackupPaths;
  errors: string[];
  skipped: string[];
};

export const BACKUP_FILE_NAMES = {
  redis: "redis.json",
  neo4j: "neo4j.json",
  qdrant: "qdrant.json",
  documents: "documents",
} as const;

async function ensureDir(dir: string): Promise<void> {
  await fs.mkdir(dir, { recursive: true });
}

async function createTimestampedDir(root: string): Promise<{ timestamp: string; dir: string }> {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const dir = path.join(root, timestamp);
  await ensureDir(dir);
  return { timestamp, dir };
}

async function backupRedis(
  client: RedisBackupClient,
  outFile: string,
): Promise<void> {
  let cursor = "0";
  const entries: Array<{ key: string; value: string | null; ttl: number }> = [];

  do {
    const [nextCursor, keys] = await client.scan(cursor, "MATCH", "*", "COUNT", 500);
    cursor = nextCursor;

    for (const key of keys) {
      const value = await client.dump(key);
      const ttl = client.pttl ? await client.pttl(key) : -1;
      entries.push({
        key,
        value: value ? value.toString("base64") : null,
        ttl: typeof ttl === "number" ? ttl : -1,
      });
    }
  } while (cursor !== "0");

  const payload = {
    generatedAt: new Date().toISOString(),
    entries,
  };

  await fs.writeFile(outFile, JSON.stringify(payload, null, 2), "utf-8");
}

async function backupNeo4j(driver: Neo4jDriverLike, outFile: string): Promise<void> {
  const session = driver.session();

  try {
    const nodesResult = await session.run(
      "MATCH (n) RETURN id(n) as id, labels(n) as labels, properties(n) as properties",
    );
    const relationshipsResult = await session.run(
      "MATCH (a)-[r]->(b) RETURN id(r) as id, id(a) as startId, id(b) as endId, type(r) as type, properties(r) as properties",
    );

    const payload = {
      generatedAt: new Date().toISOString(),
      nodes: nodesResult.records.map((record) => ({
        id: record.get("id"),
        labels: record.get("labels"),
        properties: record.get("properties"),
      })),
      relationships: relationshipsResult.records.map((record) => ({
        id: record.get("id"),
        startId: record.get("startId"),
        endId: record.get("endId"),
        type: record.get("type"),
        properties: record.get("properties"),
      })),
    };

    await fs.writeFile(outFile, JSON.stringify(payload, null, 2), "utf-8");
  } finally {
    await session.close?.();
  }
}

async function backupQdrant(
  client: QdrantClientLike,
  outFile: string,
  collection?: string,
): Promise<void> {
  const snapshot =
    collection && client.createSnapshot
      ? await client.createSnapshot(collection)
      : client.createFullSnapshot
        ? await client.createFullSnapshot()
        : undefined;

  const payload = {
    generatedAt: new Date().toISOString(),
    snapshot,
    collection,
  };

  await fs.writeFile(outFile, JSON.stringify(payload, null, 2), "utf-8");
}

async function backupDocuments(source: string, destination: string): Promise<void> {
  await ensureDir(path.dirname(destination));
  await fs.cp(source, destination, { recursive: true });
}

export async function runBackup(options: BackupOptions): Promise<BackupResult> {
  const backupRoot = options.backupRoot ?? "/data/backups";
  await ensureDir(backupRoot);
  const { timestamp, dir } = await createTimestampedDir(backupRoot);

  const paths: BackupPaths = { root: dir };
  const errors: string[] = [];
  const skipped: string[] = [];

  if (options.redisClient) {
    try {
      const file = path.join(dir, BACKUP_FILE_NAMES.redis);
      await backupRedis(options.redisClient, file);
      paths.redis = file;
    } catch (error) {
      errors.push(`redis: ${(error as Error).message}`);
    }
  } else {
    skipped.push("redis");
  }

  if (options.neo4jDriver) {
    try {
      const file = path.join(dir, BACKUP_FILE_NAMES.neo4j);
      await backupNeo4j(options.neo4jDriver, file);
      paths.neo4j = file;
    } catch (error) {
      errors.push(`neo4j: ${(error as Error).message}`);
    }
  } else {
    skipped.push("neo4j");
  }

  if (options.qdrantClient) {
    try {
      const file = path.join(dir, BACKUP_FILE_NAMES.qdrant);
      await backupQdrant(options.qdrantClient, file, options.qdrantCollection);
      paths.qdrant = file;
    } catch (error) {
      errors.push(`qdrant: ${(error as Error).message}`);
    }
  } else {
    skipped.push("qdrant");
  }

  if (options.documentsPath) {
    try {
      const dest = path.join(dir, BACKUP_FILE_NAMES.documents);
      await backupDocuments(options.documentsPath, dest);
      paths.documents = dest;
    } catch (error) {
      errors.push(`documents: ${(error as Error).message}`);
    }
  } else {
    skipped.push("documents");
  }

  return { timestamp, paths, errors, skipped };
}

export function startDailyBackups(
  options: BackupOptions,
  cronExpression = "0 2 * * *",
) {
  return cron.schedule(cronExpression, () => {
    void runBackup(options);
  });
}
