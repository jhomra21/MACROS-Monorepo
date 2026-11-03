export const title = "Upload drain and identity cancellation";
export const state = v => !v.enabled
  ? v.phase === "idle" || v.phase === "failed" ? "Sharing disabled, no acknowledgment" : "Sharing disabled, old request settling"
  : v.phase === "idle" ? v.dirty ? "Changes waiting to upload" : "Latest changes acknowledged"
  : ({ authenticating: "Authenticating, will reread changes", writing: "Writing latest snapshot", acknowledging: "Cloud committed, acknowledgment pending", failed: "Upload failed, explicit retry needed" })[v.phase];
export const step = a => ({
  YouEdit: "you edit local totals",
  RequestUpload: "the app requests an upload",
  AuthenticationFinishes: "authentication finishes and totals are reread",
  ServerCommits: "the cloud write commits",
  ReplyArrives: "the reply settles without reviving a disabled identity",
  YouDisable: "you disable device sharing",
  CanceledAuthSettles: "the canceled authentication settles",
  WriteFails: "the write fails",
  YouRetry: "you request a retry",
  Settled: "remain settled"
})[a];
export const group = v => v.enabled ? "enabled" : "disabled";
export const colors = { enabled: "blue", disabled: "tan" };
