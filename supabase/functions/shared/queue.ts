import { callPlatformVoid } from "./database.ts";

/** Trigger platform cron processors — used by jobs/ functions only. */
export async function runPlatformCronTick(): Promise<void> {
  await callPlatformVoid("platform.run_platform_cron_tick", []);
}

export async function runPlatformDailyMaintenance(): Promise<void> {
  await callPlatformVoid("platform.run_platform_daily_maintenance", []);
}
