export type ScheduledTask = () => Promise<void> | void;

export type ScheduledJob = {
  id: string;
  cron: string;
  task: ScheduledTask;
  retryLimit?: number;
};

export class ScheduleRegistry {
  private readonly jobs = new Map<string, ScheduledJob>();

  register(job: ScheduledJob): void {
    this.jobs.set(job.id, job);
  }

  unregister(id: string): void {
    this.jobs.delete(id);
  }

  list(): ScheduledJob[] {
    return [...this.jobs.values()];
  }

  get(id: string): ScheduledJob | undefined {
    return this.jobs.get(id);
  }
}
