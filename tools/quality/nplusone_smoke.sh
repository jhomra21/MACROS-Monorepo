#!/bin/sh
set -eu

root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      root="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$root" ]; then
  echo "error: --root is required" >&2
  exit 1
fi

findings_file=$(mktemp)
trap 'rm -f "$findings_file"' EXIT HUP INT TERM

find "$root" -type f -name '*.swift' \
  ! -path '*/.git/*' \
  ! -path '*/DerivedData/*' \
  ! -path '*/.build/*' \
  ! -path '*/build/*' | LC_ALL=C sort | while IFS= read -r file_path; do
  if printf '%s' "$file_path" | grep -Eq '(Row|Cell|Item)\.swift$' && grep -n '@Query' "$file_path" >/dev/null; then
    grep -n '@Query' "$file_path" | while IFS=: read -r line_number _; do
      echo "$file_path:$line_number: @Query declared in row-like view" >> "$findings_file"
    done
  fi

  awk -v file_path="$file_path" '
    /modelContext\.fetch[[:space:]]*\(/ {
      fetch_line = NR
      fetch_hits[fetch_line] = 1
    }
    /for[[:space:]]+[[:alnum:]_]+[[:space:]]+in|ForEach[[:space:]]*\(/ {
      loop_hits[NR] = 1
    }
    END {
      for (fetch_line in fetch_hits) {
        for (loop_line in loop_hits) {
          delta = fetch_line - loop_line
          if (delta < 0) {
            delta = -delta
          }
          if (delta <= 6) {
            printf "%s:%d: fetch near loop/ForEach\n", file_path, fetch_line
            break
          }
        }
      }
    }
  ' "$file_path" >> "$findings_file"
done

if [ ! -s "$findings_file" ]; then
  echo "nplusone-smoke: no suspicious repeated fetch patterns detected"
  exit 0
fi

echo "nplusone-smoke: suspicious fetch patterns detected" >&2
cat "$findings_file" | while IFS= read -r line; do
  echo "- $line" >&2
done
exit 1
