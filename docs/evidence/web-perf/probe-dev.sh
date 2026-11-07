#!/bin/bash
# usage: probe-dev.sh <host> <port>; serves the built web/dist with the real wrangler.jsonc routing, but with
# probe-worker.ts as main so routing-matrix.sh can tell Worker responses from asset-router responses.
# --local-upstream makes the Worker and _headers see <host>, as on that custom domain; a Host header
# alone does not. Run `bun run build` in web/ first. The generated config lives in ignored web/.wrangler/.
set -euo pipefail
cd "$(dirname "$0")/../../../web"
mkdir -p .wrangler
sed -e 's#"main": "./src/worker.ts"#"main": "../../docs/evidence/web-perf/probe-worker.ts"#' \
    -e 's#"\./dist"#"../dist"#' -e 's#"\./migrations"#"../migrations"#' \
    -e 's#"\./node_modules/#"../node_modules/#' wrangler.jsonc > ".wrangler/probe-$1.jsonc"
grep -q 'probe-worker.ts' ".wrangler/probe-$1.jsonc" && grep -q '"../dist"' ".wrangler/probe-$1.jsonc"
exec bunx wrangler dev --config ".wrangler/probe-$1.jsonc" --local-upstream "$1" --port "$2"
