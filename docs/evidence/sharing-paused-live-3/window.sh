#!/bin/sh
# Flag window with video: record A, ON, capture, reopen twice, OFF. OFF always runs via the EXIT trap.
ROOT=/Users/juan/.t3/worktrees/cal-macro-tracker/sharing-ui
E=$ROOT/build/sharing-paused-live-3
O=$E/run3
mkdir -p $O
export DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer
A_UDID=918D29B9-97D3-42C0-9C47-00605E01E8DB
AA="/Users/juan/.t3/userdata/device/targets/t3-51aeb77ca2678a08ca8d8ee4/agent-device"
AB="/Users/juan/.t3/userdata/device/targets/t3-8f4cfa4dcce3281ce9eda78c/agent-device --session t3-9c6b70a8d77eb2eada509d98"
CVX="cd $ROOT/convex-backend && CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex"
T=$O/window-times.txt
mark() { echo "$1 $(date -u +%FT%TZ)" >> $T; }

off() {
  mark "OFF start"
  sh -c "$CVX import --replace --table settings ../build/sharing-paused-live-3/settings-empty.jsonl --yes" >> $O/import-off.log 2>&1
  mark "OFF done "
  sleep 6
  $AA screenshot $O/08-recovered-person-A.png --pixel-density 2 > /dev/null 2>&1
  $AA snapshot -i > $O/recovered-person-A-snapshot.txt 2>&1
  mark "recovered shot"
  kill -INT $REC 2>/dev/null
  wait $REC 2>/dev/null
}
trap off EXIT

: > $T
xcrun simctl io $A_UDID recordVideo --codec h264 --force $O/paused-window-A.mov > $O/record.log 2>&1 &
REC=$!
sleep 3
mark "recording started"

mark "ON start "
sh -c "$CVX import --append --table settings ../build/sharing-paused-live-3/settings-on.jsonl --yes" > $O/import-on.log 2>&1 || exit 1
mark "ON done  "

sleep 5
$AA screenshot $O/03-paused-person-A.png --pixel-density 2 > /dev/null 2>&1
$AA snapshot -i > $O/paused-person-A-snapshot.txt 2>&1
$AB screenshot $O/07-paused-person-B.png --pixel-density 2 > /dev/null 2>&1
$AB snapshot -i > $O/paused-person-B-snapshot.txt 2>&1
mark "person shots"

$AA back --settle > /dev/null 2>&1
sleep 2
$AA screenshot $O/04-paused-list-A.png --pixel-density 2 > /dev/null 2>&1
$AA snapshot -i > $O/paused-list-A-snapshot.txt 2>&1
mark "list shot"

mark "reopen 1 tap"
$AA press 200 205 > /dev/null 2>&1
sleep 3
$AA screenshot $O/05-paused-reopen-A.png --pixel-density 2 > /dev/null 2>&1
$AA snapshot -i > $O/paused-reopen-A-snapshot.txt 2>&1
mark "reopen 1 shot"

$AA back --settle > /dev/null 2>&1
sleep 2
mark "reopen 2 tap"
$AA press 200 205 > /dev/null 2>&1
sleep 3
mark "reopen 2 done"
