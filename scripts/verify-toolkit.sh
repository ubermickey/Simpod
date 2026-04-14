#!/bin/bash
# verify-toolkit.sh — Reusable gate infrastructure for v6 verification pipeline
# Provides functions for running gates, recording results, and reporting.
#
# Source this file in your project's verify scripts:
#   source scripts/verify-toolkit.sh
set -euo pipefail

VERIFY_DIR="${VERIFY_DIR:-.build/verify}"
GATES_JSON="$VERIFY_DIR/gates.json"
REVIEW_TRIGGERS="$VERIFY_DIR/review-triggers.jsonl"

# -- Initialize --
verify_init() {
  mkdir -p "$VERIFY_DIR"
  echo "[]" > "$GATES_JSON"
  : > "$REVIEW_TRIGGERS"
  echo "Verify toolkit initialized: $VERIFY_DIR"
}

# -- Run a single gate --
# Usage: verify_gate "G0" "Environment" "command to run"
verify_gate() {
  local gate_id="$1"
  local gate_name="$2"
  local gate_cmd="$3"
  local log_file="$VERIFY_DIR/${gate_id}.log"
  local start_ts=$(date +%s)
  local result="PASS"
  local evidence=""

  echo -n "  $gate_id: $gate_name ... "

  if eval "$gate_cmd" > "$log_file" 2>&1; then
    result="PASS"
    echo "PASS"
  else
    result="FAIL"
    evidence=$(tail -5 "$log_file" | tr '\n' ' ')
    echo "FAIL"
  fi

  local end_ts=$(date +%s)
  local duration=$((end_ts - start_ts))

  # Append to gates.json
  python3 -c "
import json
with open('$GATES_JSON') as f: gates = json.load(f)
gates.append({
    'id': '$gate_id',
    'name': '$gate_name',
    'result': '$result',
    'duration_s': $duration,
    'evidence': '''$evidence''',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'log': '$log_file'
})
with open('$GATES_JSON', 'w') as f: json.dump(gates, f, indent=2)
"

  # Record review trigger if failed
  if [ "$result" = "FAIL" ]; then
    echo "{\"gate\": \"$gate_id\", \"name\": \"$gate_name\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$REVIEW_TRIGGERS"
  fi

  [ "$result" = "PASS" ]
}

# -- Skip a gate --
verify_skip() {
  local gate_id="$1"
  local gate_name="$2"
  local reason="$3"

  echo "  $gate_id: $gate_name ... SKIP ($reason)"

  python3 -c "
import json
with open('$GATES_JSON') as f: gates = json.load(f)
gates.append({
    'id': '$gate_id',
    'name': '$gate_name',
    'result': 'SKIP',
    'reason': '$reason',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
})
with open('$GATES_JSON', 'w') as f: json.dump(gates, f, indent=2)
"
}

# -- Report results --
verify_report() {
  echo ""
  echo "=== Gate Results ==="

  python3 -c "
import json
with open('$GATES_JSON') as f: gates = json.load(f)
passed = sum(1 for g in gates if g['result'] == 'PASS')
failed = sum(1 for g in gates if g['result'] == 'FAIL')
skipped = sum(1 for g in gates if g['result'] == 'SKIP')
total = len(gates)

for g in gates:
    icon = {'PASS': 'o', 'FAIL': 'x', 'SKIP': '-'}[g['result']]
    print(f\"  [{icon}] {g['id']}: {g['name']} — {g['result']}\")

print(f\"\nTotal: {total} gates | {passed} passed | {failed} failed | {skipped} skipped\")

if failed > 0:
    print(f\"\nReview triggers written to: $REVIEW_TRIGGERS\")
    exit(1)
"
}

# -- Check if all gates passed --
verify_all_passed() {
  python3 -c "
import json
with open('$GATES_JSON') as f: gates = json.load(f)
failed = [g for g in gates if g['result'] == 'FAIL']
exit(0 if len(failed) == 0 else 1)
"
}
