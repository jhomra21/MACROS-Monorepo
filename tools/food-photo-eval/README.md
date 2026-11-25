# Food photo evaluation

Research-only tooling for comparing meal-photo food identification and portion estimates. It is not part of the MACROS app, app target, or test targets, and it never returns calories from a model. The scorer computes calories from the bundled `cal-macro-tracker/CommonFoods/common_foods.json` data by scaling its per-serving calories by grams consumed and `gramsPerServing` (equivalent to deriving calories per 100 g).

## Requirements

- Bun 1.2+ and `sips` (included with macOS)
- Swift 6.2 and Xcode 27 / macOS 27 SDK for Apple Foundation Models
- Optional cloud credentials: `GEMINI_API_KEY`, `OPENAI_API_KEY`, and `CLOUDFLARE_ACCOUNT_ID` + `CLOUDFLARE_API_TOKEN`

Install TypeScript tooling once:

```sh
cd tools/food-photo-eval
bun install
```

## Workflow

1. Follow [`dataset/README.md`](dataset/README.md) to collect photos and weighed truth.
2. Place photos in a dataset folder, such as `dataset/photos/`, and matching truth JSON files in `dataset/truth/`. Filenames without extensions must match.
3. Add credentials to your shell environment using a secure secret manager. Never put keys in files or commit them.
4. Run cloud arms. Missing credentials are skipped:

   ```sh
   bun run cloud/run.ts --dataset dataset
   ```

   `--dry-run` confirms which arms would run without making network requests.
5. Run Apple arms on a Mac with Apple Intelligence enabled:

   ```sh
   cd apple
   swift run FoodPhotoEval --dataset ../dataset --results ../results
   ```

6. Score all result folders:

   ```sh
   cd ..
   bun run score.ts --dataset dataset --results results
   ```

The report is written to `results/report.md`. Inspect raw model responses and verify all ground-truth weights before drawing conclusions. Each photo is an independent scan, and paired angles should be evaluated as separate examples.

## Model arms

The cloud runner pins Gemini 3.5 Flash-Lite and Gemini 3.8 Flash, OpenAI GPT-5.4 mini, and an optional Cloudflare Workers AI Clairic pilot. Model identifiers are at the top of `cloud/run.ts`; prices and their sources are in `pricing.json`. Update those when the vendors change their catalogs or rates. Clairic does not expose the same strict JSON Schema response mode, so it uses typed fields to request JSON food entries and the result is checked against the shared output schema after the call.

The Apple command runs `SystemLanguageModel` (on-device) and `PrivateCloudComputeLanguageModel` separately. The private-cloud arm may be unavailable or quota-limited; the runner records that outcome rather than silently substituting another model.

Cloud calls transmit the selected photos and prompt to the configured providers. Use only photos you have permission to submit. There are no keys or photos bundled with this tooling.
