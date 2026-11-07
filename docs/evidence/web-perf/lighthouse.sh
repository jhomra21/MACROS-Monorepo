#!/bin/bash
# usage: lighthouse.sh <origin> <outdir>; 3 performance-only runs per page for mobile (default) and desktop.
# Needs lighthouse@13.6.0 in build/perf-tools and a Playwright Chromium; override LH or CHROME_PATH if they differ.
ORIGIN=$1; OUT=$2; mkdir -p $OUT
export CHROME_PATH="${CHROME_PATH:-$(node -e "console.log(require('./build/perf-tools/node_modules/playwright').chromium.executablePath())")}"
LH="${LH:-build/perf-tools/node_modules/.bin/lighthouse}"
for page in home:/ guide:/guides/how-to-set-macro-goals/; do
  name=${page%%:*}; path=${page#*:}
  for mode in mobile desktop; do
    flag=""; [ $mode = desktop ] && flag="--preset=desktop"
    for run in 1 2 3; do
      $LH "$ORIGIN$path" $flag --only-categories=performance --output=json --output-path="$OUT/$name-$mode-$run.json" \
        --chrome-flags="--headless=new --no-sandbox" --quiet || echo "FAIL $name $mode $run"
    done
  done
done
