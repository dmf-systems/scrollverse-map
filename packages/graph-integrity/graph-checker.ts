export interface Neo4jSession {
  run<T = unknown>(query: string, params?: Record<string, unknown>): Promise<{ records: T[] }>;
  close?: () => void | Promise<void>;
}

export interface Neo4jDriver {
  session(options?: Record<string, unknown>): Neo4jSession;
}

export type GraphIssue =
  | { type: "orphan"; nodeId: string | number; label?: string }
  | { type: "missingEdge"; from: string | number; to: string | number; relationship: string };

export const findOrphans = async (driver: Neo4jDriver): Promise<GraphIssue[]> => {
  const session = driver.session();
  try {
    const result = await session.run<{ get: (key: string) => unknown }>(
      "MATCH (n) WHERE NOT (n)--() RETURN n.id AS id, labels(n) AS labels LIMIT 100"
    );
    return result.records.map((record: any) => ({ type: "orphan", nodeId: record.id ?? record.get?.("id"), label: record.labels?.[0] }));
  } finally {
    await session.close?.();
  }
};

export const repairMissingEdges = async (
  driver: Neo4jDriver,
  relationship: string,
  basedOnProperty = "parentId"
): Promise<GraphIssue[]> => {
  const session = driver.session();
  const issues: GraphIssue[] = [];
  try {
    const query = `
      MATCH (child {${basedOnProperty}: $value})-[:${relationship}]->(:Root)
      RETURN count(child) AS cnt
    `;
    // This is a placeholder lookup; in a real deployment you would stream candidate nodes
    const result = await session.run<{ get: (key: string) => unknown }>(query, { value: "__missing__" });
    if (result.records.length === 0 || (result.records[0] as any).cnt === 0) {
      issues.push({ type: "missingEdge", from: "unknown", to: "root", relationship });
    }
    return issues;
  } finally {
    await session.close?.();
  }
};

export const validateGraph = async (driver: Neo4jDriver): Promise<GraphIssue[]> => {
  const orphans = await findOrphans(driver);
  const missingEdges = await repairMissingEdges(driver, "PARENT_OF");
  return [...orphans, ...missingEdges];
};

const runCli = async (): Promise<void> => {
  console.log("[graph-check] No Neo4j driver configured; running dry-run");
  const issues: GraphIssue[] = [{ type: "orphan", nodeId: "sample", label: "Example" }];
  if (issues.length === 0) {
    console.log("Graph is consistent");
  } else {
    console.log(`Detected ${issues.length} potential issues`, issues);
  }
};

if (require.main === module) {
  runCli().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
