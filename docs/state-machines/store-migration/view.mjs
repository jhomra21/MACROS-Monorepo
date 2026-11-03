export const title = "Local database migration and relaunch";
export const state = v => ({
  launch: v.base ? "Relaunched with only database copied" : "Legacy database waiting",
  copyBase: "Copying database",
  copyWAL: "Database copied, WAL still missing",
  failed: "Copy failed after database",
  opened: v.wal ? "Complete migrated store opened" : "Incomplete migrated store opened"
})[v.phase];
export const step = a => ({
  CheckDestination: "the app checks for the destination database",
  CopyBase: "the database copy finishes",
  CopyWAL: "the committed WAL copy finishes",
  CopyFails: "the WAL copy fails",
  YouRelaunch: "you relaunch",
  Settled: "use the opened store"
})[a];
export const group = v => v.phase === "opened" ? "opened" : "copy";
export const colors = { opened: "teal", copy: "blue" };
