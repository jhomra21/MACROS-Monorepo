#!/bin/sh
set -eu

project_file=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project)
      project_file="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$project_file" ]; then
  echo "error: --project is required" >&2
  exit 1
fi

if [ ! -f "$project_file" ]; then
  echo "error: missing Xcode project file: $project_file" >&2
  exit 1
fi

package_refs=$(grep -c 'XCRemoteSwiftPackageReference' "$project_file" || true)
has_pods=0
has_carthage=0

if grep -q -E '\bPods\b|Podfile' "$project_file"; then
  has_pods=1
fi

if grep -q -E '\bCarthage\b|Cartfile' "$project_file"; then
  has_carthage=1
fi

if [ "$package_refs" -eq 0 ] && [ "$has_pods" -eq 0 ] && [ "$has_carthage" -eq 0 ]; then
  echo "dependency-inventory: no external package manager dependencies configured"
  exit 0
fi

echo "dependency-inventory: external dependencies detected" >&2
echo "- Swift Package references: $package_refs" >&2
echo "- CocoaPods markers present: $has_pods" >&2
echo "- Carthage markers present: $has_carthage" >&2
echo "manual review required: unused dependency detection should be upgraded now that third-party dependencies exist" >&2
exit 1
