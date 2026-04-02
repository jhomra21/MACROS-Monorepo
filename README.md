# cal-macro-tracker

Native SwiftUI calorie and macro tracker with local-first storage.

## Requirements
- Xcode 26+
- macOS with the Xcode command line tools installed
- POSIX shell tools available on macOS (`sh`, `bash`, `awk`, `grep`, `find`)

## Project Structure
- `cal-macro-tracker/` — app source grouped by feature and app/data concerns
- `cal-macro-tracker.xcodeproj/` — Xcode project
- `tools/quality/` — lightweight repository quality checks
- `skills/` — local agent skill packs used during development

## Build
```sh
xcodebuild -project "cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'platform=macOS' build
```

## Quality Checks
Run all repo checks:
```sh
make quality
```

Run individual checks:
```sh
make quality-build
make quality-lint
make quality-format-check
make format
make quality-dead
make quality-dup
make quality-debt
make quality-deps
make quality-n1
```

## Current Quality Foundation
- `quality-build` verifies the Xcode target still builds.
- `quality-lint` runs SwiftLint when installed and otherwise reports how to install it.
- `quality-format-check` runs SwiftFormat in lint mode to verify formatting.
- `format` applies SwiftFormat to the app source tree.
- `quality-dead` runs Periphery when installed and otherwise reports how to install it.
- `quality-dup` scans Swift files for repeated normalized blocks using shell tooling.
- `quality-debt` flags TODO/FIXME/HACK markers, `fatalError`, and oversized files/functions.
- `quality-deps` reports the current dependency surface from the Xcode project.
- `quality-n1` runs heuristic SwiftData fetch checks for suspicious repeated query patterns.
