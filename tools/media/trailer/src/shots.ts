export type Style = "restrained" | "bold";
export type Variant = "coming-soon" | "app-store";

/** Ring colours from the app. The near-black text colour clears 4.5:1 on all three (see scripts/contrast.ts). */
export const COLORS = { protein: "#007AFF", carbs: "#FF9F0A", fat: "#EF4F87" } as const;

/** A line of headline text. `words` reveal from `at` seconds into the shot; a later phase replaces an earlier one. */
export type Phase = { at: number; words: string[] };

/** A number that counts up beside the headline (bold style only). Values come from what the recording shows. */
export type Counter = { label: string; from: number; to: number; at: number; duration: number; unit: string; decimals?: number };

export type Crop = { x: number; y: number; w: number; h: number };
export type Clip = { file: string; width: number; height: number; rate: number };

type Common = { start: number; end: number; color: string; phases: Phase[]; support: string; counters: Counter[] };
export type Shot =
  | (Common & { kind: "device"; clip: Clip })
  | (Common & { kind: "close"; clip: Clip; crop: Crop })
  | (Common & { kind: "type" })
  | (Common & { kind: "end" });

const PHONE = { width: 1320, height: 2868 } as const;
// Today screen below the status bar: rings, totals, streak link.
const TODAY: Crop = { x: 0, y: 150, w: 1320, h: 1330 };
// Scan clip from web/public/media/macros-demo.d72c87d2.mp4 (720 x 1280): below the burnt-in pill, camera view and result card.
const SCAN: Crop = { x: 112, y: 222, w: 496, h: 1028 };
// Large MACROS widget on the Home Screen: widget and its label on wallpaper only.
const WIDGET: Crop = { x: 80, y: 915, w: 1160, h: 610 };

const none: Counter[] = [];
const phase = (at: number, ...words: string[]): Phase => ({ at, words });

// Cuts land on the 0.5 s grid. Clip rates are at most 1.4x and never speed a clip past 1.5x.
export const SHOTS: Shot[] = [
  { kind: "close", start: 0, end: 2, color: COLORS.protein, clip: { file: "hook.mp4", ...PHONE, rate: 1 }, crop: TODAY,
    phases: [phase(0, "Log", "your", "food."), phase(1, "Get", "on", "with", "your", "day.")], support: "",
    counters: [{ label: "kcal today", from: 1310, to: 1415, at: 0.2, duration: 0.35, unit: "" }] },
  { kind: "device", start: 2, end: 8, color: COLORS.carbs, clip: { file: "search.mp4", ...PHONE, rate: 0.97 },
    phases: [phase(0, "Search", "it.")], support: "Type it, tap it, done.",
    counters: [{ label: "kcal logged", from: 0, to: 105, at: 4.6, duration: 0.8, unit: "" }] },
  { kind: "close", start: 8, end: 13, color: COLORS.fat, clip: { file: "scan.mp4", width: 720, height: 1280, rate: 0.86 }, crop: SCAN,
    phases: [phase(0, "Scan", "it.")], support: "Barcodes and nutrition labels.",
    counters: [{ label: "kcal logged", from: 0, to: 200, at: 2, duration: 0.8, unit: "" }] },
  { kind: "close", start: 13, end: 17, color: COLORS.protein, clip: { file: "rings.mp4", ...PHONE, rate: 1 }, crop: TODAY,
    phases: [phase(0, "Rings", "fill", "as", "you", "go.")], support: "",
    counters: [{ label: "kcal", from: 1310, to: 1415, at: 0.2, duration: 0.35, unit: "" }, { label: "g carbs", from: 162, to: 189, at: 0.2, duration: 0.35, unit: "" }] },
  { kind: "device", start: 17, end: 21, color: COLORS.carbs, clip: { file: "insights.mp4", ...PHONE, rate: 1.2 },
    phases: [phase(0, "Track", "it.")], support: "Weight and calories, over time.",
    counters: [{ label: "g protein avg", from: 0, to: 125.7, at: 1.5, duration: 1, unit: "", decimals: 1 }] },
  { kind: "close", start: 21, end: 25, color: COLORS.fat, clip: { file: "home.mp4", ...PHONE, rate: 1 }, crop: WIDGET,
    phases: [phase(0, "Glance", "at", "it.")], support: "Home Screen widgets.", counters: none },
  { kind: "type", start: 25, end: 27, color: COLORS.protein,
    phases: [phase(0, "Search."), phase(0.5, "Scan."), phase(1, "Track."), phase(1.5, "Done.")], support: "", counters: none },
  { kind: "end", start: 27, end: 30, color: COLORS.carbs, phases: [], support: "", counters: none },
];
