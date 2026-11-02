#!/bin/sh
# usage: sheet.sh <video> <start_sec> <out.png>  -> 2.0s window at 15fps, 10x3 tiles (row-major, 1/15 s per tile)
V=$1; S=$2; OUT=$3
/opt/homebrew/bin/ffmpeg -v error -y -ss "$S" -t 2.0 -i "$V" \
  -vf "fps=15,scale=160:-1,tile=10x3:padding=2:margin=2" -frames:v 1 "$OUT"
