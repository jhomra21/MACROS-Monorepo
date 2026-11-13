import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import type { Copy } from "../src/slides.ts";

export const fromRoot = (path: string) => fileURLToPath(new URL(`../../../../${path}`, import.meta.url));

/** The TikTok slideshow renders, one folder per headline variant. */
export const TIKTOK_DIRS: Record<Copy, string> = { short: fromRoot("build/marketing/tiktok"), full: fromRoot("build/marketing/tiktok-full") };

export const REPO_ROOT = fromRoot("");
export const OUT_DIR = fromRoot("build/marketing/trailer");
export const RAW_DIR = fromRoot("build/marketing/trailer/sources/v3");
export const RAW_DIR_V4 = fromRoot("build/marketing/trailer/sources/v4");
export const PUBLIC_SOURCES = fromRoot("tools/media/trailer/public/sources");
export const DEMO_VIDEO = fromRoot("web/public/media/macros-demo.d72c87d2.mp4");

export function run(cmd: string[]) {
  const result = spawnSync(cmd[0], cmd.slice(1), { stdio: "inherit" });
  if (result.status !== 0) throw new Error(`${cmd.slice(0, 3).join(" ")} failed with exit code ${result.status}`);
}
