#!/bin/bash
# usage: measure.sh <outfile> <host> [n]; n requests per path (default 20), each a new curl process and connection.
# The CSS and AVIF paths are content-hashed; update them from the live HTML after a deploy changes them.
OUT=$1; HOST=$2; N=${3:-20}
PATHS="/ /about/ /support/ /guides/ /guides/how-to-set-macro-goals/ /privacy/ /_astro/SiteLayout.3BrxyvVc.css /_astro/logging.Bf0N-aaz_1Llrze.avif /favicon.svg /sitemap.xml"
: > "$OUT"
for p in $PATHS; do
  for i in $(seq 1 $N); do
    curl -sS -o /dev/null -H 'accept-encoding: br, gzip' -A 'macros-perf-audit/1.0' \
      -D /tmp/h.$$ -w "%{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{size_download} %{http_version} %{http_code}" \
      "https://$HOST$p" > /tmp/w.$$
    ray=$(grep -i '^cf-ray' /tmp/h.$$ | tr -d '\r' | awk '{print $2}')
    cs=$(grep -i '^cf-cache-status' /tmp/h.$$ | tr -d '\r' | awk '{print $2}')
    ce=$(grep -i '^content-encoding' /tmp/h.$$ | tr -d '\r' | awk '{print $2}')
    et=$(grep -ci '^etag' /tmp/h.$$)
    st=$(grep -i '^server-timing' /tmp/h.$$ | tr -d '\r' | cut -c1-120 | tr ' ' '_')
    echo "$HOST $p $i $(cat /tmp/w.$$) ray=$ray cache=${cs:-none} enc=${ce:-none} etag=$et st=${st:-none}" >> "$OUT"
  done
done
rm -f /tmp/h.$$ /tmp/w.$$
