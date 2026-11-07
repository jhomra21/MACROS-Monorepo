// Not global, so `test()` keeps no state between calls. `split()` still splits on every match.
export const visualMarker = /<!-- visual:(calorie-flow|amdr|calculator|serving-label|calorie-gap|protein-lookup|carb-factors|label-rounding|protein-bar-steps|settings|profile|activity|review|scan-review|scan-grams|scan-details) -->/;
