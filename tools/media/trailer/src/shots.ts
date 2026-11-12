export type Variant = "coming-soon" | "app-store";

/** Ring colours from the app. The near-black text colour clears 4.5:1 on all three (see scripts/contrast.ts). */
export const COLORS = { protein: "#007AFF", carbs: "#FF9F0A", fat: "#EF4F87" } as const;

/** A line of headline text. `words` reveal from `at` seconds into the shot; a later phase replaces an earlier one. */
export type Phase = { at: number; words: string[] };

/**
 * A number that counts beside the headline. Values come from what the recording shows.
 * A negative `at` starts the count before the cut, so the first frame is already moving.
 */
export type Counter = { label: string; from: number; to: number; at: number; duration: number; decimals?: number; steps?: CounterStep[] };

/** A later move of the same counter, from wherever the previous move ended to `to`. */
export type CounterStep = { to: number; at: number; duration: number };

/** A full-screen 1320 x 2868 recording that plays inside the bezel. */
export type Clip = { file: string; rate: number };

type Common = { start: number; end: number; color: string; phases: Phase[]; support: string; counters: Counter[] };
export type Shot =
  | (Common & { kind: "device"; clip: Clip })
  | (Common & { kind: "type" })
  | (Common & { kind: "end" });

const none: Counter[] = [];
const phase = (at: number, ...words: string[]): Phase => ({ at, words });

// Cuts land on the 0.5 s grid. No clip is sped up.
export const SHOTS: Shot[] = [
  { kind: "device", start: 0, end: 2, color: COLORS.protein, clip: { file: "hook.mp4", rate: 1 },
    phases: [phase(0, "Log", "your", "food."), phase(1, "Get", "on", "with", "your", "day.")], support: "",
    counters: [{ label: "kcal today", from: 0, to: 1310, at: -0.1, duration: 0.9 }] },
  { kind: "device", start: 2, end: 6, color: COLORS.carbs, clip: { file: "search.mp4", rate: 1 },
    phases: [phase(0, "Search", "it.")], support: "Type it, tap it, done.",
    counters: [{ label: "kcal per banana", from: 0, to: 105, at: 2.2, duration: 0.8 }] },
  { kind: "device", start: 6, end: 10, color: COLORS.fat, clip: { file: "scan.mp4", rate: 1 },
    phases: [phase(0, "Scan", "it.")], support: "Barcodes and nutrition labels.",
    counters: [{ label: "kcal logged", from: 0, to: 200, at: 3, duration: 0.8 }] },
  // rings.mp4: 0.6 s of Today at 350 kcal, then four 1.1 s moments on Today right after each Log Food (740, 1340, 1620, 2080 kcal).
  { kind: "device", start: 10, end: 15, color: COLORS.protein, clip: { file: "rings.mp4", rate: 1 },
    phases: [phase(0, "Rings", "fill", "as", "you", "go.")], support: "",
    counters: [{ label: "kcal today", from: 350, to: 740, at: 0.6, duration: 0.45,
      steps: [{ to: 1340, at: 1.7, duration: 0.45 }, { to: 1620, at: 2.8, duration: 0.45 }, { to: 2080, at: 3.9, duration: 0.45 }] }] },
  { kind: "device", start: 15, end: 19, color: COLORS.carbs, clip: { file: "insights.mp4", rate: 1 },
    phases: [phase(0, "Track", "it.")], support: "Weight and calories, over time.",
    counters: [{ label: "g protein, 30-day avg", from: 0, to: 125.7, at: 0.55, duration: 0.8, decimals: 1 }] },
  { kind: "device", start: 19, end: 24, color: COLORS.fat, clip: { file: "home.mp4", rate: 1 },
    phases: [phase(0, "Glance", "at", "it.")], support: "Home Screen widgets.", counters: none },
  { kind: "type", start: 24, end: 26, color: COLORS.protein,
    phases: [phase(0, "Search."), phase(0.5, "Scan."), phase(1, "Track."), phase(1.5, "Done.")], support: "", counters: none },
  { kind: "end", start: 26, end: 29, color: COLORS.carbs, phases: [], support: "", counters: none },
];

export const FPS = 30;
export const TOTAL_FRAMES = SHOTS[SHOTS.length - 1].end * FPS;
