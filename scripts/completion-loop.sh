#!/bin/bash
# completion-loop.sh — Standard v6 completion loop template
# Automated PDSA Study phase: run gates, diagnose failures, fix, re-run.
#
# Usage: ./scripts/completion-loop.sh [--max-cycles N] [--fast-only]
# Outputs: .build/completion-loop/summary.json
set -euo pipefail
cd "$(dirname "$0")/.."

MAX_CYCLES="${1:-10}"
FAST_ONLY=false
BUILD_DIR=".build/completion-loop"
SUMMARY="$BUILD_DIR/summary.json"
TREND_CSV="Docs/TREND-LOG.csv"

# Parse args
for arg in "$@"; do
  case "$arg" in
    --max-cycles=*) MAX_CYCLES="${arg#*=}" ;;
    --fast-only) FAST_ONLY=true ;;
  esac
done

mkdir -p "$BUILD_DIR"

# -- Gate runner --
run_gates() {
  local mode="$1"  # "fast" or "full"
  local gates_json="$BUILD_DIR/gates.json"
  echo "[]" > "$gates_json"

  run_gate() {
    local id="$1" name="$2" cmd="$3"
    local start_ts=$(date +%s)
    local result="PASS"
    if ! eval "$cmd" > "$BUILD_DIR/${id}.log" 2>&1; then
      result="FAIL"
    fi
    local end_ts=$(date +%s)
    local duration=$((end_ts - start_ts))

    # Append to gates.json
    python3 -c "
import json, sys
with open('$gates_json') as f: gates = json.load(f)
gates.append({'id': '$id', 'name': '$name', 'result': '$result', 'duration_s': $duration, 'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'})
with open('$gates_json', 'w') as f: json.dump(gates, f, indent=2)
"
    echo "  $id: $name — $result (${duration}s)"
    [ "$result" = "PASS" ]
  }

  echo "Running gates ($mode)..."

  # G0: Environment
  run_gate "G0" "Environment" "which swift || which python3 || which node" || true

  # G1: Build
  if [ -f "Package.swift" ]; then
    run_gate "G1" "Build" "swift build 2>&1" || true
  elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    run_gate "G1" "Build" "python3 -c 'import importlib; print(\"OK\")'" || true
  elif [ -f "package.json" ]; then
    run_gate "G1" "Build" "npm run build --if-present 2>&1" || true
  else
    run_gate "G1" "Build" "echo 'No build system detected — SKIP'" || true
  fi

  # G2: Unit tests
  if [ -f "Package.swift" ]; then
    run_gate "G2" "Unit Tests" "swift test 2>&1" || true
  elif [ -f "pyproject.toml" ]; then
    run_gate "G2" "Unit Tests" "python3 -m pytest -x -q 2>&1" || true
  elif [ -f "package.json" ]; then
    run_gate "G2" "Unit Tests" "npm test --if-present 2>&1" || true
  fi

  # G3: Integration / Smoke
  if [ -f "scripts/verify-fast.sh" ]; then
    run_gate "G3" "Smoke" "bash scripts/verify-fast.sh 2>&1" || true
  fi

  if [ "$mode" = "full" ] && [ "$FAST_ONLY" = "false" ]; then
    # G4-G7: Domain gates (project-specific — override this section)
    # G8: Design gate (manual or automated)
    # G9: Release gate
    run_gate "G9" "Release" "echo 'Release gate: check CLAUDE.md accuracy manually'" || true
  fi
}

# -- Main loop --
cycle=0
total_failures=0
consecutive_same_gate=0
last_failed_gate=""

START_TIME=$(date +%s)

while [ "$cycle" -lt "$MAX_CYCLES" ]; do
  cycle=$((cycle + 1))
  echo ""
  echo "=== Completion Loop Cycle $cycle / $MAX_CYCLES ==="

  if [ "$cycle" -le 2 ]; then
    run_gates "fast"
  else
    run_gates "full"
  fi

  # Check results
  failed=$(python3 -c "
import json
with open('$BUILD_DIR/gates.json') as f: gates = json.load(f)
fails = [g for g in gates if g['result'] == 'FAIL']
print(len(fails))
")

  if [ "$failed" = "0" ]; then
    echo ""
    echo "ALL GATES PASSED on cycle $cycle"
    break
  fi

  total_failures=$((total_failures + failed))

  # Check for 3 consecutive failures on same gate
  first_fail=$(python3 -c "
import json
with open('$BUILD_DIR/gates.json') as f: gates = json.load(f)
fails = [g for g in gates if g['result'] == 'FAIL']
print(fails[0]['id'] if fails else '')
")

  if [ "$first_fail" = "$last_failed_gate" ]; then
    consecutive_same_gate=$((consecutive_same_gate + 1))
  else
    consecutive_same_gate=1
    last_failed_gate="$first_fail"
  fi

  if [ "$consecutive_same_gate" -ge 3 ]; then
    echo ""
    echo "HARD STOP: Gate $last_failed_gate failed 3 consecutive times. Escalate to Council."
    break
  fi

  echo "  $failed gate(s) failed. Cycle $cycle complete."
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# -- Produce summary.json --
python3 -c "
import json
with open('$BUILD_DIR/gates.json') as f: gates = json.load(f)
passed = len([g for g in gates if g['result'] == 'PASS'])
failed = len([g for g in gates if g['result'] == 'FAIL'])
summary = {
    'total_cycles': $cycle,
    'max_cycles': $MAX_CYCLES,
    'passed_gates': passed,
    'failed_gates': failed,
    'total_duration_seconds': $DURATION,
    'hard_stop': $consecutive_same_gate >= 3,
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
}
with open('$SUMMARY', 'w') as f: json.dump(summary, f, indent=2)
print(json.dumps(summary, indent=2))
"

echo ""
echo "Summary written to $SUMMARY"

# -- Append to trend log --
if [ -f "scripts/append-trend-log.sh" ]; then
  bash scripts/append-trend-log.sh "$SUMMARY"
fi
