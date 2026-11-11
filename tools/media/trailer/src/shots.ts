export type Variant = "coming-soon" | "app-store";

/** Ring colours from the app. The near-black text colour clears 4.5:1 on all three (see scripts/contrast.ts). */
export const COLORS = { protein: "#007AFF", carbs: "#FF9F0A", fat: "#EF4F87" } as const;

/** A line of headline text. `words` reveal from `at` seconds into the shot; a later phase replaces an earlier one. */
export type Phase = { at: number; words: string[] };

/**
 * A number that counts beside the headline. Values come from what the recording shows.
 * A negative `at` starts the count before the cut, so the first frame is already moving.
 */
export type Counter = { label: string; from: number; to: number; at: number; duration: number; decimals?: number };

/** A full-screen 1320 x 2868 recording that plays inside the bezel. */
export type Clip = { file: string; rate: number };

type Common = { start: number; end: number; color: string; phases: Phase[]; support: string; counters: Counter[] };
export type Shot =
  | (Common & { kind: "device"; clip: Clip })
  | (Common & { kind: "type" })
  | (Common & { kind: "end" });

const none: Counter[] = [];
const phase = (at: number, ...words: string[]): Phase => ({ at, words });

// Cuts land on the 0.5 s grid. No clip plays faster than 1.2x.
export const SHOTS: Shot[] = [
  { kind: "device", start: 0, end: 2, color: COLORS.protein, clip: { file: "hook.mp4", rate: 1 },
    phases: [phase(0, "Log", "your", "food."), phase(1, "Get", "on", "with", "your", "day.")], support: "",
    counters: [{ label: "kcal today", from: 0, to: 1310, at: -0.1, duration: 0.9 }] },
  { kind: "device", start: 2, end: 6, color: COLORS.carbs, clip: { file: "search.mp4", rate: 1 },
    phases: [phase(0, "Search", "it.")], support: "Type it, tap it, done.",
    counters: [{ label: "kcal per banana", from: 0, to: 105, at: 2.2, duration: 0.8 }] },
  { kind: "device", start: 6, end: 12, color: COLORS.fat, clip: { file: "scan.mp4", rate: 1 },
    phases: [phase(0, "Scan", "it.")], support: "Barcodes and nutrition labels.",
    counters: [{ label: "kcal logged", from: 0, to: 539, at: 3.6, duration: 0.8 }] },
  { kind: "device", start: 12, end: 16, color: COLORS.protein, clip: { file: "rings.mp4", rate: 1 },
    phases: [phase(0, "Rings", "fill", "as", "you", "go.")], support: "",
    counters: [{ label: "kcal today", from: 1310, to: 1415, at: -0.05, duration: 0.35 }] },
  { kind: "device", start: 16, end: 20, color: COLORS.carbs, clip: { file: "insights.mp4", rate: 1.2 },
    phases: [phase(0, "Track", "it.")], support: "Weight and calories, over time.",
    counters: [{ label: "g protein, 30-day avg", from: 0, to: 125.7, at: -0.1, duration: 1, decimals: 1 }] },
  { kind: "device", start: 20, end: 25, color: COLORS.fat, clip: { file: "home.mp4", rate: 1 },
    phases: [phase(0, "Glance", "at", "it.")], support: "Home Screen widgets.", counters: none },
  { kind: "type", start: 25, end: 27, color: COLORS.protein,
    phases: [phase(0, "Search."), phase(0.5, "Scan."), phase(1, "Track."), phase(1.5, "Done.")], support: "", counters: none },
  { kind: "end", start: 27, end: 30, color: COLORS.carbs, phases: [], support: "", counters: none },
];
