#!/usr/bin/env bash
# G-RELEASE conjunct (1) and (2): every debug-only symbol introduced by the
# refresh-debounce test infrastructure must live inside #if DEBUG ... #endif,
# and wipeAll() must have no production caller outside #if DEBUG.
#
# Usage: bash Scripts/check-debug-guards.sh
# Exits 0 on pass, 1 on any leak.
#
# Strategy: scan files under Sources/ for occurrences of debug-only symbols.
# For each match, walk back through preceding lines to find the nearest
# #if/#endif marker — pass if and only if the most recent marker is `#if DEBUG`.

set -euo pipefail

cd "$(dirname "$0")/.."

DEBUG_SYMBOLS=(
    "inboxSinkCount"
    "saveRefreshCount"
    "lastInboxPayloadCount"
    "suppressInitialAutoRefresh"
    "StubFeedURLProtocol"
    "SIMPOD_"
    "debounceMilliseconds"
    "seedPodcasts"
    "resetDebugCounters"
    "debugInboxEpisodeCount"
    "debugPodcastCount"
    "debugRefreshSnapshotCount"
    "debugRefreshCompletions"
)

leaks=0
report_leak() {
    echo "LEAK: $1:$2  $3"
    leaks=$((leaks + 1))
}

scan_file() {
    local file="$1"
    local symbol="$2"

    # Build a quick array of #if/#endif positions and their kinds.
    awk -v sym="$symbol" -v file="$file" '
    BEGIN { depth = 0; debug_depth = 0 }
    {
        line = $0
        # Track #if DEBUG / #if !DEBUG / #else / #endif state.
        if (line ~ /^[[:space:]]*#if[[:space:]]+DEBUG([[:space:]]|$)/) {
            stack[++depth] = "DEBUG"
        } else if (line ~ /^[[:space:]]*#if([[:space:]]|$)/) {
            stack[++depth] = "OTHER"
        } else if (line ~ /^[[:space:]]*#else([[:space:]]|$)/) {
            if (depth > 0) {
                stack[depth] = (stack[depth] == "DEBUG") ? "OTHER" : "DEBUG-ELSE"
            }
        } else if (line ~ /^[[:space:]]*#endif([[:space:]]|$)/) {
            if (depth > 0) depth--
        } else if (index(line, sym) > 0) {
            # Check if any active #if frame is DEBUG.
            in_debug = 0
            for (i = 1; i <= depth; i++) {
                if (stack[i] == "DEBUG") { in_debug = 1; break }
            }
            # Allow definition site of wipeAll() — see invariant note.
            if (sym == "wipeAll" && line ~ /func wipeAll/) next
            # Allow comments (lines whose match is purely in a comment).
            stripped = line
            sub(/^[[:space:]]*\/\/.*/, "", stripped)
            if (stripped == "") next
            if (in_debug == 0) {
                printf "%s:%d  %s\n", file, NR, line
            }
        }
    }
    ' "$file"
}

for sym in "${DEBUG_SYMBOLS[@]}"; do
    while IFS= read -r match; do
        report_leak "${match%%:*}" "$(echo "$match" | cut -d: -f2)" "$sym  →  $(echo "$match" | cut -d: -f3-)"
    done < <(find Sources -name '*.swift' -print0 | xargs -0 -I{} bash -c "$(declare -f scan_file); scan_file '{}' '$sym'" 2>/dev/null)
done

# wipeAll() may exist unguarded, but only at its definition site — no other
# caller in Sources/ may reference it.
wipe_callers=$(grep -rn "wipeAll" Sources --include="*.swift" \
    | grep -v "func wipeAll" \
    | awk -F: 'NR==FNR{} {print}' || true)

if [[ -n "$wipe_callers" ]]; then
    while IFS= read -r line; do
        # Each line is file:lineno:content. Check the surrounding context for #if DEBUG.
        f=$(echo "$line" | cut -d: -f1)
        ln=$(echo "$line" | cut -d: -f2)
        # Walk back from the matching line to find the nearest #if directive.
        ctx=$(awk -v target="$ln" '
            NR <= target {
                if ($0 ~ /^[[:space:]]*#if[[:space:]]+DEBUG/) state = "DEBUG"
                else if ($0 ~ /^[[:space:]]*#if/) state = "OTHER"
                else if ($0 ~ /^[[:space:]]*#endif/) state = ""
            }
            END { print state }
        ' "$f")
        if [[ "$ctx" != "DEBUG" ]]; then
            report_leak "$f" "$ln" "wipeAll caller outside #if DEBUG"
        fi
    done <<< "$wipe_callers"
fi

if [[ $leaks -gt 0 ]]; then
    echo ""
    echo "FAIL: $leaks debug-guard leak(s) found"
    exit 1
fi

echo "OK: all debug-only symbols enclosed in #if DEBUG"
exit 0
