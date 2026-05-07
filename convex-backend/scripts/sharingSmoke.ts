import { ConvexHttpClient } from "convex/browser";
import { api } from "../convex/_generated/api";
import type { Id } from "../convex/_generated/dataModel";

const authBaseUrl = process.env.MACROS_AUTH_URL ?? "https://macros-auth.jhonra121.workers.dev";
const convexUrl = process.env.CONVEX_URL;
const day = new Date().toISOString().slice(0, 10);

if (convexUrl == null) {
  throw new Error("CONVEX_URL is required. Run with the convex-backend .env.local loaded.");
}

type TokenResponse = {
  token: string;
  profile: { profileKey: string; displayName: string; deleted: boolean };
};

type SmokeUser = {
  displayName: string;
  profileKey: string;
  profileSecret: string;
  client: ConvexHttpClient;
};

async function main() {
  const suffix = Date.now().toString(36).slice(-6);
  const userA = await createUser(`Smoke A ${suffix}`);
  const userB = await createUser(`Smoke B ${suffix}`);
  const userC = await createUser(`Smoke C ${suffix}`);
  const unauthenticatedClient = new ConvexHttpClient(convexUrl!);

  await uploadSnapshot(userA, { calories: 321, protein: 30, carbs: 40, fat: 9, entryCount: 2 });
  await uploadSnapshot(userB, { calories: 222, protein: 20, carbs: 10, fat: 8, entryCount: 1 });

  const inviteToken = crypto.randomUUID().replaceAll("-", "");
  await userA.client.mutation(api.sharing.createInvite, { tokenHash: await sha256Hex(inviteToken) });
  await userB.client.mutation(api.sharing.acceptInvite, { tokenHash: await sha256Hex(inviteToken), ownerDay: day });

  const dashboardForB = await userB.client.query(api.sharing.sharingDashboard, { day, ownerToday: day });
  const aFromB = expectPerson(dashboardForB, userA.displayName);
  assert(aFromB.incomingActive, "A should be sharing with B after invite acceptance.");
  assert(!aFromB.outgoingActive, "B should not share back until reciprocal sharing is enabled.");
  assert(aFromB.snapshot?.calories === 321, "B should see A's uploaded snapshot.");
  await expectQueryFailure(
    () => userB.client.query(api.sharing.sharingDashboard, { day: previousDay(day), ownerToday: day }),
    "Dashboard query should reject non-current-day snapshot requests.",
  );
  const historicalDay = previousDay(previousDay(day));
  await expectQueryFailure(
    () => userB.client.query(api.sharing.sharingDashboard, { day: historicalDay, ownerToday: historicalDay }),
    "Dashboard query should not trust caller-supplied historical ownerToday values.",
  );

  await expectQueryFailure(
    () => unauthenticatedClient.query(api.sharing.sharingDashboard, { day, ownerToday: day }),
    "Unauthenticated dashboard queries should fail.",
  );
  const dashboardForC = await userC.client.query(api.sharing.sharingDashboard, { day, ownerToday: day });
  assert(dashboardForC.people.length === 0, "Unrelated profiles should not see sharing relationships or snapshots.");

  const dashboardForA = await userA.client.query(api.sharing.sharingDashboard, { day, ownerToday: day });
  const bFromA = expectPerson(dashboardForA, userB.displayName);
  assert(!bFromA.incomingActive, "A should not receive B's snapshot before reciprocal sharing is enabled.");
  assert(bFromA.snapshot == null, "B's snapshot should be hidden before reciprocal sharing is enabled.");

  await userB.client.mutation(api.sharing.setOutgoingSharingForPerson, {
    toProfileId: aFromB.profileId as Id<"profiles">,
    enabled: true,
    ownerDay: day,
  });
  const reciprocalDashboardForA = await userA.client.query(api.sharing.sharingDashboard, { day, ownerToday: day });
  assert(
    expectPerson(reciprocalDashboardForA, userB.displayName).snapshot?.calories === 222,
    "A should see B's snapshot after reciprocal sharing is enabled.",
  );

  await userA.client.mutation(api.sharing.stopSharingMyData, { ownerDay: day });
  const disabledDashboardForB = await userB.client.query(api.sharing.sharingDashboard, { day, ownerToday: day });
  const disabledAFromB = expectPerson(disabledDashboardForB, userA.displayName);
  assert(!disabledAFromB.incomingActive, "A's outgoing sharing should be inactive after stopSharingMyData.");
  assert(disabledAFromB.snapshot == null, "A's same-day snapshot should be hidden after sharing is stopped.");

  await userA.client.mutation(api.sharing.setOutgoingSharingForPerson, {
    toProfileId: bFromA.profileId as Id<"profiles">,
    enabled: true,
    ownerDay: day,
  });
  const reenabledDashboardForB = await userB.client.query(api.sharing.sharingDashboard, { day, ownerToday: day });
  assert(
    expectPerson(reenabledDashboardForB, userA.displayName).snapshot?.calories === 321,
    "B should see A's snapshot again after re-enable.",
  );

  await userA.client.mutation(api.sharing.removePerson, {
    otherProfileId: bFromA.profileId as Id<"profiles">,
    ownerDay: day,
  });
  const reconnectInviteToken = crypto.randomUUID().replaceAll("-", "");
  await userA.client.mutation(api.sharing.createInvite, { tokenHash: await sha256Hex(reconnectInviteToken) });
  await userB.client.mutation(api.sharing.acceptInvite, { tokenHash: await sha256Hex(reconnectInviteToken), ownerDay: day });
  const reconnectedDashboardForB = await userB.client.query(api.sharing.sharingDashboard, { day, ownerToday: day });
  const reconnectedAFromB = expectPerson(reconnectedDashboardForB, userA.displayName);
  assert(reconnectedAFromB.incomingActive, "Reconnected A should share with B after a new invite.");
  const reconnectedDashboardForA = await userA.client.query(api.sharing.sharingDashboard, { day, ownerToday: day });
  const reconnectedBFromA = expectPerson(reconnectedDashboardForA, userB.displayName);
  assert(!reconnectedBFromA.incomingActive, "Reconnect should not preserve B's previous reciprocal sharing.");
  assert(reconnectedBFromA.snapshot == null, "Reconnect should not expose B's previous reciprocal snapshot.");
  await userB.client.mutation(api.sharing.setOutgoingSharingForPerson, {
    toProfileId: reconnectedAFromB.profileId as Id<"profiles">,
    enabled: true,
    ownerDay: day,
  });

  await userB.client.mutation(api.sharing.deleteMySharingProfile, {});
  await expectQueryFailure(
    () => userB.client.query(api.sharing.sharingDashboard, { day, ownerToday: day }),
    "Deleted profile's existing token should no longer authorize sharing queries.",
  );
  await expectTokenExchangeFailure(userB, "Deleted profile credentials should not recreate the same cloud identity.");
  await userC.client.mutation(api.sharing.deleteMySharingProfile, {});
  const afterDeleteDashboardForA = await userA.client.query(api.sharing.sharingDashboard, { day, ownerToday: day });
  assert(
    afterDeleteDashboardForA.people.every((person) => person.displayName !== userB.displayName),
    "Deleted sharing profile should disappear from counterpart dashboard.",
  );

  await userA.client.mutation(api.sharing.deleteMySharingProfile, {});
  console.log("Sharing smoke passed.");
}

async function createUser(displayName: string): Promise<SmokeUser> {
  const profileKey = `smoke_${crypto.randomUUID().replaceAll("-", "")}`;
  const profileSecret = crypto.randomUUID().replaceAll("-", "") + crypto.randomUUID().replaceAll("-", "");
  const token = await exchangeToken({ profileKey, profileSecret, displayName });
  const client = new ConvexHttpClient(convexUrl!);
  client.setAuth(token.token);
  return { displayName, profileKey, profileSecret, client };
}

async function exchangeToken(args: { profileKey: string; profileSecret: string; displayName: string }): Promise<TokenResponse> {
  const response = await fetch(`${authBaseUrl}/v1/token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "User-Agent": "MACROS-sharing-smoke/1.0",
    },
    body: JSON.stringify(args),
  });
  if (!response.ok) {
    throw new Error(`Token exchange failed: ${response.status} ${await response.text()}`);
  }
  return await response.json();
}

async function uploadSnapshot(
  user: SmokeUser,
  snapshot: { calories: number; protein: number; carbs: number; fat: number; entryCount: number },
) {
  await user.client.mutation(api.sharing.upsertMyDailySnapshot, {
    day,
    timeZoneId: "America/Chicago",
    ...snapshot,
  });
}

function expectPerson(dashboard: { people: Array<any> }, displayName: string) {
  const person = dashboard.people.find((value) => value.displayName === displayName);
  assert(person != null, `Expected dashboard person ${displayName}.`);
  return person;
}

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

async function expectQueryFailure(query: () => Promise<unknown>, message: string) {
  try {
    await query();
  } catch {
    return;
  }
  throw new Error(message);
}

async function expectTokenExchangeFailure(user: SmokeUser, message: string) {
  try {
    await exchangeToken(user);
  } catch {
    return;
  }
  throw new Error(message);
}

async function sha256Hex(value: string) {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function previousDay(dayKey: string) {
  const date = new Date(`${dayKey}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() - 1);
  return date.toISOString().slice(0, 10);
}

await main();
