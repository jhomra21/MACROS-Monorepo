#!/bin/sh
set -eu

root=""
max_lines=300
max_function_lines=80

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      root="$2"
      shift 2
      ;;
    --max-lines)
      max_lines="$2"
      shift 2
      ;;
    --max-function-lines)
      max_function_lines="$2"
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
  line_count=$(wc -l < "$file_path" | tr -d ' ')
  if [ "$line_count" -gt "$max_lines" ]; then
    echo "$file_path: file has $line_count lines (limit $max_lines)" >> "$findings_file"
  fi

  grep -n -E 'TODO|FIXME|HACK|XXX|fatalError\(' "$file_path" | while IFS=: read -r line_number _; do
    echo "$file_path:$line_number: contains tech-debt marker" >> "$findings_file"
  done || true

  awk -v file_path="$file_path" -v max_function_lines="$max_function_lines" '
    function report_span(start_line, end_line) {
      if (start_line > 0) {
        span_length = end_line - start_line + 1
        if (span_length > max_function_lines) {
          printf "%s:%d-%d: function spans %d lines (limit %d)\n", file_path, start_line, end_line, span_length, max_function_lines
        }
      }
    }

    {
      if (active_start == 0 && $0 ~ /(^|[^[:alnum:]_])func[[:space:]]+[[:alnum:]_]+/) {
        active_start = NR
        brace_depth = gsub(/\{/, "{") - gsub(/\}/, "}")
        if (brace_depth <= 0) {
          report_span(active_start, NR)
          active_start = 0
          brace_depth = 0
        }
        next
      }

      if (active_start > 0) {
        brace_depth += gsub(/\{/, "{") - gsub(/\}/, "}")
        if (brace_depth <= 0) {
          report_span(active_start, NR)
          active_start = 0
          brace_depth = 0
        }
      }
    }
  ' "$file_path" >> "$findings_file"
done

if [ ! -s "$findings_file" ]; then
  echo "tech-debt: no configured debt markers found"
  exit 0
fi

echo "tech-debt: findings detected" >&2
cat "$findings_file" | while IFS= read -r line; do
  echo "- $line" >&2
done
exit 1
