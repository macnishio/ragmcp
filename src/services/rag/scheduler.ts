import type { RagService } from "./service.js";

export class SyncScheduler {
  private intervalId: ReturnType<typeof setInterval> | null = null;
  private running = false;

  constructor(private ragService: RagService) {}

  start(intervalMs = 60_000): void {
    if (this.intervalId) return;
    this.intervalId = setInterval(() => this.tick(), intervalMs);
    // Run immediately on start to catch overdue schedules
    this.tick();
    console.log(`SyncScheduler started, checking every ${intervalMs / 1000}s`);
  }

  stop(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  private async tick(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      const due = this.ragService.getDueSchedules();
      for (const schedule of due) {
        try {
          console.log(`[Scheduler] Syncing source ${schedule.sourceId}...`);
          await this.ragService.syncSource(schedule.sourceId);
          this.ragService.markScheduleRun(schedule.sourceId, "success");
          console.log(`[Scheduler] Sync completed for ${schedule.sourceId}`);
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err);
          this.ragService.markScheduleRun(schedule.sourceId, "error", msg);
          console.error(`[Scheduler] Sync failed for ${schedule.sourceId}: ${msg}`);
        }
      }
    } finally {
      this.running = false;
    }
  }
}
