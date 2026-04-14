#!/bin/bash
# council-session.sh — Parallel multi-model council invocation
# Implements the v6 Session Orchestration Protocol (TEAM.md)
#
# Usage: ./scripts/council-session.sh <brief.md>
#
# Prerequisites:
#   - Brief prepared as markdown file (identical for all seats)
#   - Seat-specific system prompts in prompts/{seat}.md (optional — defaults used if absent)
#   - ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLE_API_KEY set for multi-model
#
# Output: .build/council/{seat}-response.json + decision-record.md
set -euo pipefail
cd "$(dirname "$0")/.."

BRIEF="${1:?Usage: council-session.sh <brief.md>}"
COUNCIL_DIR=".build/council"
PROMPTS_DIR="prompts"

if [ ! -f "$BRIEF" ]; then
  echo "Error: Brief file not found: $BRIEF"
  exit 1
fi

mkdir -p "$COUNCIL_DIR"

# -- Seat configuration --
# Override by creating prompts/{seat}.md or passing --models flag
SEATS=("architect" "critic" "pragmatist" "seat4" "seat5")

# Default seat system prompts (used if prompts/{seat}.md doesn't exist)
declare -A SEAT_PROMPTS
SEAT_PROMPTS[architect]="You are The Architect. Your lens: system design, scalability, patterns. Core question: Will this structure hold at 10x scale? Score each option 1-9 on your dimensions. Propose your preferred option with rationale."
SEAT_PROMPTS[critic]="You are The Critic. Your lens: adversarial testing, edge cases, failure modes. Core question: How does this break? Score each option 1-9 on your dimensions. Propose your preferred option with rationale."
SEAT_PROMPTS[pragmatist]="You are The Pragmatist. Your lens: shipping speed, simplicity, user value. Core question: Can we ship this by Friday? Score each option 1-9 on your dimensions. Propose your preferred option with rationale."
SEAT_PROMPTS[seat4]="You are a domain expert. Score each option 1-9 on your dimensions. Propose your preferred option with rationale."
SEAT_PROMPTS[seat5]="You are a domain expert. Score each option 1-9 on your dimensions. Propose your preferred option with rationale."

echo "=== Council Session ==="
echo "Brief: $BRIEF"
echo "Output: $COUNCIL_DIR/"
echo ""

# -- Phase 1: Parallel Independent Assessment --
echo "Phase 1: Parallel seat assessment (information barrier)..."
PIDS=()

for seat in "${SEATS[@]}"; do
  (
    # Use custom prompt if available, otherwise default
    if [ -f "$PROMPTS_DIR/${seat}.md" ]; then
      SYSTEM_PROMPT=$(cat "$PROMPTS_DIR/${seat}.md")
    else
      SYSTEM_PROMPT="${SEAT_PROMPTS[$seat]}"
    fi

    BRIEF_CONTENT=$(cat "$BRIEF")

    # Invoke via Claude CLI (default — works without API keys)
    # For multi-model: replace with direct API calls per seat
    echo "$BRIEF_CONTENT" | claude --print --system-prompt "$SYSTEM_PROMPT" \
      > "$COUNCIL_DIR/${seat}-response.json" 2>/dev/null || \
    echo "{\"seat\": \"$seat\", \"error\": \"invocation failed\", \"proposal\": \"ABSTAIN\"}" \
      > "$COUNCIL_DIR/${seat}-response.json"

    echo "  $seat: done"
  ) &
  PIDS+=($!)
done

# Wait for all seats (parallel: wall time = max(seat_time))
echo "  Waiting for all seats..."
FAIL_COUNT=0
for pid in "${PIDS[@]}"; do
  if ! wait "$pid"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "  Warning: $FAIL_COUNT seat(s) failed invocation"
fi

echo ""
echo "Phase 1 complete. Seat responses:"
for seat in "${SEATS[@]}"; do
  if [ -f "$COUNCIL_DIR/${seat}-response.json" ]; then
    echo "  $seat: $(wc -l < "$COUNCIL_DIR/${seat}-response.json") lines"
  else
    echo "  $seat: MISSING"
  fi
done

# -- Phase 2: Convergence --
echo ""
echo "Phase 2: Convergence (single moderator invocation)..."

CONVERGENCE_PROMPT="You are the Council Moderator. You have received independent assessments from 5 council seats. Run the convergence protocol:

1. SCHELLING FOCAL POINT: Count how many seats proposed the same option. If F(x) >= 0.6, adopt it.
2. If no focal point, run IESDS to eliminate dominated options.
3. For remaining options, compute Nash Product (reversible) or Minimax Regret (irreversible).
4. Check for vetoes.
5. Produce a Decision Record in the standard format.

Seat responses follow:"

# Combine all seat responses
COMBINED=""
for seat in "${SEATS[@]}"; do
  if [ -f "$COUNCIL_DIR/${seat}-response.json" ]; then
    COMBINED="$COMBINED

--- $seat ---
$(cat "$COUNCIL_DIR/${seat}-response.json")"
  fi
done

echo "$CONVERGENCE_PROMPT $COMBINED" | claude --print \
  > "$COUNCIL_DIR/decision-record.md" 2>/dev/null || \
echo "# Decision Record — CONVERGENCE FAILED

Moderator invocation failed. Review seat responses manually in $COUNCIL_DIR/" \
  > "$COUNCIL_DIR/decision-record.md"

echo ""
echo "=== Council Session Complete ==="
echo "Decision Record: $COUNCIL_DIR/decision-record.md"
echo "Seat Responses:  $COUNCIL_DIR/{seat}-response.json"
echo ""
echo "IMPORTANT: Verify no seat saw another seat's response (information barrier)."
echo "If Phase 1 ran in parallel (default), the barrier is maintained."
