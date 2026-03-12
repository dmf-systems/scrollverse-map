export type VectorRecord = {
  id: string;
  values: number[];
  lastAccessed?: number;
  payload?: Record<string, unknown>;
};

export type CompactionResult = {
  kept: VectorRecord[];
  removed: VectorRecord[];
};

export const compressEmbedding = (values: number[], precision = 4): number[] => {
  const factor = 10 ** precision;
  return values.map((v) => Math.round(v * factor) / factor);
};

export const compactVectors = (vectors: VectorRecord[], precision = 4, staleAfterMs = 1000 * 60 * 60 * 24 * 30): CompactionResult => {
  const now = Date.now();
  const kept: VectorRecord[] = [];
  const removed: VectorRecord[] = [];

  for (const vector of vectors) {
    const isStale = typeof vector.lastAccessed === "number" ? now - vector.lastAccessed > staleAfterMs : false;
    if (isStale) {
      removed.push(vector);
      continue;
    }
    kept.push({ ...vector, values: compressEmbedding(vector.values, precision) });
  }

  return { kept, removed };
};
