// Prints WCAG contrast ratios for the bold style (text on each colour field) and the restrained style's brightest wash centre.
import { COLORS } from "../src/shots.ts";
import { STYLES } from "../src/styles.ts";

const channel = (v: number) => (v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
const luminance = (hex: string) => {
  const [r, g, b] = [1, 3, 5].map((i) => channel(parseInt(hex.slice(i, i + 2), 16)));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const ratio = (a: string, b: string) => {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};
const mix = (a: string, b: string, t: number) =>
  "#" + [1, 3, 5].map((i) => Math.round(parseInt(a.slice(i, i + 2), 16) * t + parseInt(b.slice(i, i + 2), 16) * (1 - t)).toString(16).padStart(2, "0")).join("");

const bold = STYLES.bold;
const restrained = STYLES.restrained;
for (const [name, color] of Object.entries(COLORS)) {
  console.log(`bold  ${name} ${color}: text ${bold.text} ${ratio(bold.text, color).toFixed(2)}:1, white ${ratio("#FFFFFF", color).toFixed(2)}:1`);
  // Wash centre is the shot colour at 50% over the near-black background.
  const centre = mix(color, restrained.background!, 0.5);
  console.log(`restrained wash centre ${name} ${centre}: white ${ratio("#FFFFFF", centre).toFixed(2)}:1, muted ${restrained.muted} ${ratio(restrained.muted, centre).toFixed(2)}:1`);
}
