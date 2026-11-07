// Not global, so `test()` keeps no state between calls. `split()` still splits on every match.
export const visualMarker = /<!-- visual:(calorie-flow|amdr|calculator|serving-label|calorie-gap|protein-lookup|protein-units|resting-estimate|activity-multipliers|goal-offsets|rounding-window|settings|profile|activity|review|scan-review|scan-grams|scan-details) -->/;
