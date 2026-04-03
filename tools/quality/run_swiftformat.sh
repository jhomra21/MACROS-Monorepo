#!/bin/sh
set -eu

config_path=".swiftformat"
mode="lint"
target_path="cal-macro-tracker"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config)
      config_path="$2"
      shift 2
      ;;
    --mode)
      mode="$2"
      shift 2
      ;;
    --target)
      target_path="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$config_path" ]; then
  echo "error: missing SwiftFormat config: $config_path" >&2
  exit 1
fi

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "warning: swiftformat is not installed; skipping format check."
  echo "install with: brew install swiftformat"
  exit 0
fi

case "$mode" in
  lint)
    swiftformat "$target_path" --lint --config "$config_path"
    ;;
  format)
    swiftformat "$target_path" --config "$config_path"
    ;;
  *)
    echo "error: unsupported mode: $mode" >&2
    exit 1
    ;;
esac
