import { COLORS } from "./shots";

/** A screenshot in web/src/assets/app-images/ (without the extension), or "home-clean", the trailer's clean Home Screen still in public/sources/. */
export type Screenshot = "app-home" | "app-scan-review" | "app-scan-details" | "app-add-food" | "app-history" | "home-clean";

/** `short` is the shorter headline for copy 'short'; 'full' always uses `headline`. */
export type Copy = "short" | "full";

export type Slide = {
  headline: string; // empty on the last slide of a set, which is the CTA
  short?: string; // used for copy 'short' when set, otherwise the headline is used
  color: string;
  screenshot?: Screenshot;
  /** Line above the CTA on the last slide. */
  intro?: string;
};

export type SlideSet = { slug: string; title: string; slides: Slide[]; caption: string; hashtags: string[] };

/** The site has a waitlist form (web/src/components/WaitlistForm.astro on the home and about pages), so the CTA points to it. */
export const CTA = "Coming soon for iPhone. Join the waitlist.";
export const SITE = "macrosios.com";

const ring = [COLORS.protein, COLORS.carbs, COLORS.fat];

/** Ring colours rotate: slide i of set n uses colour (n - 1 + i) mod 3, so neighbouring slides never match. */
function set(n: number, slug: string, title: string, rows: [string, Screenshot?, string?][], caption: string, hashtags: string[], intro?: string): SlideSet {
  const slides = rows.map(([headline, screenshot, short], i): Slide => ({ headline, short, screenshot, color: ring[(n - 1 + i) % 3] }));
  slides.push({ headline: "", color: ring[(n - 1 + rows.length) % 3], intro });
  return { slug, title, slides, caption, hashtags };
}

export const SETS: SlideSet[] = [
  set(1, "protein-math", "Protein math", [
    ["I stopped doing protein math in my head.", "app-home", "No more protein math."],
    ["Scan the label.", "app-scan-review"],
    ["Half the bag? Make it half.", "app-scan-details"],
    ["Protein's right there.", "app-home"],
  ], "I got tired of adding up protein in my head, so I built an app that reads the label and keeps the total. Coming soon for iPhone.", ["#ProteinTracking", "#FoodDiary", "#GymTok", "#MACROSapp"]),
  set(2, "serving-on-the-box", "The serving on the box", [
    ["\"Serving size\" isn't how much you ate.", "app-scan-review", "\"Serving size\" isn't your portion."],
    ["Eight servings. In this one box.", "app-scan-review"],
    ["Scan it, then log what you actually had.", "app-scan-details", "Log what you actually ate."],
    ["Then sit down and eat.", "app-home"],
  ], "A nutrition label lists one serving, and a box can hold eight. MACROS scans the label, then you log the amount you had. Coming soon for iPhone.", ["#NutritionLabels", "#FoodLogging", "#MacroTracking", "#MACROSapp"]),
  set(3, "why-my-email", "Why my email?", [
    ["Why does a food diary need my email?", undefined, "Why does a diary need my email?"],
    ["Mine doesn't. Open it and log.", "app-home"],
    ["Your diary stays on your phone.", "app-history"],
    ["Scanning is free.", "app-scan-review"],
  ], "I built MACROS so you can log food without making an account. Your diary stays on your phone. Coming soon for iPhone.", ["#FoodDiary", "#IndieApp", "#iPhoneApps", "#MACROSapp"], "I'm Juan, I built MACROS."),
  set(4, "breakfast-at-your-desk", "Breakfast at your desk", [
    ["Breakfast again. First meeting in five minutes.", "app-add-food", "Breakfast. Meeting in five."],
    ["Same yogurt as yesterday.", "app-add-food"],
    ["There it is.", "app-add-food"],
    ["Log it. Close the laptop lid.", "app-home"],
  ], "Same breakfast most mornings, so logging it should take a few taps. Coming soon for iPhone.", ["#Breakfast", "#FoodDiary", "#iPhoneApps", "#MACROSapp"]),
  set(5, "before-dinner", "Before dinner", [
    ["Wait, where am I on protein?", "app-home"],
    ["Dinner's nearly ready.", "app-home"],
    ["One glance at my phone.", "home-clean"],
    ["Right. Now I know.", "home-clean"],
  ], "A widget on the Home Screen shows where I am on protein before I cook dinner. Coming soon for iPhone.", ["#ProteinTracking", "#iPhoneWidgets", "#FoodDiary", "#MACROSapp"]),
];
