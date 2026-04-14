#!/usr/bin/env bash
# Detect circle patterns in git history and conversation
# Usage: ./scripts/detect-circles.sh [--since YYYY-MM-DD]
#
# Detects three circle types (see ITERATION.md §5):
#   Type 1: Revisited Decision — same file modified 5+ times without test passing
#   Type 2: Repeated Failure — same error pattern in 3+ consecutive commits
#   Type 3: Scope Oscillation — file added then removed then re-added
#
# Output: appends to .claude/projects/*/memory/circle-log.md
#
# → See ITERATION.md §5 for circle detection protocol
# → See CHARACTER-TRACKING.md for circle tracking

echo "Circle detector — placeholder for implementation"
echo "Usage: $0 [--since YYYY-MM-DD]"
