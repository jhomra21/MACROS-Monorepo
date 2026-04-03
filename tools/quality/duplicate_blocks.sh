#!/bin/sh
set -eu

root=""
min_lines=12

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      root="$2"
      shift 2
      ;;
    --min-lines)
      min_lines="$2"
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

blocks_file=$(mktemp)
duplicates_file=$(mktemp)
trap 'rm -f "$blocks_file" "$duplicates_file"' EXIT HUP INT TERM

find "$root" -type f -name '*.swift' \
  ! -path '*/.git/*' \
  ! -path '*/DerivedData/*' \
  ! -path '*/.build/*' \
  ! -path '*/build/*' | LC_ALL=C sort | while IFS= read -r file_path; do
  awk -v min_lines="$min_lines" '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }

    {
      line = trim($0)
      if (line == "" || line ~ /^\/\//) {
        normalized[NR] = ""
      } else {
        gsub(/[[:space:]]+/, " ", line)
        normalized[NR] = line
      }
      total = NR
    }

    END {
      for (start = 1; start <= total - min_lines + 1; start++) {
        has_blank = 0
        block = ""

        for (offset = 0; offset < min_lines; offset++) {
          value = normalized[start + offset]
          if (value == "") {
            has_blank = 1
            break
          }
          block = block value "\034"
        }

        if (!has_blank) {
          print start "\t" block
        }
      }
    }
  ' "$file_path" | while IFS="$(printf '\t')" read -r start block; do
    digest=$(printf '%s' "$block" | shasum | awk '{print $1}')
    printf '%s\t%s:%s\n' "$digest" "$file_path" "$start" >> "$blocks_file"
  done
done

LC_ALL=C sort "$blocks_file" | awk -F '\t' '
  function flush_group() {
    if (count > 1) {
      printf "- block starting at %s\n", matches[1]
      for (match_index = 2; match_index <= count; match_index++) {
        printf "  matches %s\n", matches[match_index]
      }
    }
  }

  {
    digest = $1
    location = $2

    if (current_digest != "" && digest != current_digest) {
      flush_group()
      count = 0
    }

    current_digest = digest
    count += 1
    matches[count] = location
  }

  END {
    flush_group()
  }
' > "$duplicates_file"

if [ ! -s "$duplicates_file" ]; then
  echo "duplicate-blocks: no repeated Swift blocks detected"
  exit 0
fi

echo "duplicate-blocks: repeated Swift blocks detected" >&2
cat "$duplicates_file" >&2
exit 1
