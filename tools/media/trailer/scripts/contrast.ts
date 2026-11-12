// Prints WCAG contrast ratios for the trailer's near-black text on each colour field.
import { COLORS } from "../src/shots.ts";
import { STYLE } from "../src/styles.ts";

const channel = (v: number) => (v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
const luminance = (hex: string) => {
  const [r, g, b] = [1, 3, 5].map((i) => channel(parseInt(hex.slice(i, i + 2), 16)));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const ratio = (a: string, b: string) => {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};

for (const [name, color] of Object.entries(COLORS)) {
  console.log(`${name} ${color}: text ${STYLE.text} ${ratio(STYLE.text, color).toFixed(2)}:1, white ${ratio("#FFFFFF", color).toFixed(2)}:1`);
}
