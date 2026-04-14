# ITERATION.md -- Pass-Based Workflow Engine

> **Kaizen** -- The pass loop IS the iteration engine; measure, improve, measure.
> **Unix** -- One objective per pass, one diagnostic per issue; compose small corrections.
> **Deming** -- PDSA is the scientific method of software; study the system, not the symptom.
> **AI-Native** -- Lock invariants explicitly; AI cannot remember what is not written down.
> **Parallel** -- Decompose into swim lanes; serial-when-parallel is waste (muda).
> The pass loop is simple. Its power comes from discipline.

---

## 1. PDSA Cycle (Outer Loop)

PDSA is the scientific method of software. It is the outer loop; the Pass Loop (S2) runs inside it. Every feature or significant change begins with a written Plan and ends with a measured Act.

```
PDSA CYCLE (outer loop -- use for any new feature or significant change)

PLAN   -> State hypothesis + acceptance criteria + rollback condition
DO     -> Smallest safe implementation + instrumentation
STUDY  -> Expected vs. observed; regressions; complexity added; circle check
ACT    -> Standardize / revise / isolate behind flag / reduce scope / rollback / re-brief
```

PDSA maps to the Pass Loop:
- **Plan** = Identity Block + objective definition (what must not change + what we are trying to achieve)
- **Do** = PRODUCE phase (smallest safe implementation)
- **Study** = ANALYZE phase (expected vs. observed, regressions, circle check)
- **Act** = MODIFY + EVALUATE + decision (ship / revert / flag)

WHEN a feature or significant change is starting, THEN write the PDSA Plan first:

```markdown
PDSA PLAN: {feature_name}
- Hypothesis: If we build {X}, then {user} can {Y}
- Acceptance criteria: {testable assertions -- each binary}
- Rollback condition: {specific signal that means revert}
- Rollback plan: {how to revert -- git branch, flag, migration}
- Measurement: {what metrics will be collected during Study}
- Swim lane: {which lane owns this work -- see S3}
- Phase: {which phase cadence slot -- see S4}
```

NEVER start the Do phase without a written Plan. A Plan without acceptance criteria is not a Plan -- it is a wish.

WHEN Study reveals that observed behavior diverges from expected, THEN the Act phase MUST choose one:
1. **Standardize** -- it worked; document and ship
2. **Revise** -- it partially worked; adjust the hypothesis, loop again
3. **Flag** -- it works but has risk; isolate behind a feature flag
4. **Rollback** -- it failed the rollback condition; revert and rethink scope
5. **Re-brief** -- scope has changed significantly; produce an updated Architecture Brief (-> See ARCHITECTURE.md) before the next PDSA cycle

WHEN Act results in a major scope change (new subsystem, new pillar, fundamental architecture shift), THEN choose option 5 (Re-brief). The existing Architecture Brief no longer describes the system. An outdated brief causes the same class of errors as no brief -- the AI team makes decisions against a stale mental model.

ALWAYS write the rollback plan before writing the implementation (Deming: design quality in).

---

## 2. The Pass Loop (Inner Loop)

Every change follows this four-phase loop. No exceptions.

```
    PRODUCE --> ANALYZE --> MODIFY --> EVALUATE
       ^                                    |
       |           +--------+               |
       +-----------| PASS?  |<--------------+
                   +----+---+
                   YES  |  NO
                    v   |   v
              Next pass |  Loop back to MODIFY
                        |  (or PRODUCE if fundamental rethink needed)
```

| Phase | Directive |
|-------|-----------|
| **PRODUCE** | Create the artifact. Write code, generate the image, draft the design. Do NOT over-polish. |
| **ANALYZE** | Compare output against the single-sentence objective. Identify every gap. Use `symptom -> fix -> result` for each issue. |
| **MODIFY** | Apply fixes identified in analysis. ONE change at a time. NEVER introduce new features during modification. |
| **EVALUATE** | Binary judgment. Does the artifact meet the objective? Yes = pass complete. No = loop back. |
| **CIRCLE CHECK** | After EVALUATE, run circle detection (-> See S5). Check: are we revisiting a decided question (Type 1)? Repeating a failed approach (Type 2)? Oscillating on scope (Type 3)? If circle detected: log it, flag it, consider course change before next pass. |

### One Objective Per Pass

Every pass has exactly ONE objective, stated as a single sentence that is directly testable.

**Good objectives** (single, testable):
- "The login button appears on mobile viewport (375px width)"
- "The API returns 401 when no auth token is provided"
- "The sidebar collapses to icons when the toggle is clicked"

**Bad objectives** (compound, vague, untestable):
- "Fix the button and add the header" (two objectives = two passes)
- "Improve the design" (untestable)
- "Make it work better" (no metric)

ALWAYS split immediately when you catch a compound objective:

```
BAD:  "Fix the nav bar alignment and add dark mode support"

GOOD: P01 -- "The nav bar items are horizontally centered with 16px gaps"
      P02 -- "Clicking the theme toggle switches all CSS properties to dark palette"
```

### Pass ID Format

```
P01, P02, P03, ... P12, P13, ...
```

Reset the counter when starting a new work session. Pass IDs are local to a session. WHEN swim lanes are active, prefix with the lane ID: `L1-P03`, `L2-P01`.

### The `symptom -> fix -> result` Diagnostic Format

Every problem uses this three-line format. No exceptions.

```
SYMPTOM: <what is wrong -- observable behavior anyone can verify>
FIX:     <what to change -- specific, actionable modification>
RESULT:  <expected outcome -- testable assertion after the fix>
```

**Why Three Lines:**
- **SYMPTOM** forces you to describe the actual problem, not your theory.
- **FIX** forces you to name a specific action, not a vague intention.
- **RESULT** forces you to define done. If you cannot write it, you do not understand the fix.

**One Example Per Domain:**

**UI:**
```
SYMPTOM: The submit button overflows the card container on viewports below 400px.
FIX:     Add max-width: 100% and box-sizing: border-box to .btn-submit in app.css.
RESULT:  The submit button stays within the card boundary at 320px, 375px, and 400px.
```

**API:**
```
SYMPTOM: POST /api/tasks returns 500 when due_date is null.
FIX:     Make due_date optional in the Pydantic model (due_date: Optional[datetime] = None).
RESULT:  POST /api/tasks with {"title": "Test", "due_date": null} returns 201.
```

**Performance:**
```
SYMPTOM: The dashboard takes 4.2 seconds to load with 1000+ tasks.
FIX:     Add pagination (default limit=50) and virtual scrolling in TaskList.tsx.
RESULT:  Dashboard loads in under 800ms. Scrolling 1000 tasks stays above 55fps.
```

WHEN ANALYZE produces more than 3 issues in a single pass, THEN the objective is too broad -- split into multiple passes.

### Universal Application

The pass loop applies to ALL types of work. The domain changes. The discipline does NOT.

| Work Type | Pass Characteristics |
|-----------|---------------------|
| Feature development | Multi-pass. Produce module, analyze integration, modify edge cases, evaluate. |
| Bug fix | Almost always single-pass. If > 2 passes, root cause analysis is wrong. |
| Refactoring | Extract, verify tests pass, add tests for extracted units. |
| Design system | Component variants, disabled states, responsive behavior -- one per pass. |
| Performance | Audit first (produce metrics), fix bottlenecks one at a time. |

ALWAYS use the same structure: state objective, produce, analyze, modify, evaluate. ALWAYS log every pass. ALWAYS respect failure gates (-> See S7).

---

## 3. Swim Lane Model

Swim lanes decompose a project into parallel workstreams. Each lane is a sequence of dependent phases; across lanes, work proceeds concurrently. A serial plan that could be parallel is waste (Parallel principle).

### Decomposition at Kickoff

ALWAYS decompose into swim lanes at project kickoff, during or immediately after the first Council Session (-> See TEAM.md). The decomposition produces a DAG (Directed Acyclic Graph) of lanes and their dependencies.

WHEN starting a new project, THEN identify independent workstreams before writing any code. NEVER begin sequential work without first checking whether it can be parallelized.

### Swim Lane Rules

1. **Max 5 lanes per project.** More than 5 lanes creates coordination overhead that exceeds the parallelism benefit. WHEN you identify more than 5 independent streams, THEN merge the two most related streams into one.
2. **Sequential within lane.** Each phase within a lane depends on the prior phase. NEVER skip a phase within a lane.
3. **Concurrent across lanes.** Lanes without shared state or data dependencies execute in parallel. NEVER block Lane B waiting on Lane A unless there is a genuine data dependency.
4. **Sync points are explicit.** WHEN Lane B depends on output from Lane A, THEN define a sync point: the specific artifact, API, or data contract that Lane A must produce before Lane B can proceed. Sync points are the ONLY places where lanes wait.
5. **Each phase is a PDSA vertical slice.** Every phase within every lane has its own hypothesis, acceptance criteria, rollback condition, and quality gate (-> See QUALITY.md).

### DAG Template

ALWAYS produce a DAG diagram at kickoff. Use this format:

```
SWIM LANE DAG -- {Project Name}

Lane 1 ({domain}):  [A: {phase}] -> [B: {phase}] -> [F: {phase}]
Lane 2 ({domain}):  [C: {phase}] -> [D: {phase}] -> [G: {phase}]
Lane 3 ({domain}):  -------------- -> [E: {phase}] -> [H: {phase}]
Lane 4 ({domain}):  -------------------------------- -> [I: {phase}] -> [J: {phase}]

Sync points:
  Lane 3 starts at E (depends on Lane 2.D output)
  Lane 4 starts at I (depends on Lane 1.F + Lane 3.H)

Critical path: Lane 1 -> Lane 4 (longest chain determines minimum project duration)
```

### Critical Path Identification

ALWAYS identify the critical path -- the longest chain of dependent phases from project start to finish. The critical path determines the minimum possible project duration regardless of parallelism.

WHEN prioritizing work, THEN prioritize critical path phases first. A delay on the critical path delays the entire project. A delay on a non-critical lane only matters if it exceeds its slack time.

### Parallel Passes Across Independent Lanes

WHEN two or more lanes have active phases with no shared dependencies, THEN execute passes in those lanes concurrently. Fan out to parallel agents for independent tasks (-> See TEAM.md).

```
PARALLEL PASS EXECUTION

Lane 1: L1-P03 (active)  -- no dependency on Lane 2
Lane 2: L2-P01 (active)  -- no dependency on Lane 1

-> Execute L1-P03 and L2-P01 concurrently.

Lane 3: L3-P02 (blocked) -- waiting on sync point from Lane 1.L1-P03
-> Lane 3 waits. Advance Lane 3 only after Lane 1 sync point is met.
```

### Lane State Tracking

Track each lane's state in the session handoff (-> See S10):

```
LANE STATUS -- {date}

| Lane | Current Phase | Pass | Status  | Blocked By |
|------|--------------|------|---------|------------|
| L1   | B: API scaffold | L1-P02 | ACTIVE  | --         |
| L2   | C: Tab enum     | L2-P01 | ACTIVE  | --         |
| L3   | (waiting)       | --     | BLOCKED | L2.D       |
| L4   | (waiting)       | --     | BLOCKED | L1.F, L3.H |
```

---

## 4. Phase Cadence

Every phase (a lettered step within a swim lane) follows a strict cadence of rituals at its start, during execution, and at its end. The cadence ensures that no phase begins without a hypothesis, proceeds without discipline, or ends without verification.

### Start of Phase

ALWAYS perform these steps before writing any code for a new phase:

1. **Record phase start**: Log `phase-{X}.{name}.start` with timestamp.
2. **State hypothesis**: Write the phase's hypothesis in PDSA Plan format. WHEN the hypothesis cannot be stated in one sentence, THEN the phase is too broad -- split it.
3. **State acceptance criteria**: List binary (yes/no) criteria. NEVER use subjective criteria like "looks good" or "feels fast."
4. **Identify rollback condition**: Define the specific signal that means revert. WHEN no rollback condition can be identified, THEN the phase lacks sufficient clarity to begin.
5. **Gate check**: Review prerequisites. All sync-point dependencies from other lanes must be met. All P0 issues from prior phases must be resolved. `pass` to proceed, `warn` to note concerns and proceed with caution.

### During Phase

ALWAYS maintain these invariants while a phase is active:

6. **Implement smallest safe change** (Unix: one thing, Deming: smallest experiment that tests the hypothesis).
7. **Build must compile at each step.** NEVER leave the build broken between modifications within a phase. WHEN the build breaks, THEN fix it before making any further changes.
8. **File issues immediately.** WHEN an issue is discovered during implementation, THEN log it into the TODO Pipeline (-> See S6) with priority and PDSA state. NEVER defer issue logging to "later."

### End of Phase

ALWAYS perform these steps before advancing to the next phase:

9. **Run affected tests.** WHEN no tests exist for the changed code, THEN write them before declaring the phase complete (-> See QUALITY.md).
10. **Compare expected vs. observed.** Run the PDSA Study step: does actual behavior match the hypothesis? Log discrepancies.
11. **Record phase end**: Log `phase-{X}.{name}.complete` with timestamp and outcome.
12. **Gate check**: `pass` to advance to next phase, `fail` to iterate within the current phase. WHEN the gate check is `fail`, THEN loop back through the pass loop (S2) within this phase until the acceptance criteria are met or failure gates (S7) trigger escalation.

### Hard Stop Rules

ALWAYS enforce these rules -- no exceptions, no workarounds:

- **Any unresolved P0 issue -> stop everything.** A P0 in one lane blocks ALL lanes, not just the lane where it was found. P0 issues are system-level threats.
- **Any unresolved P1 on core flow -> stop.** P1 issues on the core flow (as defined in the Requirements Brief T1) block advancement on any lane that touches the core flow.
- **Preempt signal -> fix before advancing.** WHEN a preempt signal is raised (by any team member, quality gate, or automated check), THEN address it before advancing to the next phase or the next pass. Preemption is not a suggestion.

---

## 5. Circle Detection

Circles are patterns of wasted effort. Three types, each with distinct detection triggers and resolution strategies. Circle detection runs after every EVALUATE phase and at every session start.

-> See PHILOSOPHY.md for the Kaizen principle behind continuous detection: improvement without measurement is guessing.

### 5.1 Circle Types

#### Type 1: Revisited Decisions

The team re-discusses something that already has an ADR or Council Decision Record.

```
DETECTION TRIGGER:
  A question is raised that has an existing answer in:
  - An ADR (ARCHITECTURE.md)
  - A Council Decision Record (TEAM.md)
  - A Requirements Brief

EXAMPLES:
  "Should we use JWT or sessions?" -- already decided in ADR-003
  "Maybe we should switch to PostgreSQL" -- already decided in Council Session #1
  "What if we changed the core flow?" -- already defined in Requirements Brief

SEVERITY: Medium. Indicates either forgotten context or changing requirements.
```

#### Type 2: Repeated Failed Approaches

The same symptom/fix pattern appears 2+ times without success.

```
DETECTION TRIGGER:
  The symptom -> fix -> result format shows:
  - Same SYMPTOM described 2+ times across different passes
  - Same FIX attempted 2+ times (even with minor variations)
  - A 2-fail pivot (S7) that leads to the same class of approach

EXAMPLES:
  P03: "API returns 500" -> "add error handling" -> FAIL
  P05: "API returns 500" -> "add different error handling" -> FAIL
  (Same symptom, same class of fix -- the root cause is elsewhere)

SEVERITY: High. Indicates misdiagnosed root cause.
```

#### Type 3: Scope Creep Loops

Scope is expanded, then cut, then expanded again on the same topic.

```
DETECTION TRIGGER:
  A feature or requirement has been:
  - Added to scope (user request or discovery)
  - Cut from scope (too complex, out of time, anti-goal violation)
  - Added back to scope again (user re-requests or re-discovers)

EXAMPLES:
  Sprint 1: "Let's add dark mode" -> Sprint 2: "Cut dark mode, not MVP"
  -> Sprint 3: "Actually, we need dark mode"

  Pass P02: "Add filtering" -> Pass P04: "Filtering is too complex, remove"
  -> Pass P08: "Users need filtering, add it back"

SEVERITY: High. Indicates unclear requirements or unstable priorities.
```

### 5.2 Circle Log Format

Every detected circle MUST be logged immediately. The log persists across sessions in `.claude/projects/*/memory/circle-log.md`.

```
CIRCLE LOG ENTRY

ID: CIRCLE-{NNN}
Date: {date}
Type: 1 (Revisited Decision) | 2 (Repeated Failure) | 3 (Scope Creep)
Lane: {swim lane ID, if applicable}
Phase: {phase ID, if applicable}
Description: {what happened -- 1-2 sentences}
Evidence: {references to ADRs, pass logs, or scope changes}
Occurrences: {count -- how many times this circle has appeared}
Resolution: OPEN | RESOLVED | ESCALATED
Resolution Action: {what was done to break the circle}
```

### 5.3 Circle Resolution Strategies

| Type | Resolution Strategy |
|------|-------------------|
| Type 1 (Revisited Decision) | Surface the existing ADR/Decision Record. If circumstances have genuinely changed, explicitly re-open the decision through a new Council Session -- NEVER by drift. |
| Type 2 (Repeated Failure) | Force a fundamentally different approach. If the symptom persists after 2 different fix classes, the diagnosis is wrong. Escalate to root cause analysis or Council. |
| Type 3 (Scope Creep) | Force a definitive in/out decision. Add to Requirements Brief as either a firm commitment or a firm anti-goal. If it keeps oscillating, it is a sign that the success metric (S6) is unclear. |

### 5.4 Escalation Rules

```
CIRCLE ESCALATION

1 occurrence:  Log it. Note it. Continue.
2 occurrences: Flag it. Review the original decision/approach.
3+ occurrences: ESCALATE.
  -> Type 1: Force a Council Session to either reaffirm or formally reverse.
  -> Type 2: Hard stop. Root cause analysis. Different team member diagnoses.
  -> Type 3: Human intervention required. The scope is genuinely unclear.
```

### 5.5 When to Check

ALWAYS run a circle check after the EVALUATE phase of every pass. The check takes 30 seconds and prevents hours of wasted work.

ALWAYS run a circle check at session start:
1. Read the Circle Log from memory.
2. Read the current pass log / session handoff.
3. Compare current work against logged circles.
4. WHEN a circle pattern is emerging, THEN flag it BEFORE work begins.

### 5.6 PDSA Integration

In the PDSA outer loop, circle detection maps to the **Study** phase:

- **Plan** = Define hypothesis + acceptance criteria (no circle check needed)
- **Do** = Implement (no circle check needed)
- **Study** = Expected vs. observed + **circle check** (is this a pattern we have seen before?)
- **Act** = If circle detected, the Act decision MUST account for the circle (do not standardize a circling pattern; revise or rollback instead)

WHEN the Act phase results in "Revise" and a Type 2 circle is active, THEN the revision MUST be a fundamentally different approach -- not a variation of the same fix class.

---

## 6. TODO Pipeline

Every TODO follows a lifecycle from creation to resolution. TODOs are not informal notes -- they are tracked items with PDSA state, gate status, and rollback conditions. A TODO without acceptance criteria is not a TODO -- it is a wish.

### Lifecycle

```
TODO created -> tracked item (PDSA state + gate status) -> implementation -> verification -> resolution
```

Each TODO has:
- **PDSA state**: Plan -> Do -> Study -> Act
- **Gate status**: pending | pass | warn | fail
- **Priority**: P0 (blocks everything) | P1 (blocks core flow) | P2 (blocks lane) | P3 (backlog)
- **Rollback condition**: What triggers revert
- **Acceptance criteria**: Binary (yes/no) conditions for resolution
- **Lane assignment**: Which swim lane owns this TODO

### TODO Format

```
TODO-{NNN}: {one-sentence description}
Priority: P0 | P1 | P2 | P3
Lane: {lane ID or "cross-cutting"}
Phase: {phase ID or "backlog"}
PDSA State: PLAN | DO | STUDY | ACT | RESOLVED
Gate: pending | pass | warn | fail
Acceptance: {binary criteria}
Rollback: {condition that triggers revert}
Created: {date}
Resolved: {date or "--"}
```

### Lifecycle Steps

1. **TODO created during planning or discovered during implementation.** ALWAYS log immediately using the format above. NEVER defer TODO creation to "later."
2. **Phase start**: Record the TODO entering the Do state. The TODO is now active.
3. **Implementation (Do)**: Execute the smallest safe change that addresses the TODO.
4. **Verification (Study)**: Compare result against acceptance criteria. WHEN acceptance criteria are not met, THEN the TODO stays in Study state and loops back through the pass loop.
5. **Phase end**: Record the TODO gate result. `pass` = TODO resolved. `fail` = TODO iterates.
6. **If pass -> Standardize (Act)**: The TODO is RESOLVED. Document the fix. Update any affected Identity Blocks, ADRs, or contracts.
7. **If fail -> Issue filed, iterate**: The TODO remains open. File a diagnostic using `symptom -> fix -> result` format and loop.
8. **If rollback triggered -> Revert to known-good state**: The TODO failed its rollback condition. Revert and reassess the approach.

### Pipeline Tracking

ALWAYS maintain a TODO summary in the session handoff (-> See S10):

```
TODO PIPELINE -- {date}

| ID       | Priority | Lane | PDSA  | Gate    | Description                     |
|----------|----------|------|-------|---------|---------------------------------|
| TODO-001 | P0       | L1   | ACT   | pass    | API auth returns valid JWT       |
| TODO-002 | P1       | L2   | DO    | pending | Tab enum covers all 5 sections   |
| TODO-003 | P2       | L3   | PLAN  | pending | Browse tab renders genre grid    |
| TODO-004 | P3       | --   | PLAN  | pending | Add keyboard shortcuts           |
```

### Hard Stop Integration

WHEN a P0 TODO enters `fail` gate status, THEN all lanes stop (-> See S4 Hard Stop Rules). P0 issues are system-level threats that override lane-level parallelism.

WHEN a P1 TODO on the core flow enters `fail` gate status, THEN all lanes touching the core flow stop. Lanes not touching the core flow may continue.

---

## 7. Failure Gates

| Consecutive Failures | Action | Goal Changes? | Method Changes? |
|---------------------|--------|---------------|-----------------|
| 1 | Retry with refinement | No | Minor tweaks |
| 2 | **Pivot** to fundamentally different approach | No | Yes |
| 3 | **Hard stop** + escalate to Council | Possibly | Council decides |

### 1-Fail: Retry with Refinement

The first failure is normal. Adjust and re-attempt within the same approach.

WHEN a pass fails on the first attempt, THEN refine the approach without changing the fundamental method. Minor tweaks to the implementation, not to the strategy.

### 2-Fail: Pivot

Two consecutive failures on the same objective with the same approach means the approach is WRONG. Keep the goal, change the method.

```
L1-P05 -- "Chart renders in under 200ms with 10k points"
  Approach: Optimize D3 rendering -> FAIL (1.2s)

L1-P06 -- same objective
  Approach: Different D3 optimization -> FAIL (900ms)

  -> 2-FAIL PIVOT: Switch from D3 SVG to Canvas rendering

L1-P07 -- same objective
  Approach: Canvas-based rendering -> PASS (140ms)
```

WHEN a 2-fail pivot occurs, THEN check for Type 2 circles (-> See S5). If the pivot leads to the same class of approach, the diagnosis is wrong -- escalate.

### 3-Fail: Hard Stop

Three consecutive failures means something fundamental is wrong. STOP. NEVER attempt a fourth pass on the same objective with the same diagnosis.

Actions:
1. Document all three attempts and their failure modes
2. Escalate to Council or human review (-> See TEAM.md)
3. The objective may need to be redefined, split, or abandoned
4. Log a circle entry if this represents a repeated pattern (-> See S5)

### Restart Protocol

Trigger a restart when:
- Three or more overlapping issues make isolation impossible
- A fundamental assumption turns out to be wrong
- You have been iterating for more than 10 passes on a simple change

```
1. git add -A && git commit -m "wip: snapshot before restart -- <reason>"
2. Document what was learned (in CLAUDE.md or iteration log)
3. Reset to last known good state
4. Restate original intent in fresh terms
5. Update swim lane DAG if lane structure has changed
6. Begin new pass chain from P01
```

ALWAYS commit before resetting -- NEVER discard work without a snapshot. The `wip:` prefix signals this is a recovery checkpoint, not a feature commit.

---

## 8. Identity Blocks

Some things MUST NOT change across iterations. Lock them down explicitly. Identity drift -- small, unrequested changes that accumulate until the artifact is unrecognizable -- is the primary risk in AI-assisted iteration.

-> See DESIGN.md for visual identity values (colors, typography, layout).

### What to Lock

| Category | Examples | Why |
|----------|----------|-----|
| Core layout | Header height, sidebar width, main content grid | Prevents layout drift |
| Color palette | Primary, secondary, background, text (CSS custom properties) | Prevents AI from "improving" colors |
| Typography | Font family, base size, scale ratio | Type changes cascade through every element |
| Brand elements | Logo, icon set, illustration style | Defines recognition |
| API contracts | Endpoint paths, request/response schemas | Breaking changes cascade to all clients |
| Data models | Table names, column types | Changing these requires migrations |

### Identity Block Template

Document at the top of every iteration session:

```markdown
## Identity Block (LOCKED)

DO NOT MODIFY these elements. Carry them unchanged across all passes.

### Layout
- Header: 64px fixed, full width
- Sidebar: 280px, collapsible to 60px
- Main content: flex-grow, 24px padding

### Colors (CSS custom properties)
- --color-bg: #121016
- --color-surface: #1A171F
- --color-primary: #FF6B8A
- --color-text: #F0ECE8

### Typography
- Display: Quicksand, 600
- Body: Nunito, 400
- Scale: micro/caption/body/heading/title

### API Contract
- GET /api/v1/tasks -> { tasks: Task[], total: number }
- POST /api/v1/tasks -> { task: Task }
```

### Preventing Identity Drift

Identity drift = small, unrequested changes that accumulate until the artifact is unrecognizable.

```
Pass P01: "Fix the card shadow"
  -> AI also changes border-radius from 8px to 12px (NOT REQUESTED)

Pass P02: "Add loading spinner"
  -> AI changes primary color from pink to indigo (NOT REQUESTED)

After 10 passes: "Why does the app look completely different?"
```

The Identity Block prevents this by making locked properties explicit. ALWAYS check the Identity Block after each pass. WHEN any locked property changed without a dedicated unlock pass, THEN REVERT immediately.

### Unlock Protocol

An identity element MUST only be unlocked when:
1. A deliberate design decision is made (not a side effect)
2. The change is its own dedicated pass with the identity change as the sole objective
3. Impact is assessed across the entire system before the change
4. The old value and new value are documented
5. The Identity Block document is updated
6. All swim lanes are notified of the change (identity changes are cross-cutting)

NEVER unlock an identity element as a side effect of another pass. NEVER allow an AI agent to modify a locked element without explicit human approval.

---

## 9. Variance Tracking

Track trends across sessions, not just individual pass outcomes. Increasing failure rates or build times reveal system health problems that individual passes cannot diagnose. This is Deming applied to the iteration process itself: measure the system, not just the event.

### Trend Log

```markdown
## Trend Log -- {project}
| Session    | Passes | Failures | Pivots | Build Time | Test Count | Circles |
|------------|--------|----------|--------|------------|------------|---------|
| 2026-03-01 | 8      | 2        | 1      | 45s        | 47         | 0       |
| 2026-03-08 | 11     | 1        | 0      | 43s        | 51         | 1       |
| 2026-03-15 | 6      | 0        | 0      | 41s        | 58         | 0       |
```

### Diagnostic Rules

WHEN failure rate increases across sessions, THEN diagnose the process (unclear objectives, wrong model assignment, missing tests), not individual failures.
WHEN build time increases across sessions, THEN investigate what was added (new dependencies, larger test suite, missing caching).
WHEN test count decreases, THEN investigate deletions -- a shrinking test suite is a quality regression signal.
WHEN circle count increases, THEN review the Circle Log (-> See S5) for systemic patterns -- recurring circles indicate process failure, not individual failure.
WHEN pivot rate increases over the project lifetime, THEN the project may have unclear requirements or an unstable architecture -- escalate to Council.

### Healthy Trends

- Failure rate: stable or decreasing
- Build time: stable or decreasing
- Test count: stable or increasing (proportional to code added)
- Pivot rate: decreasing over the project lifetime
- Circle count: decreasing or zero

### Automating the Trend Log

The Trend Log MUST be automated, not manually maintained. A manual Trend Log will be abandoned by session 3.

The completion loop already produces `summary.json` with cycle counts and pass/fail status. Append one row to a CSV after each completion loop run:

```bash
#!/bin/bash
# append-trend-log.sh -- Append one row to Docs/TREND-LOG.csv from completion loop summary
set -euo pipefail
SUMMARY="${1:-.build/completion-loop-v2/summary.json}"
CSV="Docs/TREND-LOG.csv"

# Create header if file does not exist
if [ ! -f "$CSV" ]; then
  mkdir -p "$(dirname "$CSV")"
  echo "date,cycles,pass,fail,pivots,build_time_s,test_count,circle_count" > "$CSV"
fi

# Extract fields from summary.json (jq required)
DATE=$(date +%Y-%m-%d)
CYCLES=$(jq -r '.total_cycles // 0' "$SUMMARY")
PASS=$(jq -r '.passed_cycles // 0' "$SUMMARY")
FAIL=$(jq -r '.failed_cycles // 0' "$SUMMARY")
PIVOTS=$(jq -r '.pivots // 0' "$SUMMARY")
BUILD_TIME=$(jq -r '.total_duration_seconds // 0' "$SUMMARY")
TEST_COUNT=$(jq -r '.test_count // 0' "$SUMMARY")
CIRCLES=$(jq -r '.circle_count // 0' "$SUMMARY")

echo "${DATE},${CYCLES},${PASS},${FAIL},${PIVOTS},${BUILD_TIME},${TEST_COUNT},${CIRCLES}" >> "$CSV"
echo "Trend log updated: $CSV"
```

Call `append-trend-log.sh` at the end of every completion loop run. After 10 data points, the Trend Log becomes diagnostic -- variance reveals system health.

---

## 10. Session Handoff

Within-session context refresh keeps AI on track during a session, but is insufficient for multi-day work. For projects spanning multiple sessions, write a **Session Handoff Record** at session end and read it at session start. Without handoffs, every new session effectively starts from P01 with no memory of prior decisions. Even a 5-line handoff prevents hours of re-derivation.

### Session Handoff Record

```markdown
## Session Handoff -- {date}

**Project state**: {brief description of where things stand}
**Last completed pass**: P{XX} -- {objective} -- PASS/FAIL
**Next pass**: P{XX+1} -- {objective}
**Identity Block**: {locked colors/layout/contracts -- or link to file}
**Active blockers**: {anything that needs human input}
**Key files changed**: {list of files modified this session}

### Swim Lane Status
| Lane | Current Phase | Pass     | Status  | Blocked By |
|------|--------------|----------|---------|------------|
| L1   | {phase}      | L1-P{XX} | ACTIVE  | --         |
| L2   | {phase}      | L2-P{XX} | ACTIVE  | --         |
| L3   | (waiting)    | --       | BLOCKED | L2.{phase} |

### TODO Pipeline Snapshot
| ID       | Priority | PDSA  | Gate    | Description              |
|----------|----------|-------|---------|--------------------------|
| TODO-001 | P0       | ACT   | pass    | {resolved item}          |
| TODO-002 | P1       | DO    | pending | {active item}            |

### Open Circles
| Circle ID   | Type | Occurrences | Status |
|-------------|------|-------------|--------|
| CIRCLE-001  | 2    | 1           | OPEN   |
```

**Where to store it**: `.claude/projects/{project-id}/memory/session-handoff.md` or the project `CLAUDE.md` under `## Current State`.

### Session Start Protocol

ALWAYS follow this protocol at the start of every session:

1. Read session handoff from previous session
2. Restore the Identity Block into context
3. Check active blockers -- any resolved since last session?
4. Read the Circle Log -- any circles emerging?
5. Read the swim lane DAG -- which lanes are active, blocked, or complete?
6. Read the TODO Pipeline -- any P0 or P1 items unresolved?
7. Resume from "Next pass" or reassess if context has changed

WHEN the handoff record is missing or stale (> 7 days old), THEN ask the user to confirm current state before resuming work. NEVER assume prior state from memory.

### Context Refresh Cadence

ALWAYS restate key context every 3-4 turns during active iteration. This prevents AI drift, hallucination, and forgotten objectives.

**Context Refresh Template:**

```markdown
---
CONTEXT REFRESH

**Intent**: {What are we trying to achieve in this work session?}
**Locked state**: {Reference the Identity Block -- what must NOT change?}
**Current target**: {Pass PXX -- specific testable objective}
**Active lane**: {Lane ID and phase}
**Progress**: {P01 PASS, P02 PASS, P03 FAIL->PASS, ...}
**Active constraints**: {Any specific rules for this pass?}
**Open circles**: {Count and types, or "none"}
---
```

**Quick Refresh (One-Liner):**

```
REFRESH: Intent=task dashboard. Locked=identity block. Lane=L2. Target=L2-P04 status badges. Last=L2-P03 PASS. Circles=0.
```

**When to Refresh:**

- Every 3-4 turns during active iteration (MANDATORY)
- After any failure
- After any break
- When switching objectives or lanes
- When the AI output does not match what you asked for

### Iteration Log Template

Every pass gets logged. This is your audit trail.

**Full Log Entry:**

```markdown
## Pass {Lane}-P{XX}

- **Objective**: {single testable sentence}
- **Lane**: {lane ID and phase}
- **Prompt**: {what was asked or what action was taken}
- **Result**: {what actually happened -- factual description}
- **Outcome**: PASS | FAIL | PARTIAL
- **Next**: continue | pivot | escalate | stop
- **Evidence**: {screenshot path, test result, terminal output}
- **Circle check**: {Type 1/2/3 detected? or "clean"}

### Diagnostics (if FAIL or PARTIAL)

SYMPTOM: {observable problem}
FIX: {proposed change}
RESULT: {expected outcome}
```

### Session Summary Table

ALWAYS produce this at end of every work session:

```markdown
## Session Summary -- {date}

| Pass     | Lane | Objective                        | Outcome | Method                     |
|----------|------|----------------------------------|---------|----------------------------|
| L1-P01   | L1   | Card layout matches design spec  | PASS    | CSS Grid                   |
| L2-P01   | L2   | Task data fetches from API       | PASS    | React Query                |
| L1-P02   | L1   | Sidebar collapse animation       | PASS    | CSS transition             |
| L1-P03   | L1   | Load time under 500ms            | FAIL    | React.memo (insufficient)  |
| L1-P04   | L1   | Load time under 500ms            | PASS    | react-window virtualization|

**Total passes**: 5
**Success rate**: 4/5 (80%) -- 1 required pivot
**Lanes advanced**: L1 (phase B complete), L2 (phase C in progress)
**Circles detected**: 0
**Key learning**: Memo optimization insufficient for large lists; virtualization required.
**Next session**: {What to work on next + which lanes are active}
```

---

## Related Directives

- -> See PHILOSOPHY.md for the five-lens foundation (kaizen-deming-unix-AI-native-parallel) that governs all iteration decisions
- -> See QUALITY.md for pass acceptance criteria (verification gates G0-G9), completion loop, and quality gate definitions
- -> See DESIGN.md for Immutable Identity Block color/typography values, visual warmth gradient as diagnostic signal, and design gate criteria
- -> See TEAM.md for Council escalation protocol, three-tier AI model selection, and parallel agent fan-out patterns
- -> See ARCHITECTURE.md for module structure, Architecture Brief format, ADR protocol, and decomposition guidance
- -> See OPERATIONS.md for dev environment setup, dashboard format, MVP tracker, and framework versioning protocol

---

## 11. Activation Infrastructure

### 11.1 Activation Principle

> "Measurement must be a byproduct of work, not a separate activity." (Deming)
> Every tracking system below is triggered automatically. Zero manual data entry required.

### 11.2 Circle Detection Activation

- Currently: designed in §5 but circle-log.md was never populated
- Activation: hook in `.claude/hooks/` scans conversation for patterns:
  - Type 1: same question matching existing ADR text (revisited decision)
  - Type 2: same error/fix pattern attempted 2+ times (repeated failure)
  - Type 3: scope item added then removed then re-added (scope oscillation)
- Auto-appends to `.claude/projects/*/memory/circle-log.md` with CIRCLE-{NNN} format
- Surfaced in session-start summary: "Aria notes: 2 open circles from last session"

### 11.3 Session Handoff Activation

- Currently: designed in §10 but session-handoff.md was never populated
- Activation: post-session hook auto-generates handoff from:
  - git diff since session start
  - tasks completed
  - open circles
  - current swim lane state
- Session-start hook reads last handoff and presents 5-line summary in Aria's voice
- Storage: `.claude/projects/*/memory/session-handoff.md`

### 11.4 Trend Log Activation

- Currently: append-trend-log.sh script exists but TREND-LOG.csv was never created
- Activation: git post-commit hook auto-appends to `Docs/TREND-LOG.csv`
- Columns: date, session_id, passes, failures, pivots, build_time_s, test_count, circles_detected, tier_used
- Marcus tracks: "Build velocity is up 15% this week"
- Weekly team report reads trend log for trajectory analysis

### 11.5 TODO Pipeline Activation

- Currently: designed in §6 but no TODO-NNN items exist
- Activation: auto-extract from task tools + conversation
- When TaskCreate is called, auto-create corresponding TODO-{NNN} entry
- Map task status to PDSA state: pending→Plan, in_progress→Do, completed→Study/Act
- Auto-assign lane based on file paths in task description

### 11.6 Pass ID Automation

- Currently: Pass IDs (L1-P01) prescribed but never used
- Activation: session orchestrator auto-assigns
- Format: P{NN} within session, L{N}-P{NN} when swim lanes active
- Incremented automatically at each EVALUATE phase
- Logged in session handoff record

### 11.7 PDSA Study Automation

- Currently: PDSA Study sections (expected vs observed) never populated except token-time calibration
- Activation: after each gate run, auto-populate Study template:
  ```
  ## Study: {pass_id}
  **Expected:** {from Plan section}
  **Observed:** {from gate results}
  **Delta:** {difference}
  **Decision:** Standardize / Revise / Flag / Rollback / Re-brief
  ```
- Gate runner output feeds directly into Study section
- Storage: appended to iteration log

### 11.8 Hook Wiring Summary

| Hook | Trigger | Writes To | Read By |
|------|---------|-----------|---------|
| `.claude/hooks/post-commit` | Every git commit | Docs/TREND-LOG.csv | Team Report, Aria |
| `.claude/hooks/session-start` | Session begins | stdout (5-line summary) | Developer |
| `.claude/hooks/session-end` | Session ends | session-handoff.md, CHARACTER-TRACKING.md | Next session |
| `scripts/detect-circles.sh` | Every EVALUATE phase | circle-log.md | Circle Detection §5 |
| `scripts/generate-council-report.sh` | After Council session | Docs/council-sessions/ | Team Report |
| `scripts/generate-team-report.sh` | Weekly / phase end | Docs/team-reports/ | Retrospective |

---

## Related Directives

- → See PHILOSOPHY.md — five-lens foundation; PDSA structures the outer loop; Parallel enables swim lanes
- → See GENESIS.md — bootstrap sequence feeds the first pass; swim lane DAG created during kickoff
- → See TEAM.md — three-tier model determines who executes passes; Council resolves escalations
- → See ARCHITECTURE.md — module structure constrains pass scope; MAP manifests track module state
- → See QUALITY.md — verification gates G0-G9 run within passes; completion loop automates verify-fix
- → See DESIGN.md — identity blocks enforced across passes; design gates integrate into verification
- → See HANDHOLDING.md — guide panel tracks pass and swim lane state for newcomers
- → See OPERATIONS.md — trend log receives pass data; session handoff enables context continuity
- → See CHARACTER-TRACKING.md — persona performance tracked per pass; calibration uses iteration data

---

## Framework Navigation

> **You Are Here:** `ITERATION.md` — Pass loop, swim lanes, circle detection, activation infrastructure
> **Core Method:** Kaizen · Deming · Unix · AI-Native · Parallel → PHILOSOPHY.md

| File | When To Read |
|------|-------------|
| CLAUDE.md | Session start, operating mode routing, unbreakable rules |
| PHILOSOPHY.md | Principle check, five-lens test, enforcement rules |
| GENESIS.md | New project kickoff, requirements interview, probe/bootstrap |
| TEAM.md | AI model selection, Council decisions, persona profiles |
| ARCHITECTURE.md | Module design, dependency management, MAP manifests |
| ITERATION.md | ★ You are here |
| QUALITY.md | Gate verification G0-G9, completion loop, testing |
| DESIGN.md | Visual identity, design gates, component system |
| HANDHOLDING.md | Newcomer guidance, glossary, preemptive help |
| OPERATIONS.md | Dev environment, dashboard, MVP tracker, reporting |
| CHARACTER-TRACKING.md | Team performance, calibration, persona metrics |

> **If lost:** Start at CLAUDE.md. If a concept is unclear, check HANDHOLDING.md §9 Glossary.
> **If stuck:** ITERATION.md §7 Failure Gates (1-fail retry, 2-fail pivot, 3-fail Council).
> **If quality uncertain:** QUALITY.md §1 Gate Runner. If design: DESIGN.md §5 Design Gates.
