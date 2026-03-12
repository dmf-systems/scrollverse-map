import fs from "fs/promises";
import path from "path";
import { BACKUP_FILE_NAMES, QdrantClientLike, RedisRestoreClient, Neo4jDriverLike } from "../backup";

export type RestoreOptions = {
  backupRoot?: string;
  backupDir?: string;
  redisClient?: RedisRestoreClient;
  neo4jDriver?: Neo4jDriverLike;
  qdrantClient?: QdrantClientLike;
  documentsPath?: string;
  wipeNeo4j?: boolean;
};

type RedisEntry = {
  key: string;
  value: string | null;
  ttl: number;
};

type RedisBackupPayload = {
  generatedAt: string;
  entries: RedisEntry[];
};

type Neo4jNode = {
  id: number;
  labels: string[];
  properties: Record<string, unknown>;
};

type Neo4jRelationship = {
  id: number;
  startId: number;
  endId: number;
  type: string;
  properties: Record<string, unknown>;
};

type Neo4jBackupPayload = {
  generatedAt: string;
  nodes: Neo4jNode[];
  relationships: Neo4jRelationship[];
};

type QdrantBackupPayload = unknown;

function sanitizeLabel(label: string): string {
  return label.replace(/`/g, "");
}

function sanitizeType(type: string): string {
  const cleaned = type.replace(/[^A-Za-z0-9_]/g, "");
  return cleaned.length > 0 ? cleaned : "REL";
}

async function findLatestBackupDir(root: string): Promise<string | null> {
  try {
    const entries = await fs.readdir(root, { withFileTypes: true });
    const dirs = entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name);
    if (dirs.length === 0) return null;
    const latest = dirs.sort().reverse()[0];
    if (!latest) return null;
    return path.join(root, latest);
  } catch {
    return null;
  }
}

async function readJson<T>(file: string): Promise<T> {
  const content = await fs.readFile(file, "utf-8");
  return JSON.parse(content) as T;
}

async function restoreRedis(client: RedisRestoreClient, file: string): Promise<void> {
  const payload = await readJson<RedisBackupPayload>(file);

  for (const entry of payload.entries) {
    if (entry.value === null) continue;
    const ttl = typeof entry.ttl === "number" && entry.ttl > 0 ? entry.ttl : 0;
    const buffer = Buffer.from(entry.value, "base64");

    if (client.restore) {
      await client.restore(entry.key, ttl, buffer, "REPLACE");
    } else if (client.set) {
      await client.set(entry.key, buffer.toString("utf-8"));
    }
  }
}

async function restoreNeo4j(
  driver: Neo4jDriverLike,
  file: string,
  wipeExisting: boolean,
): Promise<void> {
  const payload = await readJson<Neo4jBackupPayload>(file);
  const session = driver.session();

  try {
    if (wipeExisting) {
      await session.run("MATCH (n) DETACH DELETE n");
    }

    for (const node of payload.nodes) {
      const labels = node.labels.map((label) => `\`${sanitizeLabel(label)}\``).join(":");
      const labelSegment = labels.length ? `:${labels}` : "";
      const query = `CREATE (n${labelSegment}) SET n = $properties, n._backupId = $id`;
      const properties = { ...(node.properties ?? {}), _backupId: node.id };
      await session.run(query, { properties, id: node.id });
    }

    for (const rel of payload.relationships) {
      const type = sanitizeType(rel.type);
      const query = `
        MATCH (a {_backupId: $startId}), (b {_backupId: $endId})
        CREATE (a)-[r:${type}]->(b)
        SET r = $properties, r._backupId = $id
      `;
      const properties = { ...(rel.properties ?? {}), _backupId: rel.id };
      await session.run(query, {
        startId: rel.startId,
        endId: rel.endId,
        properties,
        id: rel.id,
      });
    }
  } finally {
    await session.close?.();
  }
}

async function restoreQdrant(file: string): Promise<QdrantBackupPayload> {
  return readJson<QdrantBackupPayload>(file);
}

async function restoreDocuments(source: string, destination: string): Promise<void> {
  await fs.mkdir(destination, { recursive: true });
  await fs.cp(source, destination, { recursive: true });
}

export async function restoreAll(options: RestoreOptions) {
  const backupRoot = options.backupRoot ?? "/data/backups";
  const resolvedBackupDir =
    options.backupDir ?? (await findLatestBackupDir(backupRoot));

  if (!resolvedBackupDir) {
    throw new Error(`No backup directory found in ${backupRoot}`);
  }

  const backupDir = resolvedBackupDir;

  const restored: string[] = [];
  const skipped: string[] = [];

  if (options.redisClient) {
    const file = path.join(backupDir, BACKUP_FILE_NAMES.redis);
    try {
      await restoreRedis(options.redisClient, file);
      restored.push("redis");
    } catch (error) {
      throw new Error(`redis restore failed: ${(error as Error).message}`);
    }
  } else {
    skipped.push("redis");
  }

  if (options.neo4jDriver) {
    const file = path.join(backupDir, BACKUP_FILE_NAMES.neo4j);
    try {
      await restoreNeo4j(options.neo4jDriver, file, options.wipeNeo4j ?? false);
      restored.push("neo4j");
    } catch (error) {
      throw new Error(`neo4j restore failed: ${(error as Error).message}`);
    }
  } else {
    skipped.push("neo4j");
  }

  if (options.qdrantClient) {
    const file = path.join(backupDir, BACKUP_FILE_NAMES.qdrant);
    try {
      await restoreQdrant(file);
      restored.push("qdrant");
    } catch (error) {
      throw new Error(`qdrant restore failed: ${(error as Error).message}`);
    }
  } else {
    skipped.push("qdrant");
  }

  if (options.documentsPath) {
    const source = path.join(backupDir, BACKUP_FILE_NAMES.documents);
    try {
      await restoreDocuments(source, options.documentsPath);
      restored.push("documents");
    } catch (error) {
      throw new Error(`documents restore failed: ${(error as Error).message}`);
    }
  } else {
    skipped.push("documents");
  }

  return { backupDir, restored, skipped };
}
