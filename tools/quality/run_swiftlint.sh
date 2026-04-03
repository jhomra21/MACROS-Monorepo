#!/bin/sh
set -eu

config_path=".swiftlint.yml"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config)
      config_path="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$config_path" ]; then
  echo "error: missing SwiftLint config: $config_path" >&2
  exit 1
fi

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "warning: swiftlint is not installed; skipping lint."
  echo "install with: brew install swiftlint"
  exit 0
fi

swiftlint lint --config "$config_path"
