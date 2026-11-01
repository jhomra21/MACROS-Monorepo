import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

crons.cron("sweep old shared foods", "0 3 * * 0", internal.foodCleanup.sweep, {});

export default crons;
