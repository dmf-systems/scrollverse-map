import { QueryPlan, QueryRequest, SearchStrategy, selectStrategy } from "./query-planner";

export type OptimizedQuery = {
  plan: QueryPlan;
  params: {
    topK: number;
    rerank: boolean;
    graphDepth: number;
  };
};

const defaultParams: Record<SearchStrategy, { topK: number; rerank: boolean; graphDepth: number }> = {
  vector: { topK: 20, rerank: true, graphDepth: 0 },
  graph: { topK: 50, rerank: false, graphDepth: 3 },
  hybrid: { topK: 30, rerank: true, graphDepth: 2 },
};

export const optimizeQuery = (request: QueryRequest): OptimizedQuery => {
  const plan = selectStrategy(request);
  const params = { ...defaultParams[plan.strategy] };

  if (request.filters && Object.keys(request.filters).length > 2) {
    params.topK = Math.min(params.topK + 10, 100);
  }

  if (plan.strategy === "vector" && request.embedding && request.embedding.length > 1024) {
    params.rerank = false;
  }

  return { plan, params };
};
