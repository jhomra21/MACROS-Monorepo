# Goal Calculator Failure Modes

- Zero or negative height, weight, or age must not produce a plausible target.
- Ages above 120 must be rejected.
- NaN and infinite numeric inputs must be rejected.
- Below-minimum calorie targets must clamp to 1,200 kcal for female and unspecified profiles and 1,500 kcal for male profiles, while reporting the clamp.
- Macro preset percentages must total 100%.
- Rounded macro grams must recompute calorie totals and stay within 2% of the calorie target.
- Metric/imperial conversions must remain stable when converted back and forth.
- Unspecified sex must use the midpoint of male and female Mifflin-St Jeor constants.
- Weekly pace must map to kcal/day offsets inside -750...+500 (0.25, 0.5, 0.75 kg/week); gain stops at 0.5 kg/week (+500), and a gain draft must not keep an unoffered 0.75 pace.
- A pace must survive a save and reload through `BodyProfile` unchanged.
- Manual save must update one active `BodyProfile` (no duplicates) and keep the chosen macro preset.
