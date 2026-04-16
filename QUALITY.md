# QUALITY.md -- Verification Gates, Completion Loop & Quality Assurance

> **Kaizen** -- Continuous verification loops; every pass captures evidence; every cycle improves the process.
> **Unix** -- Each test checks one thing; each gate reports one status; each monitor has one concern.
> **Deming** -- Design quality in from the start; measure systems not events; the completion loop IS the PDSA Study phase.
> **AI-Native** -- Gate reports are structured JSON; AI agents consume them without parsing prose; evidence is machine-readable.
> **Parallel** -- Gates run concurrently when independent; fan-out verification across modules; serialize only at sync points.
> If it is not verified, it is not done. If the evidence is not recorded, the verification did not happen.

> **Persona Ownership:** Marcus (BUILD) owns testing + trifecta. Aria orchestrates gates. Pixel runs visual verification. Dr. Kai designs rollback drills. → See CHARACTER-TRACKING.md

---

## 1. Verification Gates (G0-G9)

Ten gates from environment to release. Each gate is PASS/FAIL/SKIP with timestamp and evidence. Gates are the structural backbone of the completion loop.

### 1.1 Gate Definitions

| Gate | Name | Question | Evidence |
|------|------|----------|----------|
| **G0** | Environment | Toolchain, runtime, and dependencies available? | Command existence checks, version checks |
| **G1** | Build | Compiles/bundles without errors? | Build log, zero error count |
| **G2** | Unit | All unit tests pass? | Test runner output, pass/fail/skip counts |
| **G3** | Integration | Smoke tests and integration tests pass? | Test runner output, import checks, startup checks |
| **G4** | Benchmark | Performance within bounds? (if applicable) | Benchmark output, threshold comparison |
| **G5** | Domain-A | Project-specific gate (define at kickoff) | Project-defined evidence |
| **G6** | Domain-B | Project-specific gate (define at kickoff) | Project-defined evidence |
| **G7** | Domain-C | Project-specific gate (define at kickoff) | Project-defined evidence |
| **G8** | Design | Design gate review passes? (aesthetic + correctness) | Design gate verdict + criteria scores |
| **G9** | Release | All prior gates pass AND CLAUDE.md accurate? | Gate summary, CLAUDE.md diff check |

### 1.2 Gate Rules

ALWAYS run G0 before any other gate. A failed G0 makes all subsequent gates meaningless.
ALWAYS run G1 before G2-G4. If it does not build, do not test it.
ALWAYS define G5-G7 at project kickoff (Council Session #1). Leave as SKIP if not applicable.
NEVER skip G8 for projects with UI. Design gates are not optional polish.
NEVER pass G9 if any prior gate is FAIL. G9 is the conjunction of all gates.
WHEN G4 (Benchmark) is not applicable, THEN mark it SKIP with reason "no benchmark targets defined."

### 1.3 Domain Gate Examples

| Project Type | G5 | G6 | G7 |
|-------------|----|----|-----|
| iOS app | Simulator launch + smoke | Crash report check (zero new crashes) | Accessibility audit |
| Web app | Lighthouse score thresholds | Offline capability check | SEO meta verification |
| CLI tool | Help text + flag parsing | Rollback drill (see section 7) | Man page generation |
| API service | Contract test (OpenAPI match) | Load test threshold | Rate limiter verification |
| Multi-module | Health matrix pass (see section 6) | Cross-module integration | Rollback drill |

### 1.4 Gate Output Format

Gate output goes to `.build/verify/gates.json`. Produced on every verification run, even on failure.

```json
{
  "status": "passed|failed",
  "mode": "fast|full",
  "generatedAt": "2026-03-26T14:30:00Z",
  "project": "{project-name}",
  "cycle": 1,
  "gates": [
    {
      "id": "G0",
      "name": "Environment",
      "status": "passed",
      "timestamp": "2026-03-26T14:30:01Z",
      "detail": "All commands available: node 22.x, npm 10.x, playwright installed.",
      "evidence": "command-check.log"
    },
    {
      "id": "G1",
      "name": "Build",
      "status": "passed",
      "timestamp": "2026-03-26T14:30:12Z",
      "detail": "Build completed in 8.3s, 0 errors, 0 warnings.",
      "evidence": "build.log"
    },
    {
      "id": "G2",
      "name": "Unit",
      "status": "failed",
      "timestamp": "2026-03-26T14:30:45Z",
      "detail": "42/43 passed, 1 failed: test_parse_duration",
      "evidence": "unit-test-output.log"
    }
  ]
}
```

ALWAYS produce a gate report on every verification run. The report is evidence. NEVER delete gate reports; archive them with the cycle.

### 1.5 Gate Runner Script Template

```bash
#!/bin/bash
# run-gates.sh — Run verification gates G0-G9
set -euo pipefail

OUTPUT_DIR=".build/verify"
mkdir -p "$OUTPUT_DIR"
GATES_FILE="$OUTPUT_DIR/gates.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OVERALL="passed"

# Initialize gates array
echo '{"status":"running","mode":"'"${MODE:-fast}"'","generatedAt":"'"$TIMESTAMP"'","gates":[' > "$GATES_FILE"

run_gate() {
  local id="$1" name="$2" cmd="$3"
  local gate_start gate_status detail
  gate_start=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  if eval "$cmd" > "$OUTPUT_DIR/${id}.log" 2>&1; then
    gate_status="passed"
    detail="Gate passed."
  else
    gate_status="failed"
    detail="Gate failed. See ${id}.log"
    OVERALL="failed"
  fi
  echo "{\"id\":\"$id\",\"name\":\"$name\",\"status\":\"$gate_status\",\"timestamp\":\"$gate_start\",\"detail\":\"$detail\",\"evidence\":\"${id}.log\"}"
}

# G0: Environment
G0=$(run_gate "G0" "Environment" "which node && which npm && node --version")
echo "$G0" >> "$GATES_FILE"

# G1: Build (only if G0 passed)
if echo "$G0" | grep -q '"passed"'; then
  echo "," >> "$GATES_FILE"
  G1=$(run_gate "G1" "Build" "npm run build 2>&1")
  echo "$G1" >> "$GATES_FILE"
fi

# G2: Unit
echo "," >> "$GATES_FILE"
run_gate "G2" "Unit" "npm test 2>&1" >> "$GATES_FILE"

# G3: Integration
echo "," >> "$GATES_FILE"
run_gate "G3" "Integration" "npm run test:integration 2>&1" >> "$GATES_FILE"

# Close JSON
echo "]}" >> "$GATES_FILE"
sed -i.bak "s/\"running\"/\"$OVERALL\"/" "$GATES_FILE" && rm -f "$GATES_FILE.bak"

echo "Gate report: $GATES_FILE"
echo "Overall: $OVERALL"
[ "$OVERALL" = "passed" ] && exit 0 || exit 1
```

Adapt per project. The template covers G0-G3; add G4-G9 as project demands.

---

## 2. Completion Loop

The completion loop is the automated PDSA Study phase. It runs all gates, collects failures, applies fixes, and re-verifies until all gates pass or a hard stop is triggered.

### 2.1 Loop Steps

```
1. RUN ALL GATES (G0-G9)
2. COLLECT FAILURES — list every gate with status "failed"
3. FOR EACH FAILURE:
   a. DIAGNOSE — symptom (what broke) -> fix (what to change) -> result (expected after fix)
   b. APPLY FIX — one fix per failure, one at a time
   c. RE-RUN AFFECTED GATES — only the gates that failed
4. REPEAT until all gates pass OR hard stop triggers
5. PRODUCE summary.json
6. APPEND to Trend Log (-> See OPERATIONS.md §Trend Log)
```

### 2.2 Hard Stops

| Condition | Trigger | Action |
|-----------|---------|--------|
| Max cycles | 10 cycles without full pass | Escalate to THINK tier or human |
| Same-gate failure | 3 consecutive failures on same gate | Stop fixing that gate; escalate |
| Regression | Fix for gate X causes gate Y to fail | Revert fix; investigate coupling |
| Blast radius | Fix touches >3 files outside the target area | Halt; architecture review |

WHEN a hard stop triggers, THEN the completion loop MUST produce a partial summary.json with `"status": "escalated"` and the reason. NEVER silently abandon a loop.

### 2.3 Diagnostic Format

Every failure diagnosis uses the canonical symptom-fix-result format:

```
Symptom: G2 Unit failed — test_parse_duration expects 3600 but got 3599
Fix: Off-by-one in duration rounding logic (src/parser.ts:42)
Result: test_parse_duration passes; all other G2 tests unaffected
```

-> See ITERATION.md for the full diagnostic protocol.

### 2.4 Completion Loop Artifacts

```
.build/completion-loop/
  summary.json                         # cycle count, final status, timestamp
  complaints.json                      # all failures with lifecycle
  quality-gate-consultations.jsonl     # per-failure persona consultations (if applicable)
  trend-entry.json                     # entry appended to Trend Log
  cycles/
    cycle-001/
      gates.json                       # gate report for this cycle
      diagnostics.json                 # symptom/fix/result for each failure
    cycle-002/
      gates.json
      diagnostics.json
```

### 2.5 summary.json Format

```json
{
  "status": "passed|failed|escalated",
  "cycles": 3,
  "maxCycles": 10,
  "startedAt": "2026-03-26T14:30:00Z",
  "completedAt": "2026-03-26T14:45:22Z",
  "gateResults": {
    "G0": "passed",
    "G1": "passed",
    "G2": "passed (cycle 2)",
    "G3": "passed",
    "G4": "skipped",
    "G5": "passed",
    "G6": "skipped",
    "G7": "skipped",
    "G8": "passed",
    "G9": "passed"
  },
  "complaintsResolved": 1,
  "complaintsOpen": 0,
  "escalationReason": null
}
```

### 2.6 Complaint Lifecycle

```
open -> investigating -> fixed -> verified
          |                         |
          +-- (if reopen) -------> open
```

NEVER mark a complaint as `verified` without a recovery artifact proving it (test pass, build log, runtime confirmation). A complaint closed without evidence is a complaint that will recur.

### 2.7 Complaint Severity

Rank every complaint by severity. Severity determines triage order -- the loop processes p0 before p1.

| Severity | Definition | Triage |
|----------|-----------|--------|
| **p0** | Blocks core flow, no workaround | Fix before next cycle |
| **p1** | Blocks core flow, workaround exists | Fix this session |
| **p2** | Non-core regression | Fix when convenient |
| **p3** | Cosmetic or minor | Batch with next release |

### 2.8 Core Flow Tags

Tag each complaint with the user flow it affects. Define core flows at project kickoff.

```
CORE_FLOWS = {"play", "search", "checkout", "sync", "import"}  # example
```

WHEN a complaint affects a core flow AND severity is p0, THEN it blocks the Release Gate (G9).
WHEN a complaint affects only non-core flows, THEN it may be deferred with a documented tradeoff.

---

## 3. Quality Trifecta: FORMAT + LINT + TYPECHECK

Run all three before EVERY commit. No exceptions. This is the Unix principle applied to code quality: three sharp tools, each checking one dimension.

```
1. FORMAT --> Is code formatted consistently?
2. LINT   --> Are there code quality issues?
3. TYPE   --> Does the type system accept the code?
```

Format without lint = looks consistent but has bugs.
Lint without format = correct but inconsistent.
Both without types = clean but crashes at runtime.
All three are MANDATORY.

### 3.1 Commands by Language

| Language | Format | Lint | Type Check |
|----------|--------|------|------------|
| **Rust** | `cargo fmt --check` | `cargo clippy -- -D warnings` | `cargo check` |
| **TypeScript/JS** | `npx prettier --check "src/**/*.{ts,tsx,js,jsx}"` | `npx eslint src/` | `npx tsc --noEmit` |
| **Python** | `black --check .` | `ruff check .` | `mypy .` |
| **Swift** | `swift-format lint --recursive Sources/` | `swiftlint lint` | `swift build` |

### 3.2 One-Liners

```bash
# Rust
cargo fmt --check && cargo clippy -- -D warnings && cargo check

# TypeScript
npx prettier --check "src/**" && npx eslint src/ && npx tsc --noEmit

# Python
black --check . && ruff check .

# Swift
swift-format lint --recursive Sources/ && swiftlint lint && swift build
```

### 3.3 Pre-Commit Hook Template

```bash
#!/bin/sh
# .git/hooks/pre-commit
echo "Running quality trifecta..."

if [ -f "Cargo.toml" ]; then
  cargo fmt --check && cargo clippy -- -D warnings && cargo check
elif [ -f "package.json" ]; then
  npx prettier --check "src/**/*.{ts,tsx,js,jsx}" && npx eslint src/ && npx tsc --noEmit
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  black --check . && ruff check .
elif [ -f "Package.swift" ]; then
  swift-format lint --recursive Sources/ && swiftlint lint && swift build
fi

if [ $? -ne 0 ]; then
  echo "Quality trifecta FAILED. Fix issues before committing."
  exit 1
fi
```

ALWAYS install this hook at project bootstrap. The quality trifecta is G1's prerequisite -- if the trifecta fails, the build gate is meaningless.

---

## 4. Testing Pyramid (Inverted, Offline-First)

The pyramid is inverted from traditional software. The widest layer is offline UI tests. This is the Kaizen principle applied to testing: optimize for speed and determinism so you can iterate faster.

```
              /\
             /  \           Live Integration Tests
            /    \          (manual, pre-release only)
           /------\
          / SMOKE  \        Import checks, startup checks
         /----------\
        / UNIT TESTS \      Pure functions, business logic
       /--------------\
      / OFFLINE UI TESTS \  Playwright against file://
     /____________________\ Widest layer. No server. Fast. Deterministic.
```

### 4.1 Offline-First Philosophy

**Tests MUST NOT require running servers.** Defined ONCE here; applies everywhere.

| Factor | Online Tests | Offline Tests |
|--------|-------------|---------------|
| Speed | 10-60s (server startup) | 1-5s |
| Reliability | Flaky (network, ports) | Deterministic |
| Portability | Requires environment | Runs anywhere |
| CI-friendly | Complex setup | Install and run |

### 4.2 The Offline Pattern

Playwright opens `file:///path/to/index.html`. No HTTP server. The static HTML/JS/CSS loads in a real browser. Everything that does not require server responses is testable offline.

```javascript
const APP_URL = 'file:///Users/mikeudem/Projects/index.html';

test.beforeEach(async ({ page }) => {
  await page.goto(APP_URL);
  await page.waitForFunction(() => document.readyState === 'complete');
});
```

### 4.3 Testable Offline vs. Requires Online

**Testable Offline**: Layout, click handlers, form validation (client-side), state management (localStorage), navigation, CSS responsive behavior, error states, empty states, accessibility.

**Requires Online**: API responses, database operations, third-party integrations, real auth flows, server file uploads. Use the Live Integration layer for these -- run manually, NEVER in CI.

### 4.4 3-Layer Test Stack

Every feature MUST pass all three layers before shipping.

```
+----------------------------------------------------------+
| Layer 3: BEHAVIORAL -- Does it feel right?                |
| Animation timing, interaction feedback, CLS, perf         |
+----------------------------------------------------------+
| Layer 2: VISUAL -- Does it look right?                    |
| Screenshots, design system compliance, regression         |
+----------------------------------------------------------+
| Layer 1: FUNCTIONAL -- Does it work?                      |
| Assertions, API checks, DOM state, unit tests             |
+----------------------------------------------------------+
```

**Layer 1: FUNCTIONAL** -- Automated. MUST pass before anything else is evaluated.

```javascript
test('clicking add task creates a new task', async ({ page }) => {
  await page.locator('[data-testid="task-title"]').fill('Buy groceries');
  await page.locator('[data-testid="add-task-btn"]').click();

  await expect(page.locator('.task-list .task-item')).toHaveCount(1);
  await expect(page.locator('.task-item').first()).toContainText('Buy groceries');
});
```

Pass criteria: All assertions green. Zero failures. A flaky test is a failing test you are ignoring.

**Layer 2: VISUAL** -- Screenshot-based. Catches regressions that functional tests miss.

```javascript
test('dashboard matches visual baseline', async ({ page }) => {
  await page.goto(APP_URL);
  await page.waitForSelector('.dashboard-loaded');

  await expect(page).toHaveScreenshot('dashboard-baseline.png', {
    maxDiffPixelRatio: 0.01,
  });
});
```

Pass criteria: No regressions. AI analysis returns PASS. Both dark and bright modes verified. All breakpoints checked.

**Layer 3: BEHAVIORAL** -- Animation timing, interaction response, perceived performance.

```javascript
test('sidebar collapse animation completes in under 400ms', async ({ page }) => {
  const start = Date.now();
  await page.locator('[data-testid="sidebar-toggle"]').click();
  await page.waitForFunction(() => {
    const sidebar = document.querySelector('.sidebar');
    return getComputedStyle(sidebar).width === '60px';
  });
  const duration = Date.now() - start;

  expect(duration).toBeLessThan(400);
  expect(duration).toBeGreaterThan(100); // too fast = jarring
});

test('scrolling does not cause layout shift', async ({ page }) => {
  const cls = await page.evaluate(async () => {
    return new Promise(resolve => {
      let clsValue = 0;
      const observer = new PerformanceObserver(list => {
        for (const entry of list.getEntries()) {
          if (!entry.hadRecentInput) clsValue += entry.value;
        }
      });
      observer.observe({ type: 'layout-shift', buffered: true });
      window.scrollTo(0, document.body.scrollHeight);
      setTimeout(() => { observer.disconnect(); resolve(clsValue); }, 2000);
    });
  });
  expect(cls).toBeLessThan(0.1);
});
```

Pass criteria: Animations smooth (no jank). Interactions respond within 100ms for feedback, 300ms for completion. No layout shifts during interaction.

### 4.5 Layer Coverage Goals

| Layer | Coverage Target | Automation Level |
|-------|----------------|-----------------|
| Functional | 90%+ of critical paths | Fully automated |
| Visual | Key pages + components | Semi-automated (screenshots + AI) |
| Behavioral | Core interactions | Partially automated + manual QA |

### 4.6 Mock Rules

| Situation | Mock? | Reasoning |
|-----------|-------|-----------|
| External API (payment, email) | Yes | Expensive, slow, side effects |
| Database (unit tests) | Yes | Speed, isolation |
| Database (integration tests) | **No** | Test real queries -- mocks hide production divergence |
| `sqlite3` connections (integration tests) | **NEVER** | Use a real temp-file database; mock/prod divergence breaks migrations |
| Internal module (same codebase) | No | Mocking your own code hides bugs |
| Time/dates | Yes | Deterministic tests need fixed time |
| Network (Playwright) | Route interception | Control responses, test error paths |
| Python subprocesses | Use `sys.executable` | NEVER bare `python` -- wrong interpreter in venvs |

Mock the boundary, not the internals. Mock services you do not control. NEVER mock internal functions -- test them for real.

```javascript
// GOOD: Mock the external boundary
await page.route('**/api/external-service/**', (route) => {
  route.fulfill({ status: 200, body: JSON.stringify({ result: 'mocked' }) });
});

// BAD: Mock an internal utility
vi.mock('./utils/formatDate');  // Just test it for real.
```

### 4.7 Test Organization

Co-locate unit tests. Separate E2E tests.

```
project/
  src/
    components/
      Button.tsx
      Button.test.tsx      <- co-located unit test
    engine/
      tasks.ts
      tasks.test.ts        <- co-located unit test
  tests/
    e2e/
      dashboard.spec.ts    <- separate E2E test
    fixtures/
      sample-data.json     <- shared test data
```

### 4.8 Naming Conventions

| Test Type | Pattern | Example |
|-----------|---------|---------|
| Unit test | `<module>.test.{ts,js,py}` | `tasks.test.ts` |
| Unit test (Rust) | inline `#[cfg(test)]` | |
| Component test | `<Component>.test.tsx` | `Button.test.tsx` |
| E2E test | `<feature>.spec.{ts,js}` | `dashboard.spec.ts` |
| Pytest | `test_<module>.py` | `test_tasks.py` |

### 4.9 Selector Best Practices

```javascript
// BEST: data-testid -- explicit, stable, decoupled
await page.locator('[data-testid="submit-button"]').click();

// GOOD: semantic role
await page.getByRole('button', { name: 'Submit' }).click();

// GOOD: label text
await page.getByLabel('Email address').fill('user@example.com');

// AVOID: deeply nested selectors -- brittle
await page.locator('div.container > form > div:nth-child(3) > button').click();

// AVOID: auto-generated class names -- change on every build
await page.locator('.css-1a2b3c').click();
```

If a refactor that does not change behavior breaks your selector, the selector is too brittle. Use `data-testid` for any element tests interact with.

### 4.10 Workflow Recovery Tests

For long-running processes (pipeline coordinators, edit chains, multi-step workflows), test that a partially-completed workflow recovers to the correct state without double-processing.

```python
def test_workflow_recovery_after_interrupt():
    """Test that a partially-completed pipeline recovers correctly."""
    coordinator = ProcessingPipelineCoordinator()
    coordinator.start_task("task-001")
    coordinator.simulate_interrupt()  # Kill mid-flight
    coordinator.recover()             # Should resume, not restart
    assert coordinator.get_status("task-001") == "completed"
    assert coordinator.completed_steps == expected_steps  # No double-processing

def test_recovery_cleans_partial_output():
    """Partial outputs from interrupted run must be cleaned up or merged."""
    coordinator = ProcessingPipelineCoordinator()
    coordinator.start_task("task-002")
    coordinator.simulate_interrupt_at_step(2)
    coordinator.recover()
    # Output must equal what a clean run would produce
    assert coordinator.get_output("task-002") == clean_run_output
```

ALWAYS write recovery tests when:
- A pipeline has 3+ sequential steps
- State is persisted mid-run (to SQLite, disk, or memory)
- The process can be interrupted (signal, crash, timeout)

---

## 5. Design Gates

Design gates are quality bars for UI work. They are G8 in the verification gate pipeline. Derived from the five-criteria system, generalized for any project.

-> See DESIGN.md §5 for the full gate criteria, persona system, and when to run design gates.
-> Simpod: All UI changes must pass the Steve Jobs lens (minimalism, fewer taps) AND Murakami lens (aesthetic restraint, emotional clarity) before implementation. See DESIGN.md §5.5.

### 5.1 Integration with Verification Pipeline

WHEN a project has UI, THEN G8 (Design Gate) is MANDATORY.
WHEN a project has no UI, THEN G8 is SKIP with reason "no UI components."
WHEN G8 fails with `fail` or `preempt`, THEN the completion loop MUST NOT advance to G9.

### 5.2 Design Gate Criteria (Quick Reference)

| # | Criterion | Question |
|---|-----------|----------|
| 1 | **GLANCEABLE** | Can the user understand the screen in <2 seconds? |
| 2 | **PHYSICAL** | Does the interaction have momentum, snap, weight? |
| 3 | **DELIGHTFUL** | Is there a moment of "oh that's nice"? |
| 4 | **MINIMAL** | Does every element earn its place? |
| 5 | **UNIX** | Does this component do one thing and compose with others? |

### 5.3 Design Gate Outcomes

| Outcome | Meaning | Gate Status |
|---------|---------|-------------|
| `pass` | Meets all criteria | G8 = PASS |
| `warn` | Meets most, concern on 1-2 | G8 = PASS with advisory |
| `fail` | Fails 2+ criteria | G8 = FAIL |
| `preempt` | Critical issue found | G8 = FAIL (blocks everything) |

### 5.4 GUI Qualification Assertions

Design rules are not aspirational -- they are testable. Write GUI Qualification assertions as code and run them as part of the visual QA layer.

| Check Name | Assertion | Design Rule |
|-----------|-----------|-------------|
| `max-3-accents` | `accentCount <= 3` | Max 3 rule (-> See DESIGN.md §3.3) |
| `no-hardcoded-colors` | `hardcodedColorCount == 0` | Hardcode ban |
| `touch-targets-44px` | `minTouchTargetSize >= 44` | Mobile touch target |
| `typography-3-roles` | `fontRoleCount <= 3` | 3 typography roles only |
| `one-primary-cta` | `primaryButtonsPerSection <= 1` | One primary CTA per section |
| `max-3-animations` | `activeAnimationCount <= 3` | Max 3 active animations |
| `max-3-motifs` | `decorativeMotifCount <= 3` | Max 3 decorative motifs |

NEVER ship if GUI Qualification fails.
ALWAYS store qualification code in test targets, NEVER in production code.
WHEN a design rule cannot be written as a boolean assertion, THEN it is not specific enough -- make it specific before shipping.

---

## 6. Health Matrix

For multi-module projects: run isolation tests (each module independently) AND composition tests (modules wired together). Report as an NxN matrix. This is the Unix principle verified at the architecture level -- each module works alone AND composes correctly.

### 6.1 Two Dimensions

| Dimension | Tests | What It Catches |
|-----------|-------|-----------------|
| **Isolation** | Each module runs its own test suite independently | Implicit dependencies, leaked state, missing imports |
| **Composition** | Modules wired together, integration points tested | Interface mismatches, version conflicts, protocol drift |

### 6.2 Matrix Format

```
             Module-A  Module-B  Module-C  Module-D
Isolation       PASS      PASS      FAIL      PASS
Composition
  A + B         PASS
  A + C                             FAIL
  B + C                             FAIL
  A + B + C                         FAIL
  Full Stack                        FAIL
```

Target: 100% PASS in both dimensions.

### 6.3 Matrix Report (JSON)

```json
{
  "generatedAt": "2026-03-26T15:00:00Z",
  "isolation": {
    "module-a": {"status": "passed", "tests": 42, "passed": 42, "failed": 0},
    "module-b": {"status": "passed", "tests": 31, "passed": 31, "failed": 0},
    "module-c": {"status": "failed", "tests": 18, "passed": 15, "failed": 3},
    "module-d": {"status": "passed", "tests": 27, "passed": 27, "failed": 0}
  },
  "composition": {
    "a+b": {"status": "passed", "detail": "API contract matched"},
    "a+c": {"status": "failed", "detail": "module-c exports changed signature"},
    "full-stack": {"status": "failed", "detail": "blocked by a+c failure"}
  },
  "overall": "failed",
  "failureRoot": "module-c isolation failures cascade to composition"
}
```

### 6.4 Health Matrix Rules

ALWAYS run isolation tests before composition tests. A module that fails isolation will contaminate composition results.
ALWAYS trace composition failures back to isolation results first. Most composition failures originate from an isolation defect.
WHEN a module passes isolation but fails composition, THEN the interface contract is wrong -- check the MAP manifest (-> See ARCHITECTURE.md §MAP).
WHEN adding a new module, THEN add it to the health matrix before writing the first feature.
NEVER skip the health matrix for projects with 3+ modules. Skipping it means trusting that composition works without evidence.

### 6.5 Health Matrix as G5 Domain Gate

For multi-module projects, the health matrix is the natural G5 domain gate:

```json
{
  "id": "G5",
  "name": "Health Matrix",
  "status": "failed",
  "detail": "Isolation: 3/4 pass. Composition: 2/5 pass. Root: module-c.",
  "evidence": "health-matrix.json"
}
```

---

## 7. Rollback Drills

Rollback drills are chaos-engineering-style verification: intentionally test that you can undo what you are about to do. This is the Deming principle made concrete -- ALWAYS write the rollback plan before writing the implementation, then PROVE the plan works.

### 7.1 When to Run

ALWAYS run a rollback drill before:
- Irreversible deployments (production pushes, database migrations, DNS changes)
- ADR implementations (Architecture Decision Records with high-impact structural changes)
- Schema migrations that drop columns or tables
- Infrastructure changes (new services, provider switches)
- Any change tagged "irreversible" in the PDSA Plan

### 7.2 Drill Steps

```
1. BRANCH — create a drill branch from the current state
2. IMPLEMENT — apply the change (or simulate it for destructive changes)
3. VERIFY FORWARD — confirm the change works as intended
4. EXECUTE ROLLBACK — follow the documented rollback plan exactly
5. VERIFY CLEAN STATE — confirm the system is identical to pre-change state
6. REPORT — produce the rollback drill report
7. DECIDE — if drill passed, proceed with real implementation; if failed, revise plan
```

### 7.3 Drill Report Format

```json
{
  "feature": "Add multi-tenant database schema",
  "drillDate": "2026-03-26T16:00:00Z",
  "planSummary": "Rollback: drop new tables, restore backup, revert migration record",
  "result": "CLEAN|PARTIAL|FAILED",
  "forwardVerified": true,
  "rollbackVerified": true,
  "cleanState": true,
  "issuesFound": [],
  "timeToRollback": "2m 34s",
  "drillBranch": "drill/multi-tenant-rollback-2026-03-26"
}
```

### 7.4 Result Classification

| Result | Meaning | Action |
|--------|---------|--------|
| **CLEAN** | System returned to identical pre-change state | Proceed with implementation |
| **PARTIAL** | System mostly restored but residual artifacts remain | Fix rollback plan, re-drill |
| **FAILED** | Rollback did not work or caused new issues | Do NOT proceed. Redesign the change or the rollback plan |

### 7.5 Integration with PDSA and Verification Gates

The rollback drill IS the PDSA Plan validation. The PDSA cycle says "write the rollback plan before writing the implementation" (-> See PHILOSOPHY.md §Deming Principles). The drill proves the plan works.

WHEN a rollback drill result is FAILED, THEN the PDSA Plan is incomplete -- do NOT proceed to the Do phase.
WHEN a rollback drill result is PARTIAL, THEN the plan needs revision -- fix it and re-drill.
WHEN a rollback drill result is CLEAN, THEN the Plan phase is validated -- proceed to Do.

### 7.6 Rollback Drill as Domain Gate

For projects with irreversible decisions, the rollback drill can serve as G5, G6, or G7:

```json
{
  "id": "G6",
  "name": "Rollback Drill",
  "status": "passed",
  "detail": "CLEAN rollback in 2m 34s. Zero residual artifacts.",
  "evidence": "rollback-drill-2026-03-26.json"
}
```

### 7.7 Drill Checklist

Before running the drill, verify:

- [ ] Rollback plan is documented (not just "we'll figure it out")
- [ ] Rollback plan specifies exact commands/steps (not vague instructions)
- [ ] Backup strategy is defined (if applicable)
- [ ] Success criteria for "clean state" are explicit and measurable
- [ ] Time budget for rollback is defined (how long is acceptable?)
- [ ] The drill branch is isolated from main work

---

## 8. Pass Acceptance Criteria (4 Gates)

For each iteration pass to be marked PASS, ALL four acceptance gates MUST clear.
-> See ITERATION.md for the pass loop and failure gate definitions.

```
Gate 1: TARGET VISIBLE   -- The intended change is visible and correct
Gate 2: IDENTITY STABLE  -- Locked elements are unchanged (-> See DESIGN.md §2 Identity System)
Gate 3: NO NEW DEFECTS   -- No regressions introduced
Gate 4: TESTS PASSING    -- ALL automated tests pass (not "all except the one I broke")
```

### 8.1 Decision Matrix

| Gate 1 | Gate 2 | Gate 3 | Gate 4 | Verdict |
|--------|--------|--------|--------|---------|
| PASS | PASS | PASS | PASS | **PASS** -- proceed to next pass |
| PASS | PASS | PASS | FAIL | **FAIL** -- fix the broken test |
| PASS | PASS | FAIL | PASS | **FAIL** -- fix the regression |
| PASS | FAIL | * | * | **FAIL** -- revert identity change |
| FAIL | * | * | * | **FAIL** -- objective not met |

If a test fails because you intentionally changed behavior, update the test as part of the same pass. The suite MUST be green before PASS.

### 8.2 Failure Gates for Visual QA

These gates feed into the iteration engine failure gates.
-> See ITERATION.md for the canonical 1/2/3-fail escalation.

**Gate A: 3 Consecutive Failures on Same Element**

```
Attempt 1: Fix applied -> screenshot -> still broken
Attempt 2: Different fix -> screenshot -> still broken
Attempt 3: Third approach -> screenshot -> still broken

GATE TRIGGERED: Stop. Escalate to human review.
```

Likely causes: CSS specificity conflict, browser rendering bug, misunderstood expected state.

**Gate B: Regression in Unrelated Area**

```
Fix: Changed header height for new logo
Result: Header correct, BUT footer now overlaps content

GATE TRIGGERED: Blast radius exceeded. Halt and investigate.
```

ALWAYS revert the fix. Investigate coupling between areas. The fix MUST be scoped to not affect unrelated areas.

**Gate C: 5+ Passes Without Resolution**

```
Pass 1: 2 issues found, 2 fixed
Pass 2: 1 new issue from fix
Pass 3: Previous issue returned
Pass 4: Partial success
Pass 5: Still not clean

GATE TRIGGERED: Architecture problem. Stop making CSS tweaks.
```

Common causes: component doing too much (split it), layout system fighting itself (simplify grid), too many CSS overrides (refactor to design tokens), wrong responsive strategy (redesign mobile-first).

### 8.3 Visual QA to Iteration Engine Mapping

| Visual QA State | Iteration Engine Action |
|----------------|------------------------|
| 1 visual failure | Normal. Fix in current pass. |
| 2 failures in same area | Warning. Check component architecture. |
| 3 consecutive failures (Gate A) | Escalate. Human review. |
| Regression in unrelated area (Gate B) | Halt. Blast radius breach. |
| 5 passes without clean visual (Gate C) | Architecture review required. |

---

## 9. Screenshot Verification

This is the core visual QA protocol. Every UI change runs through this loop. It is the Kaizen verification cycle applied to pixels.

### 9.1 Screenshot Verification Loop

```
1. CAPTURE -----> Take screenshot of current state
2. ANALYZE -----> Examine against baseline / design spec
3. DIAGNOSE ----> symptom -> fix -> result format (-> See ITERATION.md)
4. FIX ---------> Apply the fix (one fix per symptom)
5. RE-CAPTURE --> Take new screenshot (same viewport, same state)
6. VERIFY ------> Compare before/after, check blast radius
7. REPEAT ------> Until pass OR 3-fail gate triggers
```

Max iterations: 5 (architecture problem if exceeded).
Hard stop: 3 consecutive failures on same element.

### 9.2 Visual Analysis Prompt Template

When sending screenshots to AI for analysis, use these 6 criteria:

```
Analyze this screenshot. Check:

1. LAYOUT ALIGNMENT -- Grid alignment, overlap, overflow, margin/padding consistency
2. COLOR CONSISTENCY -- Design system tokens, contrast, correct semantic colors, theme cohesion
3. TEXT READABILITY -- Legibility at rendered size, font weight hierarchy, line height
4. INTERACTIVE ELEMENTS -- Buttons/links identifiable, look clickable, focus states visible
5. SPACING -- Consistent with 4px grid, related elements grouped, whitespace breathing room
6. RESPONSIVE -- Correct at this viewport, touch targets >= 44px, stacking not shrinking

For each issue:
  Symptom: <what is visually wrong>
  Fix: <what CSS/HTML change to make>
  Result: <what the corrected state should look like>

If no issues for a criterion, mark PASS.
Rate overall: PASS / NEEDS WORK / FAIL.
```

### 9.3 Screenshot Naming Convention

```
<feature>-<state>-P<pass>.png

feature: kebab-case page or component name
state:   default, hover, error, loading, empty, mobile, dark
pass:    P01, P02, P03...
```

Examples: `login-error-P01.png`, `dashboard-mobile-P02.png`, `chat-empty-state-P01.png`

### 9.4 Screenshot Storage

```
test-results/
  screenshots/     # Current run (gitignored)
  baselines/       # Approved references (committed to VCS)
  diffs/           # Visual diff outputs (gitignored)
```

### 9.5 Playwright Screenshot Patterns

**Full-Page Screenshots**:

```javascript
await page.screenshot({
  fullPage: true,
  path: `test-results/screenshots/${feature}-${state}-P${pass}.png`,
});
```

**Element Screenshots**:

```javascript
const card = page.locator('.feature-card').first();
await card.screenshot({
  path: `test-results/screenshots/feature-card-hover-P01.png`,
});
```

**Viewport-Specific Screenshots**:

```javascript
// Mobile
await page.setViewportSize({ width: 375, height: 812 });

// Tablet
await page.setViewportSize({ width: 768, height: 1024 });

// Desktop
await page.setViewportSize({ width: 1440, height: 900 });
```

ALWAYS test all three viewports for responsive verification.

**localStorage Clearing Between Tests**:

```javascript
test.beforeEach(async ({ page }) => {
  await page.goto(APP_URL);
  await page.evaluate(() => {
    localStorage.clear();
    sessionStorage.clear();
  });
  await page.reload();
  await page.waitForFunction(() => document.readyState === 'complete');
});
```

NEVER rely on state from a previous test. Each test MUST work in isolation and in any order.

**waitForFunction Over waitForTimeout**:

```javascript
// WRONG -- arbitrary sleep
await page.waitForTimeout(2000);

// RIGHT -- specific condition
await page.waitForFunction(() => window.appReady === true);
```

### 9.6 Visual Regression

**toHaveScreenshot() with Thresholds**:

```javascript
await expect(page).toHaveScreenshot('dashboard-default.png', {
  maxDiffPixels: 100,
  maxDiffPixelRatio: 0.01,
  threshold: 0.2,
});
```

**Threshold by Scenario**:

| Scenario | `maxDiffPixelRatio` | `threshold` | Rationale |
|----------|-------------------|-------------|-----------|
| Static layout | 0.005 (0.5%) | 0.1 | Pixel-perfect |
| Text rendering | 0.01 (1%) | 0.2 | Font anti-aliasing varies |
| Charts/graphs | 0.02 (2%) | 0.3 | Data-driven rendering varies |
| Animation frames | 0.05 (5%) | 0.3 | Timing-dependent captures |

**Baseline Workflow**:

1. Create baselines: `npx playwright test --update-snapshots`
2. ALWAYS review diffs before committing updated baselines
3. NEVER update baselines to "make the test pass" without understanding why the diff exists

**Diff Interpretation**:

| Signal | Interpretation | Action |
|--------|---------------|--------|
| Diff in changed area | Likely intentional | Update baseline |
| Diff outside change area | Likely regression | Investigate |
| Diff in one mode only | Missing mode parity | Fix |
| Diff at one breakpoint only | Responsive regression | Fix |
| Anti-aliasing only (< 0.1%) | Rendering noise | Increase threshold slightly |

### 9.7 Selector Health Check Pre-Flight

Run before every test suite:

```javascript
async function checkSelectorHealth(page, selectors) {
  const report = {};
  for (const [name, selector] of Object.entries(selectors)) {
    try {
      const count = await page.locator(selector).count();
      report[name] = { selector, status: count > 0 ? 'HEALTHY' : 'NOT_FOUND', count };
    } catch (err) {
      report[name] = { selector, status: 'ERROR', error: err.message };
    }
  }
  const unhealthy = Object.entries(report).filter(([, v]) => v.status !== 'HEALTHY');
  if (unhealthy.length > 0) {
    throw new Error(`${unhealthy.length} selectors are broken. Fix before running tests.`);
  }
  return report;
}
```

### 9.8 Persistent Browser Profile for Auth Sessions

When testing against authenticated services:

```javascript
const context = await chromium.launchPersistentContext(
  './test-profiles/authenticated-session',
  {
    headless: false,
    viewport: { width: 1440, height: 900 },
  }
);
```

NEVER commit browser profiles to version control. ALWAYS add profile directories to `.gitignore`.

---

## 10. CI Integration

### 10.1 Headless Config

```javascript
// playwright.config.js
export default defineConfig({
  use: {
    viewport: { width: 1440, height: 900 },
    launchOptions: { args: ['--disable-animations'] },
  },
  ...(process.env.CI && {
    retries: 2,
    workers: 1,
    forbidOnly: true,
  }),
  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.01,
      threshold: 0.2,
      animations: 'disabled',
    },
  },
});
```

### 10.2 Artifacts

```yaml
- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: playwright-results
    path: |
      test-results/screenshots/
      test-results/diffs/
      test-results/analysis/
    retention-days: 30
```

### 10.3 PR Visual Diff Summaries

```yaml
- name: Comment visual diffs on PR
  if: failure() && github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const fs = require('fs');
      const diffDir = 'test-results/diffs';
      if (!fs.existsSync(diffDir)) return;
      const diffs = fs.readdirSync(diffDir).filter(f => f.endsWith('.png'));
      if (diffs.length === 0) return;

      let body = '## Visual Regression Detected\n\n';
      body += `Found ${diffs.length} visual diff(s). `;
      body += 'Download `playwright-results` artifact to review.\n\n';
      body += '**Next steps:**\n';
      body += '1. If intentional: `npx playwright test --update-snapshots`\n';
      body += '2. If regression: fix and re-push\n';

      await github.rest.issues.createComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.issue.number,
        body,
      });
```

### 10.4 Baseline Change Detection

```yaml
- name: Check for baseline changes
  run: |
    CHANGED=$(git diff --name-only HEAD~1 | grep "test-results/baselines/" | wc -l)
    if [ "$CHANGED" -gt 0 ]; then
      echo "::warning::This PR updates $CHANGED visual baselines. Review required."
    fi
```

### 10.5 OS Crash Report Collection

On macOS, collect crash reports from the OS diagnostic reports directory as evidence:

```bash
# Collect the 3 most recent crash reports for the app
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
find "$CRASH_DIR" -name "${APP_NAME}*.crash" -maxdepth 1 | \
  sort -t/ -k$(echo "$CRASH_DIR" | tr -cd '/' | wc -c | xargs -I{} expr {} + 2) -r | \
  head -3 | while read f; do cp "$f" "$EVIDENCE_DIR/"; done
```

ALWAYS check for crash reports after runtime smoke gates. A passing smoke gate with a crash report in DiagnosticReports is a false green.

---

## 11. Consistency Report Template

ALWAYS generate after every significant change. This is the quick-reference summary that feeds into the Trend Log.

```markdown
# Consistency Report -- <date> <time>

## Change
<Brief description>

## Checks

| Check | Status | Tool | Details |
|-------|--------|------|---------|
| Lint | PASS/FAIL | eslint / ruff / clippy | <count> errors, <count> warnings |
| Type Check | PASS/FAIL | tsc / mypy / cargo check | <count> errors |
| Tests | PASS/FAIL | playwright / pytest / cargo test | <passed>/<total>, <duration> |
| Bundle Size | OK/WARNING/ALERT | du / webpack-bundle-analyzer | <size> (<delta>) |
| Screenshots | MATCH/DRIFT/NEW | toHaveScreenshot | <pages checked> |

## Overall: PASS / FAIL
<If FAIL, list blocking issues>
```

### 11.1 Automated Consistency Check Script

```bash
#!/bin/bash
# run-consistency-check.sh
echo "=== Consistency Report ===" && echo "Date: $(date)" && echo ""
FAIL=0

echo "--- Lint ---"
npx eslint src/ --quiet 2>/dev/null && echo "Status: PASS" || { echo "Status: FAIL"; FAIL=1; }

echo "--- Type Check ---"
npx tsc --noEmit 2>/dev/null && echo "Status: PASS" || { echo "Status: FAIL"; FAIL=1; }

echo "--- Tests ---"
npx playwright test --reporter=line 2>&1 && echo "Status: PASS" || { echo "Status: FAIL"; FAIL=1; }

echo "==========================="
[ $FAIL -eq 0 ] && echo "OVERALL: PASS" || { echo "OVERALL: FAIL"; exit 1; }
```

---

## 12. Incongruency Audit Gate

An incongruency is when the system contradicts itself -- a backend feature with no UI surface, a flag with no toggle, two subsystems doing the same thing differently, dev tooling in the production layer. These are not bugs -- they are architectural drift that accumulates silently. This is the Deming principle applied to system congruence: measure the system, not individual events.

### 12.1 MVP Tracker Pattern

Maintain an **Incongruencies** section in the project's MVP Tracker:

```markdown
## Incongruencies, Redundancies, and Contradictions

| # | Issue | Location | Severity | Action |
|---|-------|----------|----------|--------|
| 1 | Feature flag `autoSkip` defaults true but has no UI toggle | DomainTypes, systemsCard | High | Add toggle |
| 2 | Two undo systems with asymmetric UI coverage | Controller, View | High | Unify UX |
| 3 | Dev tooling ships in production layer | ControlView:1253 | Low | Wrap in #if DEBUG |
```

### 12.2 Automated Incongruency Checks

Turn common incongruency patterns into verification warnings (not failures -- some incongruencies are intentional):

```bash
# verify-congruence.sh — Detect common incongruency patterns
set -euo pipefail

WARN=0

# Pattern: Feature flag defined but never referenced in UI code
for flag in $(grep -oE 'var \w+: Bool' Core/Shared/DomainTypes.swift | awk '{print $2}' | tr -d ':'); do
  if ! grep -rq "$flag" App/ 2>/dev/null; then
    echo "WARN: Flag '$flag' defined in DomainTypes but not referenced in App/ — no UI toggle?"
    WARN=$((WARN + 1))
  fi
done

# Pattern: Dev tooling outside #if DEBUG
if grep -rn 'DevPanel\|DebugOverlay\|TestHarness' App/ 2>/dev/null | grep -v '#if DEBUG' | grep -v '//'; then
  echo "WARN: Dev tooling references found outside #if DEBUG blocks"
  WARN=$((WARN + 1))
fi

echo "Incongruency check complete: $WARN warnings"
```

ADVISORY: Run `verify-congruence` during the full verification tier, not fast. Incongruencies are not blockers -- they are signals that the architecture brief needs updating (-> See ARCHITECTURE.md §Architecture Brief Versioning).

---

## 13. UX Audit Log Protocol (Manual QA)

For flows too complex or exploratory for Playwright automation, run a structured manual QA session. This complements automated testing -- it does not replace it.

### 13.1 Entry Format

Every manual test interaction uses this format:

```markdown
### HH:MM -- {Test Name}
**Action**: {what you did}
**Intent**: {what you were trying to verify}
**Result**: PASS | PARTIAL | FAIL -- {observed behavior}
**Observation**: {anything notable, even on PASS}
```

### 13.2 Bug Discovery Format

```markdown
### HH:MM -- BUG #{N}: {Short Description}
**Discovery**: {what went wrong}
**Root Cause**: {why it happened}
**Fix**: {what was changed -- file + description}
**Status**: FIXED | OPEN
```

### 13.3 Session Summary

Every UX audit session ends with a summary table:

```markdown
## Final Test Results

| Test | Status |
|------|--------|
| {test name} | PASS |
| {test name} | PASS (after fix #1) |
| {test name} | FAIL |

**Result: {X}/{Y} functions passing**

## Bugs Found and Fixed

| # | Bug | Root Cause | Fix | Status |
|---|-----|-----------|-----|--------|
| 1 | {bug} | {cause} | {fix} | FIXED |
```

### 13.4 When to Use UX Audit Logs

- After any major UI change that involves interaction flows (not just visual changes)
- Before any release that includes UI features (complement to automated visual QA)
- When exploring a new UI flow for the first time (exploratory QA)
- When automated tests pass but something "feels wrong"

Store as `testing/ux-audit-log-{date}.md`. One file per major QA session. NEVER overwrite -- each session is a separate audit trail.

---

## Related Directives

- -> See PHILOSOPHY.md -- the five-lens foundation: Kaizen drives continuous verification, Unix shapes single-purpose tests, Deming structures the completion loop, AI-Native demands machine-readable evidence, Parallel enables concurrent gate execution
- -> See ITERATION.md -- canonical `symptom -> fix -> result` format, Immutable Identity Blocks (verified in Gate 2), failure gate escalation, PDSA cycle (completion loop IS the Study phase)
- -> See DESIGN.md -- full Design Gate criteria (section 5), color tokens verified in Layer 2 visual tests, Max 3 rule audited via screenshot, Identity Block system (section 2)
- -> See ARCHITECTURE.md -- MAP manifests consumed by health matrix, Module Gate enforces Unix decomposition, ADR triggers rollback drills
- -> See GENESIS.md -- Council Session #1 defines G5-G7 domain gates and core flows
- -> See TEAM.md -- three-tier model determines who runs the completion loop (BUILD runs gates; THINK reviews escalations)
- -> See OPERATIONS.md -- Trend Log receives completion loop summaries; multi-phase verify pipeline orchestrates gates

---

## Framework Navigation

> **You Are Here:** `QUALITY.md` — Verification gates G0-G9, completion loop, testing, rollback drills
> **Core Method:** Kaizen · Deming · Unix · AI-Native · Parallel → PHILOSOPHY.md

| File | When To Read |
|------|-------------|
| CLAUDE.md | Session start, operating mode routing, unbreakable rules |
| PHILOSOPHY.md | Principle check, five-lens test, enforcement rules |
| GENESIS.md | New project kickoff, requirements interview, probe/bootstrap |
| TEAM.md | AI model selection, Council decisions, persona profiles |
| ARCHITECTURE.md | Module design, dependency management, MAP manifests |
| ITERATION.md | Pass loop, swim lanes, circle detection, session handoff |
| QUALITY.md | ★ You are here |
| DESIGN.md | Visual identity, design gates, component system |
| HANDHOLDING.md | Newcomer guidance, glossary, preemptive help |
| OPERATIONS.md | Dev environment, dashboard, MVP tracker, reporting |
| CHARACTER-TRACKING.md | Team performance, calibration, persona metrics |

> **If lost:** Start at CLAUDE.md. If a concept is unclear, check HANDHOLDING.md §9 Glossary.
> **If stuck:** ITERATION.md §7 Failure Gates (1-fail retry, 2-fail pivot, 3-fail Council).
> **If quality uncertain:** QUALITY.md §1 Gate Runner. If design: DESIGN.md §5 Design Gates.
