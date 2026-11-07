#!/bin/sh
# Read-only snapshot of the MACROS SwiftData store on a simulator.
# Usage: sh db-snapshot.sh <UDID> <label> [outdir]
set -eu
UDID="$1"
LABEL="$2"
OUT="${3:-build/evidence/2026-11-07-delete-saved-foods}"
STORE=$(find "$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Containers/Shared/AppGroup" -name default.store | head -1)
[ -n "$STORE" ] || { echo "store not found" >&2; exit 1; }
mkdir -p "$OUT"
q() { sqlite3 "file:$STORE?mode=ro" "$1"; }
{
  echo "# $LABEL"
  echo "## saved foods by source"
  q "SELECT ZSOURCE, count(*) FROM ZFOODITEM GROUP BY ZSOURCE ORDER BY ZSOURCE;"
  echo "## custom food names"
  q "SELECT ZNAME FROM ZFOODITEM WHERE ZSOURCE <> 'common' ORDER BY ZNAME;"
  echo "## meals and components"
  q "SELECT m.ZNAME, f.ZNAME FROM ZMEAL m JOIN ZMEALCOMPONENT c ON c.ZMEALID = m.ZID LEFT JOIN ZFOODITEM f ON f.ZID = c.ZFOODITEMID ORDER BY 1, 2;"
  echo "## log entries: count, kcal, protein, carbs, fat"
  q "SELECT count(*), round(sum(ZCALORIESCONSUMED),3), round(sum(ZPROTEINCONSUMED),3), round(sum(ZCARBSCONSUMED),3), round(sum(ZFATCONSUMED),3) FROM ZLOGENTRY;"
  echo "## log entries per food name (with whether the saved food still exists)"
  q "SELECT e.ZFOODNAME, count(*), round(sum(e.ZCALORIESCONSUMED),3), CASE WHEN e.ZFOODITEMID IS NULL THEN 'no-food-link' WHEN f.ZID IS NULL THEN 'food-deleted' ELSE 'food-present' END FROM ZLOGENTRY e LEFT JOIN ZFOODITEM f ON f.ZID = e.ZFOODITEMID GROUP BY e.ZFOODNAME, f.ZID IS NULL ORDER BY 1;"
  echo "## log entry digest (identity, snapshot and consumed values, updatedAt, health version)"
  q "SELECT hex(ZID), hex(ZFOODITEMID), hex(ZMEALID), ZDATELOGGED, ZFOODNAME, ZSERVINGDESCRIPTION, ZCALORIESPERSERVING, ZCALORIESCONSUMED, ZPROTEINCONSUMED, ZCARBSCONSUMED, ZFATCONSUMED, ZUPDATEDAT, ZHEALTHSYNCVERSION FROM ZLOGENTRY ORDER BY hex(ZID);" | shasum -a 256 | cut -d' ' -f1
  echo "## logged meal snapshot digest"
  q "SELECT * FROM ZLOGGEDMEALCOMPONENTSNAPSHOT ORDER BY Z_PK;" | shasum -a 256 | cut -d' ' -f1
} > "$OUT/db-$LABEL.txt"
cat "$OUT/db-$LABEL.txt"
