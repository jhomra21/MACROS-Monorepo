export const title = "Deleting a sharing profile";
export const state = v => ({
  idle: v.server === "live" ? "Sharing enabled" : "Cloud deleted, device still enabled",
  deleting: "Deleting in the cloud",
  acknowledgment: "Cloud deleted, reply pending",
  cleaning: "Sharing off, clearing credentials",
  retryCleanup: "Sharing off, cleanup needs retry",
  done: "Deleted and credentials cleared",
  blocked: "Retry blocked by deleted credentials"
})[v.phase];
export const step = a => ({
  YouDelete: "you delete or retry deletion",
  ServerDeletes: "the server commits deletion",
  ReplyArrives: "the reply reaches your phone",
  ReplyIsLost: "the reply is lost or the app terminates",
  CleanupFails: "Keychain cleanup fails",
  YouRetryCleanup: "you retry credential cleanup",
  CleanupFinishes: "credential cleanup finishes",
  Settled: "remain settled"
})[a];
export const group = v => v.phase === "blocked" ? "failure" : v.phase === "done" ? "done" : "work";
export const colors = { failure: "pink", done: "teal", work: "blue" };
