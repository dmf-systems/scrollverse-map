export type SkillHandler = (payload: unknown) => Promise<unknown> | unknown;

export interface Skill {
  name: string;
  description?: string;
  handler: SkillHandler;
}

export class SkillRegistry {
  private readonly skills = new Map<string, Skill>();

  register(skill: Skill): void {
    this.skills.set(skill.name, skill);
  }

  unregister(name: string): void {
    this.skills.delete(name);
  }

  get(name: string): Skill | undefined {
    return this.skills.get(name);
  }

  list(): Skill[] {
    return [...this.skills.values()];
  }

  async execute(name: string, payload: unknown): Promise<unknown> {
    const skill = this.skills.get(name);
    if (!skill) {
      throw new Error(`Skill "${name}" not found`);
    }
    return skill.handler(payload);
  }
}
