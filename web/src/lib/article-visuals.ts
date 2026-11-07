// Not global, so `test()` keeps no state between calls. `split()` still splits on every match.
export const visualMarker = /<!-- visual:(calorie-flow|amdr|calculator|settings|profile|activity|review|scan-review|scan-grams|scan-details) -->/;
