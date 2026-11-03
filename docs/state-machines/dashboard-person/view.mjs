export const title = "Person detail after roster removal";
export const state = v => v.roster === "removed"
  ? v.task === "failed" ? "Person removed, old macros still shown after error" : "Person removed, original macros shown"
  : v.roster === "notShared" ? "Sharing stopped, macros hidden"
  : v.cached ? "Live macros shown" : "Original dashboard macros shown";
export const step = a => ({
  LiveDayArrives: "the live day arrives",
  OtherRemovesYou: "the dashboard confirms the other person removed you",
  OtherStopsSharing: "the dashboard confirms sharing stopped",
  PermissionReply: "the day query confirms not shared",
  QueryFails: "the removed-person query fails",
  ChangeDay: "the day changes",
  OldReplyIgnored: "a canceled old-day reply is ignored",
  Settled: "remain on the screen"
})[a];
export const group = v => v.roster === "visible" ? "visible" : "revoked";
export const colors = { visible: "teal", revoked: "orange" };
