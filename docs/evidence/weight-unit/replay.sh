#!/bin/sh
# Run only on the assigned demo simulator after device_open provides AGENT_DEVICE.
set -eu
cd /Users/juan/.t3/worktrees/cal-macro-tracker/weight-unit
: "${AGENT_DEVICE:?Set AGENT_DEVICE to the pinned command returned by T3 device_open}"
udid=F976E800-DA1F-4F20-B755-DFD964E33975
lock=/tmp/macros-sim-locks/$udid
mkdir -p /tmp/macros-sim-locks
attempt=0
until mkdir "$lock" 2>/dev/null; do
    attempt=$((attempt + 1))
    [ "$attempt" -le 60 ] || exit 1
    sleep 120
done
trap 'rmdir "$lock"' EXIT
evidence=docs/evidence/weight-unit
"$AGENT_DEVICE" open juan-test.cal-macro-tracker --relaunch
"$AGENT_DEVICE" press 'text="Open insights"' --settle
"$AGENT_DEVICE" press 'text="View weight log"' --settle
"$AGENT_DEVICE" press 'text="Log Weight"' --settle
"$AGENT_DEVICE" press 'text="pounds"' --settle
"$AGENT_DEVICE" snapshot -i > "$evidence/replay-sheet.txt"
field=$(awk '/\[text-field\]/ {print $1; exit}' "$evidence/replay-sheet.txt")
"$AGENT_DEVICE" fill "$field" 180 --settle
"$AGENT_DEVICE" press 'text="kilograms"' --settle
"$AGENT_DEVICE" snapshot -i > "$evidence/replay-converted.txt"
grep -F '81.6466266' "$evidence/replay-converted.txt"
"$AGENT_DEVICE" screenshot "$PWD/$evidence/replay-converted.png"
"$AGENT_DEVICE" press 'text="pounds"' --settle
"$AGENT_DEVICE" snapshot -i > "$evidence/replay-round-trip.txt"
grep -F '[text-field] "180"' "$evidence/replay-round-trip.txt"
"$AGENT_DEVICE" press 'text="Save"' --settle
"$AGENT_DEVICE" snapshot -i > "$evidence/replay-saved.txt"
grep -F '180.0 lb' "$evidence/replay-saved.txt"
group=$(xcrun simctl get_app_container "$udid" juan-test.cal-macro-tracker group.juan-test.cal-macro-tracker)
sqlite3 -header "$group/Library/Application Support/default.store" \
    'SELECT ZWEIGHTKG, ZSOURCERAW FROM ZWEIGHTENTRY ORDER BY ZRECORDEDAT DESC LIMIT 1;' \
    > "$evidence/replay-stored-kg.txt"
grep -F '81.6466266|manual' "$evidence/replay-stored-kg.txt"
