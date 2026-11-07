#!/bin/bash
# usage: lighthouse.sh <origin> <outdir>; 3 performance-only runs per page for mobile (default) and desktop.
# Needs lighthouse@13.6.0 in build/perf-tools and a Playwright Chromium; override LH or CHROME_PATH if they differ.
# Exits nonzero if any run fails or leaves no report, after attempting every run.
set -u
ORIGIN=$1; OUT=$2; mkdir -p "$OUT" || exit 1
CHROME_PATH="${CHROME_PATH:-$(node -e "console.log(require('./build/perf-tools/node_modules/playwright').chromium.executablePath())")}" || exit 1
export CHROME_PATH
LH="${LH:-build/perf-tools/node_modules/.bin/lighthouse}"
failed=0
for page in home:/ guide:/guides/how-to-set-macro-goals/; do
  name=${page%%:*}; path=${page#*:}
  for mode in mobile desktop; do
    flag=""; [ $mode = desktop ] && flag="--preset=desktop"
    for run in 1 2 3; do
      report="$OUT/$name-$mode-$run.json"
      rm -f "$report"
      if ! "$LH" "$ORIGIN$path" $flag --only-categories=performance --output=json --output-path="$report" \
        --chrome-flags="--headless=new --no-sandbox" --quiet || [ ! -s "$report" ]; then
        echo "FAIL $name $mode $run" >&2; failed=1
      fi
    done
  done
done
exit $failed
