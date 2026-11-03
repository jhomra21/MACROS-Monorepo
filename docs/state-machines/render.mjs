import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const [folder, peleFolder] = process.argv.slice(2);
if (!folder || !peleFolder) throw new Error("Usage: bun render.mjs <model-folder> <pele-install-folder>");
const { render } = await import(pathToFileURL(resolve(peleFolder, "node_modules/pele/dist/pele.js")).href);
const source = await readFile(resolve(folder, "chart.mmd"), "utf8");
const css = await readFile(new URL("./colors.css", import.meta.url), "utf8");
const { svg } = render(source, { limit: 1_000_000, outputLimit: 8_000_000, maxEdges: 10_000 });
if (!svg.includes("<svg")) throw new Error("Pele did not return SVG");
await writeFile(resolve(folder, "chart.svg"), svg.replace(/(<svg\b[^>]*>)/, `$1<style>${css}</style>`));
console.log(resolve(folder, "chart.svg"));
