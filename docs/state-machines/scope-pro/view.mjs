export const title = "Sharing scope, Pro pause, and food retention";
export const state = v => !v.connected ? "Relationship removed, foods deleted"
  : v.scope === "off" ? "Sharing off, foods deleted"
  : !v.pro ? v.storedFoods ? "Paused, foods hidden but retained" : "Paused, no stored foods"
  : v.scope === "macros" ? "Macros only, no foods stored"
  : v.storedFoods ? "Foods stored and visible" : "Foods allowed, upload pending";
// Keep one representative removal arrow; all other removal steps remain checked.
export const step = (a, from) => a === "YouRemovePerson" && state(from) !== "Foods stored and visible" ? null : ({
  YouShareFoods: "you choose Macros and Foods",
  YouShareMacros: "you choose Macros",
  YouStopSharing: "you stop sharing",
  YouRemovePerson: "you remove the person",
  ProExpires: "the last person's Pro expires",
  ProRenews: "someone renews Pro",
  UploadFoods: "eligible foods upload",
  UploadWhileIneligible: "an ineligible upload removes stored foods",
  Settled: "remain settled"
})[a];
export const group = v => v.pro ? "active" : "paused";
export const colors = { active: "teal", paused: "orange" };
