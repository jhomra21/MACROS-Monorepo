# MACROS

MACROS-Monorepo has three shipped surfaces:

- `cal-macro-tracker/` — the native SwiftUI iPhone app with SwiftData persistence and WidgetKit widgets
- `worker/usda-proxy/` — a Cloudflare Worker API for USDA and Open Food Facts search
- `web/` — an Astro site for the product page, privacy/support pages, and support form handling 
  - `https://macros-web.jhonra121.workers.dev/`

The app stays local-first: no required account, on-device data by default, and optional network-backed search layered on top.

## Screenshots

### Home

<p align="center">
  <img src="web/src/assets/app-images/home1-light.jpeg" alt="Home screen overview in light mode" width="220" />
  &nbsp;&nbsp;
  <img src="web/src/assets/app-images/home1.jpeg" alt="Home screen overview" width="220" />
  &nbsp;&nbsp;
  <img src="web/src/assets/app-images/home2.jpeg" alt="Home screen scrolled" width="220" />
</p>

### Logging

<p align="center">
  <img src="web/src/assets/app-images/add-search.jpeg" alt="Food search" width="220" />
</p>

### History

<p align="center">
  <img src="web/src/assets/app-images/calendar-closed-light.jpeg" alt="Calendar collapsed in light mode" width="220" />
  &nbsp;&nbsp;
  <img src="web/src/assets/app-images/calendar-open.jpeg" alt="Calendar expanded" width="220" />
</p>

## Features

- **Dashboard** — daily calorie ring with protein / carbs / fat breakdown, compact summary on scroll, and full log entry list
- **Food logging** — log by servings or grams with deterministic macro math
- **Widgets** — Home Screen widget plus Lock Screen accessory widget for daily macro progress
- **Barcode scanning** — live camera or photo-based barcode detection via Vision/AVFoundation, with product lookup from Open Food Facts
- **Nutrition label scanning** — photo-based OCR via Vision text recognition with deterministic label parsing
- **Food search** — search USDA FoodData Central and Open Food Facts through a Cloudflare Worker
- **Common foods** — bundled seed database of common foods for quick offline logging
- **Custom foods** — create and edit your own food items
- **History** — calendar-based view of past daily logs with day summaries
- **Daily goals** — configurable calorie, protein, fat, and carb targets
- **Offline-first** — SwiftData persistence, cached lookups, and graceful network absence

## Workspace Overview

| Path | Stack | Purpose |
|---|---|---|
| `cal-macro-tracker/` | SwiftUI, SwiftData, WidgetKit | Native iPhone calorie and macro tracking app |
| `worker/usda-proxy/` | Cloudflare Workers, Hono, TypeScript, Bun | Search API proxy for packaged foods and USDA lookups |
| `web/` | Astro, Cloudflare, TypeScript, Bun, D1 | Marketing site plus support form flow |

## Requirements

### Apple app

- **Xcode 26+** (Swift 6, SwiftUI, SwiftData, WidgetKit)
- macOS with Xcode command-line tools installed
- iPhone Simulator or device target

### Worker and web

- [Bun](https://bun.sh) for package management and scripts
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/) for local dev and deployment
- A [USDA FoodData Central API key](https://fdc.nal.usda.gov/api-key-signup) for `worker/usda-proxy`
- Node.js `>=22.12.0` for the Astro site runtime/tooling expectations

## Project Structure

```
cal-macro-tracker/
├── cal-macro-tracker/          # Apple app source
│   ├── App/                    # App shell, routing, widget/shared entry points
│   ├── CalMacroWidget/         # WidgetKit extension, including Lock Screen widget
│   ├── CommonFoods/            # Bundled common_foods.json seed data
│   ├── Data/                   # SwiftData models and services
│   ├── Features/               # Add Food, Dashboard, History, Scan, Settings
│   └── Shared/                 # Shared UI, formatting, and app helpers
├── worker/
│   └── usda-proxy/             # Cloudflare Worker API for USDA + OFF search
├── web/
│   ├── src/                    # Astro pages, layouts, components, support API
│   ├── migrations/             # D1 schema migrations for support requests
│   └── public/                 # Static site assets
├── tools/
│   └── quality/                # Shell-based repo quality checks
├── Makefile                    # Apple-side quality commands
└── cal-macro-tracker.xcodeproj # Xcode project for app and widget targets
```

## Local Development

### iPhone app

```sh
xcodebuild -project "cal-macro-tracker.xcodeproj" \
  -scheme "cal-macro-tracker" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

The Apple project includes the main `cal-macro-tracker` app scheme and the `CalMacroWidget` widget extension scheme.

### Worker API

The app searches packaged foods through `worker/usda-proxy/`, a Cloudflare Worker that proxies USDA FoodData Central and Open Food Facts.

```sh
cd worker/usda-proxy
cp .dev.vars.example .dev.vars   # add your USDA_API_KEY
bun install
bun run dev                      # starts on http://127.0.0.1:8787
bun run check
```

In debug simulator builds the app automatically points to `http://127.0.0.1:8787`.

```sh
cd worker/usda-proxy
bun run deploy
```

The `USDA_API_KEY` secret must be set in your Cloudflare Workers dashboard.

### Astro web app

The Astro site in `web/` powers the product landing page and support/privacy flows. The support form posts into a D1-backed API route.

```sh
cd web
bun install
bun run dev
bun run check
bun run build
```

For deployment and schema changes:

```sh
cd web
bun run db:migrations:apply:local
bun run deploy
```

## Quality Checks

Apple app quality commands:

```sh
make quality
```

App-specific targets:

| Target | What it does |
|---|---|
| `make quality-build` | Verifies the Xcode target builds |
| `make quality-format-check` | Runs the official `swift-format` formatter in lint mode |
| `make format` | Applies the official `swift-format` formatter to app source |
| `make quality-dead` | Runs Periphery dead-code detection |
| `make quality-dup` | Scans for duplicated code blocks |
| `make quality-debt` | Flags TODO/FIXME/HACK, `fatalError`, oversized files/functions |
| `make quality-deps` | Reports dependency surface from the Xcode project |
| `make quality-n1` | Heuristic SwiftData N+1 query detection |
| `make quality-secrets` | Validates no real secrets leak into example env files |

Type checks outside the Xcode project:

| Package | Command |
|---|---|
| `worker/usda-proxy` | `bun run check` |
| `web` | `bun run check` |

### Optional tooling

- [swift-format](https://github.com/swiftlang/swift-format) — official Swift formatter — `brew install swift-format`
- [Periphery](https://github.com/peripheryapp/periphery) — `brew install periphery`

## Architecture

- **SwiftUI + SwiftData** — the app uses feature-scoped SwiftUI state and local persistence for logging and history
- **WidgetKit surfaces** — daily macro progress is exposed through both the main widget and a Lock Screen accessory widget
- **Worker-backed search** — the Hono Worker isolates USDA/Open Food Facts search, validation, and caching
- **Astro + Cloudflare web** — the site stays lightweight while handling support submissions through a D1-backed endpoint
- **Local-first core** — nutrition logs remain on-device; remote services are additive rather than required

## License

This project does not currently include a license file. All rights reserved unless otherwise stated.
