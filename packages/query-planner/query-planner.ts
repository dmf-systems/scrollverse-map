export type SearchStrategy = "vector" | "graph" | "hybrid";

export type QueryRequest = {
  text: string;
  embedding?: number[];
  filters?: Record<string, string | number | boolean>;
  requireGraph?: boolean;
};

export type QueryPlan = {
  strategy: SearchStrategy;
  reason: string;
  expectedLatency: "low" | "medium" | "high";
};

export const selectStrategy = (request: QueryRequest): QueryPlan => {
  const hasEmbedding = Array.isArray(request.embedding) && request.embedding.length > 0;
  const hasFilters = request.filters && Object.keys(request.filters).length > 0;
  const needGraph = request.requireGraph ?? false;

  if (hasEmbedding && needGraph) {
    return { strategy: "hybrid", reason: "Embedding supplied with graph requirement; combining vector + graph search.", expectedLatency: "medium" };
  }

  if (needGraph || hasFilters) {
    return { strategy: "graph", reason: "Graph predicates present; using relationship traversal.", expectedLatency: "medium" };
  }

  if (hasEmbedding) {
    return { strategy: "vector", reason: "Pure semantic search requested.", expectedLatency: "low" };
  }

  return { strategy: "hybrid", reason: "No embedding provided; falling back to hybrid to balance recall.", expectedLatency: "medium" };
};
