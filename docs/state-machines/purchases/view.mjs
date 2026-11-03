export const title = "Local StoreKit access and cloud purchase submission";
export const state = v => ({
  Access: v.pro ? v.backend ? "Local and cloud Pro" : "Local Pro, cloud not yet active" : v.backend ? "Cloud Pro, local refresh pending" : "No Pro",
  Store: v.purchasing ? "Buying" : v.restoring ? "Restoring" : "No purchase operation",
  Refresh: v.refresh === "dirty" ? "Read superseded, must reread" : v.refresh === "reading" ? "Reading verified entitlements" : "Entitlements settled"
});
export const step = a => ({
  YouBuy: "you buy",
  YouRestore: "you restore",
  OperationSettles: "the StoreKit operation finishes",
  RequestRefresh: "the app requests current entitlements",
  NewRefreshWhileReading: "another entitlement refresh is requested",
  DiscardOutdatedRead: "the outdated read is discarded",
  CommitVerifiedFacts: "verified current purchases grant local Pro",
  CommitNoEntitlement: "current purchases contain no entitlement",
  CancelRefresh: "the refresh is canceled without committing",
  SubmitVerifiedPurchase: "the app submits a verified purchase",
  SubmissionFails: "submission fails and becomes retryable",
  ServerAcceptsPurchase: "Apple verification grants cloud Pro",
  AppleRevokesRemotely: "an Apple notification removes cloud access",
  Settled: "remain settled"
})[a];
