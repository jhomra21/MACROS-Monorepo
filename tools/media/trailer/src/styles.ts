import type { Style } from "./shots";

export type StyleSpec = {
  background: string | null; // null: solid colour field from the shot
  text: string;
  muted: string;
  headSize: number;
  typeSize: number;
  wordStep: number; // seconds between words; 0 reveals a phase at once
  align: "center" | "left";
  counters: boolean;
  pushIn: boolean;
  deviceScale: number;
  mediaTop: number;
  closeTop: number; // bezel-free close-ups sit below the headline block, which can run three lines in bold
  mediaMax: { w: number; h: number };
};

export const STYLES: Record<Style, StyleSpec> = {
  restrained: { background: "#0A0A0C", text: "#FFFFFF", muted: "#E5E5EA", headSize: 150, typeSize: 150, wordStep: 0, align: "center", counters: false, pushIn: false, deviceScale: 0.36, mediaTop: 780, closeTop: 780, mediaMax: { w: 960, h: 1080 } },
  bold: { background: null, text: "#0A0A0C", muted: "#0A0A0C", headSize: 180, typeSize: 200, wordStep: 0.2, align: "left", counters: true, pushIn: true, deviceScale: 0.3, mediaTop: 1000, closeTop: 1130, mediaMax: { w: 840, h: 770 } },
};
