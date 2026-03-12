import { compactVectors, VectorRecord, CompactionResult } from "./vector-compactor";

export interface QdrantCollectionClient {
  scroll(collection: string): Promise<VectorRecord[]>;
  upsert(collection: string, vectors: VectorRecord[]): Promise<void>;
  delete(collection: string, ids: string[]): Promise<void>;
  optimize?(collection: string): Promise<void>;
}

export interface QdrantClient extends QdrantCollectionClient {
  listCollections(): Promise<string[]>;
}

export type OptimizeOptions = {
  staleAfterMs?: number;
  precision?: number;
  log?: (message: string) => void;
};

const defaultOptimizeOptions = (): Required<OptimizeOptions> => ({
  staleAfterMs: 1000 * 60 * 60 * 24 * 30,
  precision: 4,
  log: (message: string) => console.log(message),
});

export const optimizeCollection = async (
  client: QdrantCollectionClient,
  collection: string,
  options: OptimizeOptions = {}
): Promise<CompactionResult> => {
  const { staleAfterMs, precision, log } = { ...defaultOptimizeOptions(), ...options };
  log(`Optimizing collection "${collection}"`);
  const vectors = await client.scroll(collection);
  const result = compactVectors(vectors, precision, staleAfterMs);

  if (result.removed.length > 0) {
    log(`Removing ${result.removed.length} stale vectors`);
    await client.delete(
      collection,
      result.removed.map((v) => v.id)
    );
  }

  if (result.kept.length > 0) {
    log(`Upserting ${result.kept.length} compacted vectors`);
    await client.upsert(collection, result.kept);
  }

  if (client.optimize) {
    await client.optimize(collection);
    log(`Triggered on-cluster optimization for "${collection}"`);
  }

  return result;
};

export const optimizeAllCollections = async (client: QdrantClient, options: OptimizeOptions = {}): Promise<CompactionResult[]> => {
  const { log } = { ...defaultOptimizeOptions(), ...options };
  const collections = await client.listCollections();
  const results: CompactionResult[] = [];
  for (const collection of collections) {
    results.push(await optimizeCollection(client, collection, options));
  }
  log(`Optimized ${collections.length} collections`);
  return results;
};

const runCli = async (): Promise<void> => {
  const log = (message: string): void => console.log(`[vector-optimizer] ${message}`);
  log("No Qdrant client provided; running dry-run with in-memory data.");
  const sampleVectors: VectorRecord[] = [
    { id: "v1", values: [0.123456, 0.654321], lastAccessed: Date.now() },
    { id: "v2", values: [0.3333333, 0.999999], lastAccessed: Date.now() - 1000 * 60 * 60 * 24 * 90 },
  ];
  const result = compactVectors(sampleVectors);
  log(`Kept ${result.kept.length} vectors, removed ${result.removed.length} stale vectors`);
};

if (require.main === module) {
  runCli().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
