export const title = "Reusable invite, replacement, and lost reply";
export const state = v => ({
  idle: v.age === "fresh" ? "Valid invite, more than one hour left" : "Valid invite, less than one hour left",
  reused: "Same invite returned",
  creating: "Requesting a replacement",
  reply: "Old link revoked, new reply pending",
  finished: "New link saved, old recipients blocked",
  lost: "App still offers revoked old link",
  connected: "Recipient connected, link still reusable",
  unavailable: v.oldStatus === "pending" ? "Unavailable" : "Old recipient cannot connect"
})[v.phase];
export const step = a => ({
  TimePasses: "the invite enters its final hour",
  YouCreate: "you choose Create Invite",
  ServerReplaces: "the server replaces the previous link",
  ReplyArrives: "the new link reaches your phone",
  ReplyLost: "the new-link reply is lost",
  YouAcceptOld: "someone opens the original link",
  Settled: "remain settled"
})[a];
export const group = v => v.oldStatus === "revoked" ? "replaced" : "live";
export const colors = { replaced: "orange", live: "teal" };
