#!/usr/bin/env bash
# Run the Swift tests and enforce coverage for the core target.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

swift test --enable-code-coverage

profdata="$(find .build -path '*debug*' -name 'default.profdata' -print -quit)"
test_binary="$(find .build -path '*debug*' -type f -name 'MisetePackageTests.xctest' -print -quit)"
if [[ -z "$profdata" || -z "$test_binary" ]]; then
  echo "Could not locate Swift coverage output." >&2
  exit 1
fi

coverage_json="$(xcrun llvm-cov export "$test_binary" -instr-profile="$profdata")"
core_coverage="$(printf '%s' "$coverage_json" | python3 -c '
import json, sys
report = json.load(sys.stdin)
files = [entry for entry in report["data"][0]["files"] if "/Sources/MiseteCore/" in entry["filename"]]
if not files:
    raise SystemExit("No MiseteCore files found in coverage report")
covered = sum(entry["summary"]["lines"]["covered"] for entry in files)
count = sum(entry["summary"]["lines"]["count"] for entry in files)
if count == 0:
    raise SystemExit("MiseteCore has no executable lines in coverage report")
print(f"{covered * 100 / count:.2f}")
')"

echo "MiseteCore line coverage: $core_coverage%"
python3 - "$core_coverage" <<'PY'
import sys
coverage = float(sys.argv[1])
if coverage < 80:
    raise SystemExit(f"MiseteCore coverage {coverage:.2f}% is below the required 80%")
PY
