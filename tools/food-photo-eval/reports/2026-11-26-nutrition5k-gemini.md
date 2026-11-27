# Nutrition5k bake-off: Gemini cloud arms (2026-11-26)

Research only. No app code changed. Same 60 dishes, prompt, schema, truth and matcher as [the Apple report](2026-11-26-nutrition5k-apple.md).

## Summary

- **Gemini 3.5 Flash-Lite clears every bar the Apple report proposed** except recognizing oils and dressings. All 60 dishes answered. Dish kcal MAPE 28.4% (median 22.6%), 45.0% within ±20%, mass MAPE 25.2% (constant-guess baseline 37.5%), mass recall 73.3%, count precision 80.7%, p50 latency 1.8 s.
- **Oils are still invisible.** Olive oil was missed in all 21 dishes that contain it, the same as on-device. The app needs a "added oil or dressing?" prompt regardless of model.
- **Gemini 3.8 Flash is incomplete (21 of 60).** The new MACROS key hit its quota ("You exceeded your current quota") after 21 dishes, plus some "high demand" errors. On those 21 it looks slightly better (kcal MAPE 23.2%, 57.1% within ±20%), but only 2 of them are 6+ ingredient plates, so it is not comparable. Its latency (p50 25 s, p95 85 s) rules it out for a scan flow. Owner chose not to finish it.
- OpenAI and Cloudflare arms were not run (owner chose Gemini only).

## Results

| Metric | Apple on-device | Gemini 3.5 Flash-Lite | Gemini 3.8 Flash (21/60) | Proposed bar |
|---|---:|---:|---:|---|
| Answered | 60 | 60 | 21 | |
| kcal MAPE | 75.2% | 28.4% | 23.2% | < ~40% |
| kcal median APE | 60.7% | 22.6% | 17.9% | |
| Within ±20% kcal (all dishes) | 15.0% | 45.0% | 20.0% | > 40% |
| Mass MAPE | 50.0% | 25.2% | 19.1% | < 37.5% |
| Mass recall | 48.1% | 73.3% | 94.4% | well above 48% |
| Count precision | 63.8% | 80.7% | 87.7% | > 64% |
| Matched-item gram median APE (≥ 10 g) | 57.9% | 29.3% | 21.2% | |
| p50 / p95 latency | 2.9 / 6.4 s | 1.8 / 2.6 s | 25.0 / 85.3 s | fits a scan flow |

Flash-Lite kcal MAPE by ingredient count: 29.4% (1–2), 26.8% (3–5), 29.0% (6+), 20 dishes each. Unlike on-device, it does not degrade on complex plates.

Name matches for Flash-Lite: 85 exact, 12 alias, 39 contains, 2 fuzzy (138 pairs). "Contains" is a larger share than on-device because Gemini returns descriptive names ("roasted potato", "brown rice vegetable"); see the matcher caveat in the Apple report.

Token use for the 60 Flash-Lite requests: about 75k input and 13k output tokens. No cost threshold has been set; at this size cost is negligible.

Most missed by Flash-Lite: olive oil ×21 (83 g), salt ×18, garlic ×14, pepper ×9, vinegar ×9, onions ×7. Most frequent unmatched predictions: roasted potato ×3, strawberry ×2, blueberry ×2, mozzarella ×2.

## Run notes

- Run on Windows. `cloud/run.ts` now uses ffmpeg there to produce the same 1024 px longest-side JPEG that `sips -Z 1024` produces on macOS (source images are 640×480, so both upscale).
- The first run failed every Gemini request: `responseSchema` takes Gemini's OpenAPI subset and rejected the JSON Schema (`$schema`, `additionalProperties`, nullable type arrays). The runner now sends it as `responseJsonSchema`.
- Added retry with linear backoff (15 s × attempt, 6 attempts) for quota, rate-limit and overload errors, and `--resume` to rerun only photos without a valid saved result. Flash-Lite needed two resumed passes; failures were never scored as answers.
- One run per photo, default sampling, no known-identity mode for cloud (the runner still lacks it).

## Caveats

All caveats in the Apple report apply: cafeteria food, overhead 640×480 photos, n = 60 (about ±10 points on a proportion), matcher written by us. Results on phone photos of home meals may differ, and home photos sent to Google would need the privacy decisions still open with the owner (retention, consent, fair-use cap).

## Reproduce

```sh
cd tools/food-photo-eval
GEMINI_API_KEY=... bun run cloud/run.ts --dataset dataset/nutrition5k          # add --resume to fill failures
bun run score.ts --dataset dataset/nutrition5k --results results
```

Raw per-photo results and scores: [`2026-11-26-nutrition5k-gemini-results/`](2026-11-26-nutrition5k-gemini-results/).
