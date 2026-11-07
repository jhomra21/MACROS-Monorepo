#!/bin/bash
# usage: routing-matrix.sh; prints one line per request. Start one probe-dev.sh server per host first:
#   probe-dev.sh macrosios.com 8797; probe-dev.sh www.macrosios.com 8798
#   probe-dev.sh macros-web.jhonra121.workers.dev 8799
# "worker" is 1 when the response ran Worker code, 0 when the asset router answered alone.
set -u
DIST=$(dirname "$0")/../../../web/dist
css=$(cd "$DIST" && ls _astro/*.js | head -1)
img=$(cd "$DIST" && ls social/*.png | head -1)
mp4=$(cd "$DIST" && ls media/*.mp4 | head -1)
key=$(cd "$DIST" && ls | grep -E '^[0-9a-f]{32}\.txt$')
printf '%-34s %-6s %-44s %-4s %-6s %-46s %-40s %-14s %-18s %s\n' host method path code worker cache-control location x-robots-tag content-range content-type
row() { # host port method path [extra curl args]
  local host=$1 base=http://localhost:$2 method=$3 path=$4; shift 4
  local h
  h=$(curl -sS -o /dev/null -D - -X "$method" "$@" "$base$path" | tr -d '\r') || { echo "FAIL $host $path"; exit 1; }
  local code cc loc rob wk cr ct
  code=$(echo "$h" | awk 'NR==1{print $2}')
  cc=$(echo "$h" | grep -i '^cache-control:' | cut -d' ' -f2-)
  loc=$(echo "$h" | grep -i '^location:' | cut -d' ' -f2- | sed "s#^$base##")
  rob=$(echo "$h" | grep -i '^x-robots-tag:' | cut -d' ' -f2-)
  wk=$(echo "$h" | grep -ci '^x-probe-worker:')
  cr=$(echo "$h" | grep -i '^content-range:' | cut -d' ' -f2-)
  ct=$(echo "$h" | grep -i '^content-type:' | cut -d' ' -f2-)
  printf '%-34s %-6s %-44s %-4s %-6s %-46s %-40s %-14s %-18s %s\n' "$host" "$method" "$path" "$code" "$wk" "${cc:--}" "${loc:--}" "${rob:--}" "${cr:--}" "${ct:--}"
}
for entry in macrosios.com:8797 www.macrosios.com:8798 macros-web.jhonra121.workers.dev:8799; do
  host=${entry%:*} port=${entry#*:}
  for path in / /about /guides/how-to-set-macro-goals/?ref=ig /sitemap.xml /robots.txt /missing/ \
      "/$css" "/$img" /favicon.svg /apple-touch-icon.png "/$key" \
      /_astro/ /_astro/missing.abc123.js /social/ /social/missing.abc123.png /media/ /media/missing.abc123.mp4; do
    row "$host" "$port" GET "$path"
  done
  row "$host" "$port" GET /missing/ -H 'Sec-Fetch-Mode: navigate' -H 'Accept: text/html'
  row "$host" "$port" GET /_astro/missing.abc123.js -H 'If-None-Match: "x"' -H 'Range: bytes=0-10'
  row "$host" "$port" GET "/$mp4" -H 'Range: bytes=0-1'
  row "$host" "$port" GET /media/missing.abc123.mp4 -H 'Range: bytes=0-1'
  row "$host" "$port" POST /api/waitlist -H 'content-type: application/json' -H 'accept: application/json' --data '{"email":"bad"}'
done
