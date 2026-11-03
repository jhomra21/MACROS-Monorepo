import { readFile, readdir, stat, access } from "node:fs/promises";
import { resolve, dirname, relative } from "node:path";
import { fileURLToPath } from "node:url";

const base = dirname(fileURLToPath(import.meta.url));
const repo = resolve(base, "../..");
const expected = {
  "profile-deletion": [8, 10, 8, 8],
  "store-migration": [7, 9, 7, 7],
  invites: [12, 22, 9, 11],
  "dashboard-person": [17, 55, 5, 8],
  upload: [66, 167, 8, 15],
  purchases: [72, 399, 10, 17],
  "scope-pro": [10, 66, 7, 20],
  "widget-control": [69, 355, 9, 10],
};
const required = ["SPEC.tla", "SPEC.cfg", "view.mjs", "chart.mmd", "chart.svg", "report.md", "RUN.md", "tlc.out"];
const failures = [];
let count = 0;
let total = 0;
let largest = { path: "", bytes: 0 };
let links = 0;

async function inspect(folder) {
  for (const entry of await readdir(folder, { withFileTypes: true })) {
    const path = resolve(folder, entry.name);
    if (entry.isDirectory()) {
      await inspect(path);
      continue;
    }
    if (!entry.isFile()) {
      failures.push(`Unexpected non-file: ${path}`);
      continue;
    }
    const { size } = await stat(path);
    count++;
    total += size;
    if (size > largest.bytes) largest = { path: relative(base, path), bytes: size };
    if (size >= 5_000_000) failures.push(`File exceeds 5 MB: ${path}`);
    if (!path.endsWith(".md")) continue;
    const body = await readFile(path, "utf8");
    for (const match of body.matchAll(/!?\[[^\]]*\]\(([^)\s]+)\)/g)) {
      const target = match[1];
      if (/^(https?:|#)/.test(target)) continue;
      const file = resolve(dirname(path), decodeURIComponent(target.split("#")[0]));
      if (!file.startsWith(repo + "/")) {
        failures.push(`Link leaves research checkout: ${target}`);
        continue;
      }
      try { await access(file); links++; }
      catch { failures.push(`Broken link in ${relative(base, path)}: ${target}`); }
    }
  }
}

await inspect(base);
const readme = await readFile(resolve(base, "README.md"), "utf8");
const ids = [...readme.matchAll(/^\| (\d{2}) /gm)].map(m => Number(m[1]));
if (ids.length !== 66 || ids.some((id, index) => id !== index + 1)) failures.push("Inventory IDs must be 01–66 exactly once, in order");
for (const [name, numbers] of Object.entries(expected)) {
  for (const file of required) {
    try { await access(resolve(base, name, file)); }
    catch { failures.push(`Missing ${name}/${file}`); }
  }
  const report = await readFile(resolve(base, name, "report.md"), "utf8");
  const match = report.match(/TLC reached (\d+) states and (\d+) steps\. The chart draws (\d+) states and (\d+) arrows\./);
  if (!match || numbers.some((n, i) => Number(match[i + 1]) !== n)) failures.push(`Unexpected counts: ${name}`);
  const chart = (await readFile(resolve(base, name, "chart.mmd"), "utf8")).trimEnd();
  if (!report.includes("```mermaid\n" + chart + "\n```")) failures.push(`Mermaid handoff differs: ${name}`);
  const svg = await readFile(resolve(base, name, "chart.svg"), "utf8");
  if (!svg.includes("<svg") || !svg.includes("</svg>") || !svg.includes("<style>") ||
      !svg.includes("prefers-color-scheme: dark") || !svg.includes("!important")) failures.push(`Incomplete SVG/theme: ${name}`);
  const config = await readFile(resolve(base, name, "SPEC.cfg"), "utf8");
  if (/\b(VIEW|SYMMETRY|CONSTRAINT|ACTION_CONSTRAINT)\b/.test(config)) failures.push(`Unexpected reduction/bound in ${name}`);
  const view = await import(resolve(base, name, "view.mjs"));
  if (typeof view.state !== "function" || typeof view.step !== "function") failures.push(`Missing view functions: ${name}`);
}
console.log(JSON.stringify({ files: count, bytes: total, largest, localLinks: links, inventory: ids.length, models: Object.keys(expected).length, failures }, null, 2));
if (failures.length) process.exitCode = 1;
