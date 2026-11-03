// Run from convex-backend after installing its dependencies. See README.md.
// Secrets are generated locally, stored only in an ignored 0600 state file,
// never printed, and deleted by cleanup. Only the dev deployment is allowed.
import { ConvexHttpClient } from "../../../convex-backend/node_modules/convex/browser";
import { api } from "../../../convex-backend/convex/_generated/api";
import { chmod, readFile, unlink, writeFile } from "node:fs/promises";

const convexURL = "https://energized-pigeon-822.convex.cloud";

const authURL = "https://macros-auth.jhonra121.workers.dev/v1/token";

const simulator = "F976E800-DA1F-4F20-B755-DFD964E33975";

const statePath = new URL("../../../build/state-machine-fixes/f3-private.json", import.meta.url);

const day = new Intl.DateTimeFormat("en-CA").format(new Date());

type State = { profileKey: string; profileSecret: string; displayName: string; invite: string };

async function clientFor(state: State) {
  const response = await fetch(authURL, {
    method: "POST",
    headers: { "Content-Type": "application/json", "User-Agent": "MACROS-state-machine-e2e/1.0" },
    body: JSON.stringify(state),
  });

  if (!response.ok) throw new Error(`Auth exchange failed: HTTP ${response.status}`);
  const session: { token: string } = await response.json();
  const client = new ConvexHttpClient(convexURL);
  client.setAuth(session.token);

  return client;
}

async function main() {
  const command = process.argv[2];

  if (command === "setup") {
    const state: State = {
      profileKey: `statefix_${crypto.randomUUID().replaceAll("-", "")}`,
      profileSecret: crypto.randomUUID().replaceAll("-", "") + crypto.randomUUID().replaceAll("-", ""),
      displayName: "State Fix Partner",
      invite: crypto.randomUUID().replaceAll("-", ""),
    };

    await writeFile(statePath, JSON.stringify(state), { mode: 0o600, flag: "wx" });
    await chmod(statePath, 0o600);
    const client = await clientFor(state);
    await client.mutation(api.sharing.upsertMyDailySnapshot, {
      day, timeZoneId: Intl.DateTimeFormat().resolvedOptions().timeZone,
      calories: 1234, protein: 87, carbs: 146, fat: 33, entryCount: 3,
    });
    const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(state.invite)));
    const tokenHash = [...hash].map(byte => byte.toString(16).padStart(2, "0")).join("");
    await client.mutation(api.sharing.createInvite, { tokenHash });
    console.log("Created disposable dev partner, snapshot 1234 kcal / P87 C146 F33, and invite (not logged).");

    return;
  }

  const state: State = JSON.parse(await readFile(statePath, "utf8"));
  const client = await clientFor(state);

  switch (command) {
    case "open-invite": {
      const child = Bun.spawn(["xcrun", "simctl", "openurl", simulator, `calmacrotracker://sharing/invite/${state.invite}`], {
        stdout: "ignore", stderr: "ignore",
      });

      if (await child.exited !== 0) throw new Error("Opening private invite failed.");
      console.log("Opened invite in app; confirm Start Sharing (invite not logged).");
      break;
    }

    case "remove": {
      const dashboard = await client.query(api.sharing.sharingDashboard, { day, ownerToday: day });

      if (dashboard.people.length !== 1) throw new Error("Expected exactly one disposable relationship.");
      await client.mutation(api.sharing.removePerson, { otherProfileId: dashboard.people[0].profileId, ownerDay: day });
      const after = await client.query(api.sharing.sharingDashboard, { day, ownerToday: day });

      if (after.people.length !== 0) throw new Error("Relationship removal not confirmed.");
      console.log("Authoritative dev dashboard confirms zero relationships; leave app detail open.");
      break;
    }

    case "check": {
      const dashboard = await client.query(api.sharing.sharingDashboard, { day, ownerToday: day });
      console.log(`Disposable partner dashboard relationship count: ${dashboard.people.length}.`);
      break;
    }

    case "cleanup":
      await client.mutation(api.sharing.deleteMySharingProfile, {});
      await unlink(statePath);
      console.log("Deleted disposable dev partner through app API and removed private local state.");
      break;
    default:
      throw new Error("Use setup | open-invite | check | remove | cleanup.");
  }
}

try {
  await main();
} catch {
  // Do not print SDK exceptions, request payloads, tokens, or credential state.
  console.error("E2E operation failed; no credentials logged. Check the selected step and dev availability.");
  process.exitCode = 1;
}
