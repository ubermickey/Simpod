#!/bin/bash
# append-trend-log.sh — Append one row to Docs/TREND-LOG.csv from completion loop summary
# Usage: ./scripts/append-trend-log.sh [path/to/summary.json]
set -euo pipefail
cd "$(dirname "$0")/.."

SUMMARY="${1:-.build/completion-loop/summary.json}"
CSV="Docs/TREND-LOG.csv"

if [ ! -f "$SUMMARY" ]; then
  echo "Error: Summary file not found: $SUMMARY"
  exit 1
fi

# Create header if file doesn't exist
if [ ! -f "$CSV" ]; then
  mkdir -p "$(dirname "$CSV")"
  echo "date,cycles,passed,failed,hard_stop,duration_s" > "$CSV"
fi

# Extract fields from summary.json
DATE=$(date +%Y-%m-%d)
CYCLES=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('total_cycles', 0))")
PASSED=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('passed_gates', 0))")
FAILED=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('failed_gates', 0))")
HARD_STOP=$(python3 -c "import json; print(str(json.load(open('$SUMMARY')).get('hard_stop', False)).lower())")
DURATION=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('total_duration_seconds', 0))")

echo "${DATE},${CYCLES},${PASSED},${FAILED},${HARD_STOP},${DURATION}" >> "$CSV"
echo "Trend log updated: $CSV"
