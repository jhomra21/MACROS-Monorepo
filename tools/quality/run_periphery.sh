#!/bin/sh
set -eu

config_path=""

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

if [ -z "$config_path" ]; then
  echo "error: --config is required" >&2
  exit 1
fi

if [ ! -f "$config_path" ]; then
  echo "error: missing config file: $config_path" >&2
  exit 1
fi

if ! command -v periphery >/dev/null 2>&1; then
  echo "warning: periphery is not installed; skipping dead code scan."
  echo "install with: brew install peripheryapp/periphery/periphery"
  exit 0
fi

periphery scan --config "$config_path"
