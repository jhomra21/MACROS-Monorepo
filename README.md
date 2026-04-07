# Cal Macro Tracker

A native SwiftUI calorie and macro tracking app for iPhone. No account required — all data stays on-device.

## Features

- **Dashboard** — daily calorie ring with protein / carbs / fat breakdown, compact summary on scroll, and full log entry list
- **Food logging** — log by servings or grams with deterministic macro math
- **Barcode scanning** — live camera or photo-based barcode detection via Vision/AVFoundation, with product lookup from Open Food Facts
- **Nutrition label scanning** — photo-based OCR via Vision text recognition with deterministic label parsing
- **Food search** — search USDA FoodData Central and Open Food Facts through a Cloudflare Worker proxy (no API key shipped in the client)
- **Common foods** — bundled seed database of common foods for quick offline logging
- **Custom foods** — create and edit your own food items
- **History** — calendar-based view of past daily logs with day summaries
- **Daily goals** — configurable calorie, protein, fat, and carb targets
- **Offline-first** — SwiftData persistence, cached lookups, and graceful network absence

## Requirements

- **Xcode 26+** (Swift 6, SwiftUI, SwiftData)
- macOS with Xcode command-line tools installed
- iPhone target (iOS)

### USDA Proxy Worker (optional, for food search)

- [Bun](https://bun.sh) (package manager / runtime)
- A [USDA FoodData Central API key](https://fdc.nal.usda.gov/api-key-signup) (free)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/) for local dev or Cloudflare deployment

## Project Structure

```
cal-macro-tracker/
├── App/                  # App shell, shared UI components, view extensions
├── CommonFoods/          # Bundled common_foods.json seed data
├── Data/
│   ├── Models/           # SwiftData models (FoodItem, LogEntry, DailyGoals)
│   └── Services/         # Repositories, bootstrap, nutrition math, persistence
├── Features/
│   ├── AddFood/          # Food search, USDA/OFF integration, log food flow
│   ├── Dashboard/        # Daily view with macro rings, log list, edit entry
│   ├── History/          # Calendar history and day summaries
│   ├── Scan/
│   │   ├── Barcode/      # Live scanner, image scanner, Open Food Facts client
│   │   ├── Label/        # Nutrition label OCR, parser, text recognizer
│   │   └── Shared/       # Camera picker, capture sheet, image loading
│   └── Settings/         # Goals editor, custom food editor
worker/
└── usda-proxy/           # Cloudflare Worker — Hono API proxying USDA + OFF searches
tools/
└── quality/              # Shell-based quality check scripts
```

## Build

Build for iOS Simulator:

```sh
xcodebuild -project "cal-macro-tracker.xcodeproj" \
  -scheme "cal-macro-tracker" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

## USDA Proxy Worker

The app searches packaged foods through a Cloudflare Worker that proxies USDA FoodData Central and Open Food Facts. The worker lives in `worker/usda-proxy/`.

### Local development

```sh
cd worker/usda-proxy
cp .dev.vars.example .dev.vars   # add your USDA_API_KEY
bun install
bun run dev                      # starts on http://127.0.0.1:8787
```

In debug simulator builds the app automatically points to `http://127.0.0.1:8787`.

### Deploy

```sh
cd worker/usda-proxy
bun run deploy
```

The `USDA_API_KEY` secret must be set in your Cloudflare Workers dashboard.

## Quality Checks

Run all checks:

```sh
make quality
```

Individual targets:

| Target | What it does |
|---|---|
| `make quality-build` | Verifies the Xcode target builds |
| `make quality-lint` | Runs SwiftLint (reports install instructions if missing) |
| `make quality-format-check` | Runs SwiftFormat in lint mode |
| `make format` | Applies SwiftFormat to app source |
| `make quality-dead` | Runs Periphery dead-code detection |
| `make quality-dup` | Scans for duplicated code blocks |
| `make quality-debt` | Flags TODO/FIXME/HACK, `fatalError`, oversized files/functions |
| `make quality-deps` | Reports dependency surface from the Xcode project |
| `make quality-n1` | Heuristic SwiftData N+1 query detection |
| `make quality-secrets` | Validates no real secrets leak into example env files |

### Optional tooling

- [SwiftLint](https://github.com/realm/SwiftLint) — `brew install swiftlint`
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) — `brew install swiftformat`
- [Periphery](https://github.com/peripheryapp/periphery) — `brew install periphery`

## Architecture

- **SwiftUI + SwiftData** — views use `@Query`, `@State`, `@Environment`, and `@Observable` directly; no view-model layer
- **Feature-organized** — code grouped by feature area, not by technical layer
- **Deterministic nutrition math** — macros computed from per-serving values × quantity; original label values preserved
- **Local-first** — SwiftData on-device persistence with no required network; remote search is additive
- **Thin adapters** — Open Food Facts client, USDA proxy client, and OCR recognizer are isolated I/O boundaries

## License

This project does not currently include a license file. All rights reserved unless otherwise stated.
