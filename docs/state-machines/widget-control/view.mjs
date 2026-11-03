export const title = "IN FLUX: widget credential migration and generation fence";
export const state = v => ({
  Credentials: !v.shared ? "Legacy identity only" : v.legacy ? v.verified ? "Both copies verified" : "Shared copy awaiting verification" : "Verified shared identity",
  Widget: !v.enabled || !v.pro
    ? v.cachedGeneration === 0 ? "Access stopped, obsolete cache inert" : "Access stopped"
    : v.selected ? "Current-generation macros selected" : v.request !== "idle" ? "Loading current person" : "No macros published"
});
export const step = a => ({
  CopyCredential: "the app copies the identity",
  VerifyCopy: "the app verifies byte-for-byte equality",
  DeleteLegacy: "the app deletes the specifically scoped legacy item",
  WidgetStarts: "WidgetKit requests a person",
  AppDisables: "the app disables sharing and rotates generation",
  AppDeniesPro: "the app denies Pro and rotates generation",
  CheckResponse: "the response passes the first current-control check",
  WriteCache: "the cache write uses the request's generation",
  CheckBeforeReturn: "the provider checks current control again before returning",
  ReadCache: "the widget reads only the current generation",
  Settled: "remain settled"
})[a];
