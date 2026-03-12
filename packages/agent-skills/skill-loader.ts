import { Skill, SkillRegistry } from "./skill-registry";

export class SkillLoader {
  constructor(private readonly registry: SkillRegistry) {}

  async loadFromModule(modulePath: string): Promise<Skill> {
    const loaded = await import(modulePath);
    const skill: Skill = loaded.default ?? loaded.skill;
    if (!skill || !skill.name || typeof skill.handler !== "function") {
      throw new Error(`Module at ${modulePath} does not export a valid skill`);
    }
    this.registry.register(skill);
    return skill;
  }

  loadBuiltIn(): void {
    const skills: Skill[] = [
      {
        name: "document-analysis",
        description: "Parses and summarizes provided documents.",
        handler: async (payload) => ({ summary: typeof payload === "string" ? payload.slice(0, 120) : "No content" }),
      },
      {
        name: "vector-search",
        description: "Performs semantic lookup against an embedding index.",
        handler: async (payload) => ({ matches: [], query: payload }),
      },
      {
        name: "knowledge-linking",
        description: "Creates links between related knowledge graph nodes.",
        handler: async (payload) => ({ linked: true, payload }),
      },
    ];

    for (const skill of skills) {
      this.registry.register(skill);
    }
  }
}
