#!/bin/sh
# Read-only snapshot of the MACROS SwiftData store on a simulator.
# Usage: sh db-snapshot.sh <UDID> <label> [outdir]
# Writes db-<label>.txt plus full row dumps (db-<label>-<table>.txt) that the digests are computed from.
set -eu
UDID="$1"
LABEL="$2"
OUT="${3:-build/evidence/2026-11-07-delete-saved-foods}"
STORE=$(find "$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Containers/Shared/AppGroup" -name default.store | head -1)
[ -n "$STORE" ] || { echo "store not found" >&2; exit 1; }
mkdir -p "$OUT"
q() { sqlite3 "file:$STORE?mode=ro" "$1"; }
# Every column of every row, as SQL literals: quote() keeps NULL distinct from '' and renders REALs so they round-trip.
# Backslashes and newlines inside values are escaped so each row is exactly one line.
# $3 lists columns to leave out (SwiftData bookkeeping that changes when a row is re-inserted).
dump() {
  cols=$(q "SELECT group_concat('replace(replace(quote(' || name || '), ''\'', ''\\''), char(10), ''\n'')', ' || ''|'' || ') FROM pragma_table_info('$1') WHERE name NOT IN (${3:-''});")
  names=$(q "SELECT group_concat(name, '|') FROM pragma_table_info('$1') WHERE name NOT IN (${3:-''});")
  { echo "$names"; q "SELECT $cols FROM $1 $2 ORDER BY hex(ZID);"; } > "$OUT/db-$LABEL-$1.txt"
  echo "$(($(wc -l < "$OUT/db-$LABEL-$1.txt") - 1)) rows, $(echo "$names" | tr '|' '\n' | wc -l | tr -d ' ') columns, sha256 $(shasum -a 256 < "$OUT/db-$LABEL-$1.txt" | cut -d' ' -f1)"
}
{
  echo "# $LABEL"
  echo "## saved foods by source"
  q "SELECT ZSOURCE, count(*) FROM ZFOODITEM GROUP BY ZSOURCE ORDER BY ZSOURCE;"
  echo "## saved food names"
  q "SELECT ZSOURCE, ZNAME FROM ZFOODITEM WHERE ZSOURCE <> 'common' ORDER BY ZNAME;"
  echo "## meals and components"
  q "SELECT m.ZNAME, coalesce(f.ZNAME, '<missing food>') FROM ZMEAL m JOIN ZMEALCOMPONENT c ON c.ZMEALID = m.ZID LEFT JOIN ZFOODITEM f ON f.ZID = c.ZFOODITEMID ORDER BY 1, 2;"
  echo "## log entries: count, kcal, protein, carbs, fat"
  q "SELECT count(*), round(sum(ZCALORIESCONSUMED),3), round(sum(ZPROTEINCONSUMED),3), round(sum(ZCARBSCONSUMED),3), round(sum(ZFATCONSUMED),3) FROM ZLOGENTRY;"
  echo "## log entries per food name (with whether the saved food still exists)"
  q "SELECT e.ZFOODNAME, count(*), round(sum(e.ZCALORIESCONSUMED),3), CASE WHEN e.ZFOODITEMID IS NULL THEN 'no-food-link' WHEN f.ZID IS NULL THEN 'food-deleted' ELSE 'food-present' END FROM ZLOGENTRY e LEFT JOIN ZFOODITEM f ON f.ZID = e.ZFOODITEMID GROUP BY e.ZFOODNAME, f.ZID IS NULL ORDER BY 1;"
  echo "## ZLOGENTRY, every column"
  dump ZLOGENTRY ""
  echo "## ZLOGGEDMEALCOMPONENTSNAPSHOT, every column"
  dump ZLOGGEDMEALCOMPONENTSNAPSHOT ""
  echo "## saved foods (non-common ZFOODITEM), every column except Z_PK/Z_ENT/Z_OPT"
  dump ZFOODITEM "WHERE ZSOURCE <> 'common'" "'Z_PK','Z_ENT','Z_OPT'"
} > "$OUT/db-$LABEL.txt"
cat "$OUT/db-$LABEL.txt"
