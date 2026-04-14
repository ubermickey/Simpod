# OPERATIONS.md -- Simpod Dev Environment, Monitoring, Lifecycle, and Continuous Improvement

> **Project:** Simpod — reliable, fast podcast player
> **Stack:** TBD (determined during GENESIS interview)
> **Repo:** https://github.com/ubermickey/Simpod

> **Kaizen** -- Maintenance cadence drives continuous improvement: daily/weekly/monthly/quarterly.
> **Unix** -- Every script does one thing: launcher launches, health checks check, migration migrates.
> **Deming** -- Measure the process, not just the product; fix the system, not the symptom.
> **AI-Native** -- Lock operational invariants explicitly; dashboards make invisible state visible to AI and human alike.
> **Parallel** -- Independent monitors run concurrently; never serialize health checks that share no data.
> NEVER build a 500-line shell script that "handles everything." ALWAYS compose small, sharp tools with `&&`.

---

## 1. Launch Scripts

### `.command` Files for macOS

ALWAYS structure `.command` files with these rules:
- `cd "$(dirname "$0")"` first -- NEVER assume the user's working directory.
- `set -euo pipefail` -- fail fast, fail loud.
- Keep the terminal open on error so output is readable.
- Explicitly activate venvs, set PATH, export vars -- NEVER assume shell state.

```bash
#!/bin/bash
# launch.command -- One-click project launcher
set -euo pipefail
cd "$(dirname "$0")"

# -- Step 1: Environment --
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
fi
source .venv/bin/activate

# -- Step 2: Dependencies --
if [ -f "requirements.txt" ]; then
    pip install -q -r requirements.txt
fi

# -- Step 3: Database --
python -c "from server import init_db; init_db()" 2>/dev/null || true

# -- Step 4: Server --
echo "Starting server on http://localhost:3001"
python server.py &
SERVER_PID=$!

# -- Step 5: Browser --
sleep 2
open "http://localhost:3001"

# -- Step 6: Cleanup on exit --
trap "kill $SERVER_PID 2>/dev/null" EXIT
wait $SERVER_PID
```

ALWAYS make it executable: `chmod +x launch.command`

### `osascript` Multi-Terminal Launcher

WHEN a project needs multiple processes (backend + frontend + worker), THEN use `osascript` to open separate Terminal tabs. One process per tab.

```bash
#!/bin/bash
# launch-full.command -- Multi-terminal launcher
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

osascript <<EOF
tell application "Terminal"
    activate
    do script "cd '$PROJECT_DIR' && source .venv/bin/activate && python server.py"
    tell application "System Events" to keystroke "t" using command down
    delay 0.5
    do script "cd '$PROJECT_DIR/web' && pnpm dev" in front window
    tell application "System Events" to keystroke "t" using command down
    delay 0.5
    do script "sleep 3 && open http://localhost:3001" in front window
end tell
EOF
```

---

## 2. Environment Variables

### `.env.example` + `.env` Pattern

ALWAYS commit `.env.example`. NEVER commit `.env`.

```bash
# .env.example -- Copy to .env and fill in real values.

# -- Required (app will not start without these) --
DATABASE_URL=sqlite:///data.db
SECRET_KEY=change-me-in-production

# -- Optional (defaults shown) --
PORT=3001
DEBUG=false
LOG_LEVEL=info

# -- External Services (uncomment when enabling) --
# OPENAI_API_KEY=sk-...
# SMTP_HOST=smtp.example.com
```

ALWAYS add to `.gitignore`:

```gitignore
.env
.env.local
.env.production
.env.*.local
```

### pydantic-settings (Python)

```python
# config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str                    # Required -- crashes if missing
    secret_key: str                      # Required -- crashes if missing
    port: int = 3001                     # Optional -- sensible default
    debug: bool = False
    openai_api_key: str | None = None    # Feature-gated

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
    }

settings = Settings()
```

### dotenv (Node.js)

```javascript
// config.js
import 'dotenv/config';

export const config = {
  databaseUrl: requireEnv('DATABASE_URL'),
  secretKey: requireEnv('SECRET_KEY'),
  port: parseInt(process.env.PORT || '3001', 10),
  debug: process.env.DEBUG === 'true',
};

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`FATAL: Missing required environment variable: ${name}`);
    console.error(`Copy .env.example to .env and fill in the values.`);
    process.exit(1);
  }
  return value;
}
```

### Environment Variable Rules

1. Every variable in code MUST appear in `.env.example` with a comment.
2. Required vs. optional MUST be explicit via section headers.
3. Defaults MUST be documented.
4. Secrets MUST get placeholder values (`change-me-in-production`).
5. Feature-gated variables MUST be commented out by default.

---

## 3. Database Patterns

### SQLite (Default)

ALWAYS use WAL mode and foreign keys. NEVER skip pragmas on connection.

> See ARCHITECTURE.md for full data modeling guidelines.

```python
import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).parent / "data.db"

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn
```

### Self-Healing Schema

> See ARCHITECTURE.md for the canonical pattern (CREATE IF NOT EXISTS + ALTER TABLE + safe_add_column).

ALWAYS call `ensure_schema()` on startup. All operations MUST be idempotent.

### Audit Trails

Every table that stores user-visible data MUST have `created_at` and `updated_at`. This is non-negotiable.

```sql
CREATE TABLE IF NOT EXISTS {table_name} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    {column_definitions},
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER IF NOT EXISTS {table_name}_updated_at
    AFTER UPDATE ON {table_name}
    FOR EACH ROW
BEGIN
    UPDATE {table_name} SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
END;
```

### Backup Script

```bash
#!/bin/bash
# backup-db.sh -- Back up SQLite database. Keep last 10.
set -euo pipefail

DB_PATH="${1:?Usage: backup-db.sh <path-to-db>}"
BACKUP_DIR="$(dirname "$DB_PATH")/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$(basename "$DB_PATH" .db)-$TIMESTAMP.db"

mkdir -p "$BACKUP_DIR"
sqlite3 "$DB_PATH" ".backup '$BACKUP_PATH'"
echo "Backed up to: $BACKUP_PATH"

# Keep only last 10 backups
ls -t "$BACKUP_DIR"/*.db 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
```

### When to Upgrade to PostgreSQL

| Signal | SQLite | PostgreSQL |
|--------|--------|------------|
| Users | Single / local | Multiple concurrent |
| Data size | < 1 GB | > 1 GB or growing fast |
| Write concurrency | < 10 writes/sec | > 10 writes/sec |
| Full-text search | Basic (FTS5) | Advanced (tsvector, pg_trgm) |
| JSON queries | Limited | Excellent (JSONB) |
| Deployment | Local / single server | Multi-server / cloud |
| Backup needs | File copy | Point-in-time recovery |

**Default**: Start with SQLite. Migrate to PostgreSQL WHEN you hit a concrete limitation, not a hypothetical one.

---

## 4. Git Workflow

### Branch Naming

```
feature/<name>      New functionality
fix/<name>          Bug fix
refactor/<name>     Code restructuring (no behavior change)
experiment/<name>   Speculative work (may be discarded)
docs/<name>         Documentation only
ops/<name>          Infrastructure / operational changes
```

ALWAYS use lowercase, kebab-case. NEVER put issue numbers in branch names. Keep names short but descriptive. `experiment/` branches MAY be deleted without merging.

### Commit Convention

Imperative mood. 50-char subject. Body explains **why**, not **what**.

```
<type>: <what changed in imperative mood>

<why this change was needed -- 1-2 sentences>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

**Types**: `feat`, `fix`, `refactor`, `test`, `docs`, `ops`, `style`, `perf`

### PDSA Cycle Tags in Commits

WHEN work is part of a PDSA cycle, THEN tag the commit with the cycle ID and phase:

```
<type>(<scope>): [PDSA-<NN>/<PHASE>] <what changed>
```

Phases: `PLAN`, `DO`, `STUDY`, `ACT-standardize`, `ACT-revise`, `ACT-flag`, `ACT-rollback`

**Example:**

```
feat(podbot): [PDSA-03/DO] add JIT playback preemption

Implements the smallest safe version of preemptive trim scheduling.
Instrumented with callback headroom metrics for Study phase.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

```
fix(podbot): [PDSA-03/STUDY] playback underrun on bluetooth route change

Expected: zero underruns in 30-min synthetic run.
Observed: 2 underruns on bluetooth route transitions.
Root cause: route change handler pauses too late.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

```
feat(podbot): [PDSA-03/ACT-standardize] ship JIT preemption

Study confirmed zero underruns after fix. Standardizing.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

This makes `git log --grep="PDSA-03"` return the full cycle narrative. ADVISORY -- use when PDSA cycles span multiple commits. SKIP for single-commit fixes.

**Standard (non-PDSA) Example:**

```
feat: add health endpoint with version and uptime

The server had no way to report its status to monitoring tools.
This endpoint returns structured health data for the watchdog script.

Co-Authored-By: Claude Opus 4 <noreply@anthropic.com>
```

### PR Template

```markdown
## Summary
<!-- 1-3 bullet points -->

## Test Plan
- [ ] All existing tests pass
- [ ] New tests added for: ...
- [ ] Visual verification: screenshot attached

## Screenshots
<!-- Before/after for UI changes -->

## Notes
<!-- Anything reviewers should know -->
```

### Squash vs. Merge Decision Matrix

| Situation | Strategy | Rationale |
|-----------|----------|-----------|
| Feature branch with messy WIP commits | **Squash** | Clean history, one commit per feature |
| Feature branch with clean, logical commits | **Merge commit** | Preserve development narrative |
| Hotfix (1-2 commits) | **Merge commit** | Every commit is meaningful |
| Experiment branch | **Squash** | Collapse exploration into one summary |
| Revert | **Merge commit** | Preserve the revert's context |

**Default**: Squash merge.

---

## 5. Mission Control Dashboard

Update at session start, during major transitions, and at session end.

> See ITERATION.md for the pass loop that drives work tracked here.
> See TEAM.md for escalation protocol and Council sessions logged here.

### Dashboard Layout

```
+-----------------------------------------------------------------+
|  MISSION CONTROL -- <Project Name>          <date> <time>        |
+-------------------+-----------------+-----------------+-----------+
| ACTIVE THREADS    | COUNCIL LOG     | BLOCKERS        | HEALTH    |
|                   |                 |                 |           |
| Thread A: ...     | Decision #3:    | [!] API auth    | Server: * |
| Thread B: ...     |   Resolved      |     blocked     | Tests:  * |
| Thread C: ...     | Decision #4:    |                 | Build:  * |
|   (idle)          |   In session    |                 | Lint:   * |
+-------------------+-----------------+-----------------+-----------+
| TODO TRACKER                                                      |
| [x] Set up project scaffold        (Haiku, 2m)                   |
| [>] Implement API routes           (Sonnet, in progress)         |
| [ ] Write Playwright tests         (Sonnet, blocked by API)      |
+-------------------------------------------------------------------+
| TEAM ACTIVITY LOG                                                  |
| 14:32 -- Sonnet: completed /api/markets endpoint                  |
| 14:15 -- Council: convened for auth strategy (Decision #4)        |
| 14:10 -- Haiku: ran 47 tests, all passing                         |
+-------------------------------------------------------------------+
```

### Dashboard Symbols

| Symbol | Meaning |
|--------|---------|
| `*` (filled) | Healthy / green / passing |
| `o` (open) | Degraded / yellow / warning |
| `x` | Broken / red / failing |
| `[x]` | TODO completed |
| `[>]` | TODO in progress |
| `[ ]` | TODO pending |
| `[!]` | Blocker / requires attention |

### Thread Tracker

Each concurrent agent instance is a "thread." The tracker answers: who is doing what, right now?

#### Thread Record Format

```
THREAD TRACKER
================================================================
Thread ID:    T-003
Team Member:  Sonnet (Senior Engineer)
Task:         Implement POST /api/markets endpoint
Status:       ACTIVE
Parent:       T-001 (Opus: project planning)
Children:     T-004 (Haiku: write unit tests for /api/markets)
Started:      14:10
Est. Time:    20m
Actual Time:  22m (in progress)
Dependencies: Needs T-002 (database schema) -- RESOLVED
Blockers:     None
Files:        backend/api/routes.py, backend/models/market.py
================================================================
```

#### Thread States

| State | Meaning | Action |
|-------|---------|--------|
| `ACTIVE` | Agent working now | Let it run |
| `IDLE` | Waiting for input | Assign next task or close |
| `BLOCKED` | Waiting on dependency | Resolve the blocker |
| `COMPLETE` | Task finished | Review output, close thread |
| `FAILED` | Hit 3-fail gate | Escalate; see TEAM.md Escalation Protocol |

#### Parent-Child Thread Map

```
T-001 (Opus: Project Planning) <- root
  +-- T-002 (Opus: Database Schema) <- COMPLETE
  +-- T-003 (Sonnet: API Implementation) <- ACTIVE
  |     +-- T-004 (Haiku: Unit Tests) <- BLOCKED (waiting for T-003)
  |     +-- T-005 (Haiku: API Docs) <- IDLE
  +-- T-006 (Playwright: Visual QA) <- ACTIVE
```

#### Cross-Thread Dependencies

Both thread records MUST note dependencies. NEVER allow silent deadlocks.

```
DEPENDENCY MAP
================================================================
T-004 (tests) --depends-on--> T-003 (API routes)    Status: WAITING
T-003 (API routes) --depends-on--> T-002 (schema)   Status: RESOLVED
================================================================
```

#### Estimated vs. Actual Time

Track for every thread. The ratio reveals which tasks the team consistently underestimates. Kaizen applied to planning.

| Thread | Task | Est. | Actual | Ratio |
|--------|------|------|--------|-------|
| T-002 | DB schema | 15m | 12m | 0.8x |
| T-003 | API routes | 20m | 35m | 1.75x |

### TODO System

Every unit of work is a TODO. TODOs are atomic -- one owner, one definition of done.

#### TODO Record Format

```
TODO-017
=========================================
Description:  Add rate limiting to POST /api/markets
Assigned To:  Sonnet (Senior Engineer)
Priority:     P1
Status:       PENDING
Blockers:     Needs TODO-014 completed first
Thread:       T-003
=========================================
```

#### Priority Levels

| Priority | Label | Meaning | SLA |
|----------|-------|---------|-----|
| **P0** | Critical path | Blocks other work | Resolve immediately |
| **P1** | Important | Significant value, not blocking | Resolve this session |
| **P2** | Nice-to-have | Improves quality/DX | Resolve when convenient |

#### Dependency Chains

```
TODO-014 (API routes)     <- P0, IN PROGRESS
  +-> TODO-015 (API tests)     <- P0, BLOCKED by TODO-014
  +-> TODO-017 (rate limiting) <- P1, BLOCKED by TODO-014
```

#### Status Transitions

```
PENDING --> IN PROGRESS --> COMPLETE
   |              |
   |              +---> BLOCKED --> (resolved) --> PENDING
   +---> BLOCKED --> (resolved) --> PENDING
```

### Council Session Log

Every AI Council session produces a logged record.

> See TEAM.md for the full Council Protocol and convergence mechanisms.

#### Session Record Format

```
COUNCIL SESSION #4
================================================================
Convened:     14:15 by Opus (Thread T-001)
Question:     "How should we handle user authentication?"
Options:      A) JWT with refresh tokens
              B) Session-based with httpOnly cookies
Mechanism:    Nash Bargaining
Decision:     OPTION A -- JWT with refresh tokens
Dissent:      Critic preferred session-based (noted)
Duration:     7 minutes
================================================================
```

#### Session Log Table

| # | Question | Mechanism | Decision | Duration |
|---|----------|-----------|----------|----------|
| 1 | Tech stack selection | Borda Count | -- | -- |
| 4 | Authentication strategy | Nash Bargaining | JWT + refresh | 7m |

### Escalation Tracker

Escalation is the system working correctly. Track every escalation so patterns emerge.

#### Escalation Record Format

```
ESCALATION #3
================================================================
From:         Sonnet (Thread T-003)
To:           Opus (Thread T-001)
Reason:       Hit 3-fail gate on JWT middleware integration
Category:     TECHNICAL
Resolution:   Opus restructured dependency graph (7 minutes)
================================================================
```

#### Escalation Paths

```
Haiku --> Sonnet --> Opus --> Human
                      +--> AI Council
```

#### Escalation Categories

| Category | Meaning | Typical Resolution |
|----------|---------|-------------------|
| TECHNICAL | Beyond agent's capability | Escalate to stronger model |
| ARCHITECTURAL | Design decision needed | Escalate to Opus or Council |
| BLOCKED | External dependency | Escalate to Human |
| POLICY | Business/taste decision | Escalate to Human |
| 3-FAIL GATE | Same element failed 3x | Escalate to Opus; see ITERATION.md Failure Gates |

#### Escalation Pattern Analysis

Review weekly. Patterns signal systemic issues.

| Pattern | Signal | Action |
|---------|--------|--------|
| Same agent escalates same type repeatedly | Model mismatch | Reassign task type |
| Escalations cluster around one subsystem | Architectural issue | Council session |
| Escalation rate increasing | Growing complexity debt | Schedule refactoring |
| Escalation rate decreasing | Team improving | Document and continue |

### War Room

Communal log. Every action, decision, test result, blocker flows here as timestamped messages.

#### Channels

| Channel | Purpose | Who Posts |
|---------|---------|-----------|
| `#general` | Coordination, status | Everyone |
| `#implementation` | Code changes, completions | Sonnet, Haiku, Opus |
| `#council` | Sessions, decisions | Council, Opus |
| `#testing` | Test runs, results | Haiku, Playwright, Sonnet |
| `#blockers` | Blocked threads, escalations | Anyone stuck |
| `#reviews` | Code/architecture reviews | Opus, Critic seat |

#### Message Format

```
[<timestamp>] @<TeamMember> (<Thread-ID>): <action summary>
              <optional details -- files, test counts>
              <optional link to TODO, Decision, or Escalation>
```

#### Auto-Posting Rules

| Event | Auto-Post To | Message |
|-------|-------------|---------|
| TODO completed | `#general`, `#implementation` | `TODO-XXX: COMPLETE` with duration |
| Test suite run | `#testing` | Pass/fail count, coverage delta |
| Council convened | `#council` | Session start with question |
| Council decided | `#council`, `#general` | Decision summary |
| Escalation raised | `#blockers` | Who, why, to whom |
| Escalation resolved | `#blockers` | Resolution summary |
| Screenshot loop pass | `#testing` | Pass number, viewport, status |
| Health check fails | `#blockers`, `#general` | Which monitor, what failed |
| Session start | `#general` | Plan summary |
| Session end | `#general` | Progress summary |

### Health Monitors

Each monitor tests ONE thing and returns ONE status. Monitors report -- they NEVER fix.

#### Monitor Definitions

| Monitor | What It Checks | Frequency |
|---------|---------------|-----------|
| **Server** | Dev server responding? | Every 5 minutes |
| **Tests** | Full test suite passing? | After every code change |
| **Build** | Project builds without errors? | After every code change |
| **Lint** | Code style clean? | After every code change |
| **Screenshots** | UI matches baseline? | After every UI change |
| **Dependencies** | All deps installed/compatible? | Start of session |
| **Hooks** | Pre-commit and session hooks passing? | After every hook config change |
| **Model availability** | Primary models responding? | Start of session |
| **Completion Loop** | Last verify cycle: PASS/FAIL? | After any verify run |
| **Runtime Artifacts** | Any crash files in Reports/? | After every runtime launch |

#### Status Format

```
HEALTH MONITORS -- <date> <time>
=============================================
* Server          UP      (response: 12ms)
* Tests           PASS    (47/47)
o Lint            WARN    (2 warnings, 0 errors)
* Screenshots     PASS    (3/3 viewports)
* Dependencies    OK      (no conflicts)
* Completion Loop PASS    (cycle 3 of 3)
* Runtime Artifacts OK    (0 crash files)
=============================================
```

#### Runtime Artifact Panel

Include in the Mission Control dashboard when running native or build-heavy projects:

```
+---------------------------------------------+
| RUNTIME ARTIFACTS                            |
| Last audit: runtime-audit-{ts}/   *          |
| Last errors: runtime-errors-{ts}/ 0 faults   |
| Benchmarks:  benchmark-{ts}.json  * stable    |
+---------------------------------------------+
```

| Field | Red Signal | Action |
|-------|-----------|--------|
| Last audit | > 24h since last successful audit | Run verify-full immediately |
| Last errors | > 0 faults in last session | Open complaints, investigate before next commit |
| Benchmarks | "degraded" instead of "stable" | Run benchmark harness, compare to baseline |

#### When a Monitor Goes Red

1. Auto-post to `#blockers` in War Room
2. Create a P0 TODO for the fix
3. Notify Opus (or current Project Lead)
4. Block downstream work that depends on broken component

#### Monitor Shell One-Liners

```bash
# Server health
curl -sf http://localhost:3001/api/health && echo "* Server UP" || echo "x Server DOWN"

# Test suite
npx playwright test --reporter=line && echo "* Tests PASS" || echo "x Tests FAIL"

# Build
npm run build 2>&1 && echo "* Build PASS" || echo "x Build FAIL"

# Lint
npm run lint 2>&1 | tail -1

# Dependencies
npm ls --all 2>&1 | grep -c "ERR!" | xargs -I{} test {} -eq 0 \
  && echo "* Deps OK" || echo "x Deps CONFLICT"
```

### Daily Standup Template

```
## Standup -- <date>

### Yesterday
- [completed tasks with TODO IDs and durations]
- [council decisions made]

### Today
- [planned tasks with TODO IDs, assigned team members, estimates]

### Blockers
- [what is stuck, who owns it, what unblocks it]
- "None" if nothing blocked (NEVER leave empty)

### Health Status
* Server   * Tests   * Build   * Lint   * Screenshots   * Deps

### Kaizen Reflection
- What improved today: [specific improvement, measured if possible]
- What to improve tomorrow: [specific target]
- Pattern noticed: [any recurring issue or efficiency gain]
```

The Kaizen Reflection section is NOT optional. Without it, the standup is status reporting. With it, the standup drives improvement.

### Session Protocol

#### Session Start (5 min)

1. Read last standup. Review health monitors.
2. Scan War Room for unresolved blockers.
3. Review TODO list -- identify P0 items.
4. Update dashboard header with today's date/time.
5. Post to `#general`: `@Opus: SESSION START. [plan summary]`

#### During Work (continuous)

1. Agents post to War Room channels as they complete actions.
2. TODOs update as work progresses.
3. Thread Tracker updates as threads spawn, block, or finish.
4. Health monitors run after every code change.
5. Escalations are logged the moment they happen, not after resolution.

#### Blocker Handling

1. Post to `#blockers` immediately.
2. Create P0 TODO if none exists.
3. Update BLOCKERS column on dashboard.
4. If decision needed, convene Council and log session.
5. When resolved, post resolution and clear dashboard.

#### Session End (5 min)

1. Generate standup using template above.
2. Run all health monitors, record status.
3. Archive War Room if getting long (move to `war-room-archive/`).
4. Post to `#general`: `@Opus: SESSION END. [progress summary]`
5. Commit updated Mission Control file.

#### Weekly Review (15 min)

1. Review all Kaizen Reflections from the week.
2. Identify recurring patterns -- same blockers, same escalation types, same estimation errors.
3. Update framework documents when reflections reveal process gaps.
4. Review escalation patterns -- is the team improving?
5. Adjust estimates using actual-vs-estimated data from Thread Tracker.

### Strategic/Tactical Tracker

Track portfolio-level goals and current session focus. Update at session start and when switching thinking modes.

> See GENESIS.md for the Strategic and Tactical Thinking Framework.

```
+------------------------------------------------------------------+
| STRATEGIC / TACTICAL TRACKER                                      |
+------------------------------------------------------------------+
| STRATEGIC GOALS (portfolio-level)                                 |
|   1. {goal} -- {metric}: {current}/{target} -- {status}          |
|   2. {goal} -- {metric}: {current}/{target} -- {status}          |
|   3. {goal} -- {metric}: {current}/{target} -- {status}          |
|                                                                   |
| TACTICAL FOCUS (current session)                                  |
|   Project:    {name}                                              |
|   Objective:  {one sentence -- current pass target}               |
|   Mode:       STRATEGIC / TACTICAL                                |
|   Thinking:   {brief note on current reasoning}                   |
|                                                                   |
| DECISION VELOCITY                                                 |
|   Avg time to Council decision: {minutes}                         |
|   Avg passes per feature:       {count}                           |
|   Circle detection->resolution:  {sessions}                       |
+------------------------------------------------------------------+
```

#### Goal Status Symbols

| Symbol | Meaning |
|--------|---------|
| `*` (filled) | On track -- metric trending toward target |
| `o` (open) | At risk -- metric stalled or trending away |
| `x` | Off track -- metric moving in wrong direction |
| `[done]` | Achieved -- target met |

### Circle Log

Track detected circles across the project lifecycle. Every circle is logged the moment it is detected.

> See ITERATION.md for circle checks in the pass loop.
> See HANDHOLDING.md for preemptive circle detection and plain-English definitions.

```
+------------------------------------------------------------------+
| CIRCLE LOG -- {Project Name}                                      |
+------------------------------------------------------------------+
| ACTIVE CIRCLES                                                    |
|   [!] CIRCLE-001 Type 1: Re-discussed auth strategy              |
|       (decided in ADR-003) -- 2 occurrences                      |
|   [!] CIRCLE-003 Type 3: Dashboard scope expanded->cut->expand   |
|       -- 3 occurrences <- ESCALATE                                |
|                                                                   |
| RESOLVED CIRCLES                                                  |
|   [x] CIRCLE-002 Type 2: API timeout fix repeated 3x             |
|       Resolution: Root cause was connection pooling, not          |
|       error handling. Fixed in P07.                               |
|                                                                   |
| CIRCLE SUMMARY                                                    |
|   Total: 3 | Active: 2 | Resolved: 1 | Escalated: 1             |
|   Type 1 (revisited decisions): 1                                 |
|   Type 2 (repeated failures):   1                                 |
|   Type 3 (scope creep):         1                                 |
+------------------------------------------------------------------+
```

#### Circle Escalation Indicators

| Indicator | Meaning | Action |
|-----------|---------|--------|
| `[!]` | Active circle, not yet escalated | Monitor; resolve if possible |
| `[!!]` | 3+ occurrences -- ESCALATED | Mandatory resolution per ITERATION.md |
| `[x]` | Resolved | Document resolution for pattern library |

### Active Project Registry

Portfolio view of all projects the platform has worked on. Update when projects change status.

> See S8 (Portfolio Dashboard) for the cross-project portfolio view.
> See S8 (Project Lifecycle) for full lifecycle management protocol.

```
+------------------------------------------------------------------+
| PROJECT REGISTRY                                                  |
+------------------------------------------------------------------+
| {project_1}: ACTIVE                                               |
|   Phase: iteration -- Pass: P12                                   |
|   Goals: 2 active -- Circles: 1 open                             |
|   Last touched: {date}                                            |
|   Health: * Tests  * Build  * Lint                                |
|                                                                   |
| {project_2}: ACTIVE                                               |
|   Phase: testing -- Pass: P08                                     |
|   Goals: 1 active (metric nearly met)                             |
|   Last touched: {date}                                            |
|   Looks done? -> YES -- ask user                                  |
|                                                                   |
| {project_3}: DONE                                                 |
|   Retrospective: complete                                         |
|   Framework patches: 2 (v6.0.1, v6.1.0)                          |
|   Duration: {start} -> {end}                                      |
|                                                                   |
| {project_4}: PAUSED                                               |
|   Phase: iteration -- Last touched: {date}                        |
|   Stalled: > 7 days -- ask user to resume or abandon              |
|                                                                   |
| PORTFOLIO SUMMARY                                                 |
|   Active: 2 | Paused: 1 | Done: 1                                |
|   Framework version: v6.1.0                                       |
|   Patterns in library: {count}                                    |
|   Next quarterly review: {date}                                   |
+------------------------------------------------------------------+
```

#### Project Status Symbols

| Status | Symbol | Dashboard Color |
|--------|--------|----------------|
| INTERVIEW | `<>` | Purple (discovery) |
| BOOTSTRAPPING | `<*>` | Blue (structure) |
| ACTIVE | `*` | Green (healthy) |
| PAUSED | `o` | Yellow (warning) |
| DONE | `[done]` | Teal (complete) |
| ABANDONED | `x` | Red (stopped) |

---

## 6. MVP Tracker

Track pillar-based MVP progress across the project. ALWAYS update at: every session end, every gate pass, every pillar completion.

> See ITERATION.md for the pass loop that drives pillar progress.
> See GENESIS.md for how pillars are defined during project bootstrap.

### MVP Summary Table

```
MVP TRACKER -- {Project Name}
================================================================
| Pillar            | Backend  | UI       | Overall     |
|-------------------|----------|----------|-------------|
| {Pillar 1}        | Done     | Done     | Done        |
| {Pillar 2}        | Done     | WIP      | Gap         |
| {Pillar 3}        | WIP      | --       | WIP         |
| {Pillar 4}        | --       | --       | WIP         |
================================================================
Overall MVP: {percentage}%
================================================================
```

### Pillar Status Values

| Status | Meaning |
|--------|---------|
| `Done` | Feature complete and verified |
| `WIP` | Work in progress this session |
| `Gap` | Backend or UI complete but the other is missing |
| `--` | Not started |
| `Blocked` | Waiting on dependency or decision |

### Feature Status Matrix

For each pillar, maintain a detailed feature matrix:

```
PILLAR: {Pillar Name}
================================================================
| Feature           | Backend         | UI              | Status  | Notes           |
|-------------------|-----------------|-----------------|---------|-----------------|
| {Feature 1}       | /api/endpoint   | /page/component | Done    |                 |
| {Feature 2}       | /api/other      | --              | Gap     | UI not started  |
| {Feature 3}       | models/foo.py   | FooView.tsx     | WIP     | In pass P07     |
================================================================
```

Columns:
- **Feature**: Name of the specific capability within the pillar
- **Backend**: File path or endpoint where the backend logic lives
- **UI Location**: File path or route where the UI rendering lives
- **Status**: Done / WIP / Gap / Blocked / Not Started
- **Notes**: Current context -- pass number, blocker details, decisions pending

### MVP Percentage Calculation

```
MVP% = (pillars with Overall=Done / total pillars) * 100

WHEN MVP% >= 80%, THEN consider declaring project done (see S8 Done Declaration).
WHEN MVP% has not increased for 2+ sessions, THEN investigate -- either scope is wrong or work is circling.
```

### Update Triggers

ALWAYS update the MVP Tracker when:
- A session ends (mandatory -- no exceptions)
- A verification gate passes for a pillar feature
- A pillar moves from WIP to Done
- A new blocker is discovered that affects a pillar

NEVER let the MVP Tracker go stale for more than one session. Stale trackers hide drift.

---

## 7. AI Cost Tracking

Track AI model costs per session. The cost log is appended to the Trend Log (see ITERATION.md) after every session.

> See TEAM.md for model selection and tier definitions.
> See PHILOSOPHY.md for the Kaizen principle: measure before and after every change.

### Tier Definitions

| Tier | Purpose | Models | Expected Share |
|------|---------|--------|----------------|
| TALK | Conversation, clarification, handholding | Haiku, Flash | 25% of token volume |
| BUILD | Implementation, code generation, testing | Sonnet, Gemini 2.5 Pro | 60% of token volume |
| THINK | Architecture, planning, complex reasoning | Opus, o3 | 15% of token volume |
| COUNCIL | Multi-model decision sessions | Mixed (see TEAM.md) | Ad hoc -- not in regular distribution |

### Session Cost Log Format

Append this block to the Trend Log after every session:

```
COST LOG -- Session {date}
================================================================
| Tier    | Model            | Invocations | Input Tokens | Output Tokens | Est. Cost |
|---------|------------------|-------------|--------------|---------------|-----------|
| TALK    | claude-haiku     | 12          | 15,000       | 8,000         | $0.02     |
| BUILD   | claude-sonnet    | 8           | 120,000      | 45,000        | $1.80     |
| THINK   | claude-opus      | 2           | 40,000       | 12,000        | $2.10     |
| COUNCIL | mixed            | 1 session   | 25,000       | 15,000        | $3.50     |
================================================================
Session Total: $7.42
Cumulative Project Total: ${running_total}
================================================================
```

### Cost Distribution Analysis

ALWAYS calculate tier distribution at session end:

```
TIER DISTRIBUTION -- Session {date}
================================================================
TALK:    {X}% of tokens   (target: 25%)
BUILD:   {X}% of tokens   (target: 60%)
THINK:   {X}% of tokens   (target: 15%)
================================================================
```

### Kaizen Thresholds and Alerts

WHEN session cost exceeds 2x the average of the previous 3 sessions, THEN alert:
```
[COST ALERT] Session cost ${current} is {ratio}x the 3-session average (${average}).
Investigate: Which tier drove the increase? Was the work proportionally larger?
```

WHEN THINK tier exceeds 50% of total token volume, THEN investigate:
```
[TIER IMBALANCE] THINK tier consumed {X}% of tokens (target: 15%).
Question: Should BUILD tier be doing more of this work?
Action: Review task assignments -- are complex tasks being routed to THINK when BUILD could handle them?
```

WHEN BUILD tier drops below 40% of total token volume, THEN flag:
```
[LOW BUILD] BUILD tier at {X}% (target: 60%).
Signal: Either the session was planning-heavy (acceptable) or BUILD tasks are being over-escalated to THINK.
```

### Cost Trend Tracking

Track cost per pass across the project lifecycle:

```
COST TREND
================================================================
| Session | Passes | Cost    | Cost/Pass | Tier Distribution        |
|---------|--------|---------|-----------|--------------------------|
| Day 1   | P01-03 | $12.50  | $4.17     | T:20% B:65% K:15%       |
| Day 2   | P04-06 | $8.30   | $2.77     | T:25% B:60% K:15%       |
| Day 3   | P07-08 | $15.80  | $7.90     | T:15% B:45% K:40% [!]   |
================================================================
```

WHEN cost/pass trends upward for 3+ consecutive sessions, THEN investigate root cause:
- Are passes getting more complex? (acceptable -- later passes often are)
- Are circles causing rework? (fix the circle, not the cost)
- Is the wrong tier handling the work? (reassign per TEAM.md model selection)

---

## 8. Project Lifecycle

### Project Registry

The registry tracks all projects the platform has worked on. It is the portfolio view.

```
PROJECT REGISTRY

Format:
  {project_name}:
    Status: INTERVIEW | BOOTSTRAPPING | ACTIVE | PAUSED | DONE | ABANDONED
    Phase: {current GENESIS/ITERATION/TESTING/RETROSPECTIVE phase}
    Goals: {1-3 active goals with metrics}
    Last Touched: {date}
    Requirements Brief: {path or "pending"}
    Circle Count: {total circles logged}
    Framework Patches: {count of v6 improvements from this project}
    Looks Done?: YES | NO | UNCLEAR
```

### Status Definitions

| Status | Meaning | Entry Condition | Exit Condition |
|--------|---------|-----------------|----------------|
| INTERVIEW | Requirements being gathered | New project started | Requirements Brief complete |
| BOOTSTRAPPING | GENESIS.md in progress | Brief complete | Day-1 Checklist done |
| ACTIVE | In iteration | Bootstrap done | Done Declaration or Abandoned |
| PAUSED | Work stopped temporarily | User decision | User resumes or abandons |
| DONE | Project complete | Done Declaration | Retrospective complete |
| ABANDONED | Project killed | User decision or probe failure | Retrospective (abbreviated) |

### Done Declaration

A project is DONE when:

```
DONE DECLARATION CHECKLIST

[ ] Success metric (from Requirements Brief S6) has been met OR explicitly waived
[ ] All P0 TODOs resolved
[ ] No open P0/P1 circles
[ ] Core flow works end-to-end (from Requirements Brief T1)
[ ] Top 3 user stories (from Requirements Brief T2) are implemented
[ ] Tests passing (quality gates met)
[ ] CLAUDE.md is accurate and current
[ ] User confirms: "This project is done"

DONE DECLARATION RESULT: DONE / NOT DONE (if any box unchecked)
```

### Proactive Done-Checking

The platform SHOULD proactively ask about project completion when:

- All P0 and P1 TODOs are marked complete
- The success metric appears to be met
- No new features have been requested for 2+ sessions
- The user's conversation shifts to a different project

Ask: "It looks like {project} might be done -- the success metric was {metric} and {evidence}. Should we declare it done and run the retrospective?"

NEVER assume a project is done. ALWAYS ask.

---

## 9. Retrospective Protocol

WHEN a project is declared DONE (S8 Done Declaration), THEN run the retrospective. The retrospective produces findings that feed into framework evolution (S10).

> See ITERATION.md for pass logs and variance tracking referenced during evidence gathering.
> See PHILOSOPHY.md for the Kaizen principle that drives continuous improvement from retrospective findings.

### Retrospective Process

```
RETROSPECTIVE PROTOCOL (run once per completed project)

1. GATHER EVIDENCE
   - Read the project's CLAUDE.md, all ADRs, Decision Records
   - Read the Circle Log (S5 Circle Log)
   - Read the Session Handoff Records (ITERATION.md)
   - Read the Trend Log (ITERATION.md)
   - Read the Cost Log (S7 AI Cost Tracking)
   - Read the Requirements Brief -- compare plan vs. outcome

2. ANALYZE PROCESS
   For each framework file, ask:
   - Did we follow this protocol? If not, why?
   - Did the protocol help? What worked well?
   - Did the protocol hinder? What added overhead without value?
   - Was anything missing? What did we need that didn't exist?

3. IDENTIFY PATTERNS
   - Efficiency gains: what made us faster?
   - Anti-patterns: what made us slower?
   - Circles: what were the root causes?
   - Surprises: what did we not expect?
   - Cost patterns: which tiers were over/under-utilized?

4. PRODUCE RETROSPECTIVE REPORT (see template below)

5. FEED IMPROVEMENTS INTO FRAMEWORK EVOLUTION (S10)
```

### Retrospective Report Template

```markdown
# Retrospective Report -- {Project Name}

## Project Summary
- **Duration**: {start date} to {end date}
- **Success metric**: {metric} -- MET / NOT MET / PARTIALLY MET
- **Total passes**: {count}
- **Success rate**: {pass/total}
- **Circles detected**: {count by type}
- **Council sessions**: {count}
- **Framework patches produced**: {count}
- **Total AI cost**: ${total} (avg ${per_pass}/pass)

## What Worked
1. {practice that helped -- specific, with evidence}
2. {practice that helped}

## What Didn't Work
1. {practice that hindered -- specific, with evidence}
2. {practice that hindered}

## What Was Missing
1. {protocol or template the framework should have -- specific gap}
2. {protocol or template}

## Circle Analysis
| Circle ID | Type | Root Cause | Resolution | Framework Fix |
|-----------|------|-----------|------------|--------------|
| CIRCLE-001 | {type} | {why it happened} | {how it was resolved} | {what framework change would prevent it} |

## Cost Analysis
- Total project cost: ${total}
- Cost per pass (average): ${avg}
- Tier distribution: TALK {X}% / BUILD {X}% / THINK {X}%
- Cost anomalies: {any sessions that triggered alerts}

## Framework Evolution Recommendations
1. {specific change to a specific file -- e.g., "Add pre-flight gate for API integration points to GENESIS.md"}
2. {specific change}

## Lessons for Future Projects
1. {transferable insight -- not project-specific}
2. {transferable insight}
```

---

## 10. Framework Evolution

The framework evolves based on retrospective findings. Evolution is automatic but disciplined -- every change is versioned, committed, and traceable to the project that motivated it.

> See PHILOSOPHY.md for the five principles that constrain all evolution.
> See ITERATION.md for the PDSA cycle that models the evolution feedback loop.

### Versioning

```
Version format: v{major}.{minor}.{patch}

patch (v6.0.1): Typo fixes, wording improvements, template tweaks
  Does not change behavior. Safe to apply without review.

minor (v6.1.0): New sections, new anti-patterns, new templates, expanded protocols
  Adds capability without breaking existing workflows.

major (v7.0.0): Structural reorganization, removed protocols, philosophy changes
  Breaking changes. Requires reading the changelog before continuing.
```

### Auto-Evolution Rules

The platform applies improvements from retrospectives directly to v6 files, subject to these rules:

```
AUTO-EVOLUTION RULES

ALLOWED automatically:
  - Adding new anti-patterns to existing anti-pattern tables
  - Adding new templates or checklists
  - Adding new sections to existing files
  - Expanding existing protocols with additional guidance
  - Adding cross-references between files

REQUIRES human confirmation:
  - Modifying existing protocols (changing how things work)
  - Removing sections or templates
  - Changing philosophy or principles (PHILOSOPHY.md)
  - Changing the interview questions (GENESIS.md)
  - Any change to CLAUDE.md operating modes

NEVER automated:
  - Removing Unbreakable Rules
  - Changing the five-lens test (Kaizen-Deming-Unix-AI-Native-Parallel)
  - Deleting framework files
```

### Evolution Commit Format

Every framework change MUST be committed with this message format:

```
framework(v6.X.Y): {description}

Source: {project name} retrospective
Finding: {what the retrospective identified}
Change: {what was modified in the framework}
```

### Changelog

Maintain the changelog in INDEX.md's Framework Version table. Each entry includes version, date, change description, and source project.

### Quarterly Holistic Review

Every quarter (or after every 3 completed projects, whichever comes first), run a holistic framework review:

```
QUARTERLY REVIEW PROTOCOL

1. Read ALL framework files end-to-end
2. Check for:
   - Contradictions between files (e.g., GENESIS.md says X, ITERATION.md says not-X)
   - Unused protocols (defined but never referenced in any project)
   - Missing protocols (gaps discovered in 2+ projects)
   - Outdated references (model IDs, tool versions, ecosystem changes)
   - Bloat (sections that could be consolidated)
3. Produce a review summary with recommended changes
4. Apply changes using the auto-evolution rules above
5. Bump version accordingly
```

---

## 11. Cross-Project Learning

Circle patterns and efficiency gains from one project automatically inform the next -- not just through framework updates (S10), but through project-specific intelligence.

> See PHILOSOPHY.md for Kaizen: compound small improvements across projects.
> See HANDHOLDING.md for how cross-project warnings are surfaced to newcomers.

### Pattern Library

Maintain a pattern library of recurring solutions and anti-patterns discovered across projects.

```
CROSS-PROJECT PATTERN

ID: PATTERN-{NNN}
Name: {descriptive name}
Type: EFFICIENCY | ANTI-PATTERN | ARCHITECTURE | PROCESS
Discovered In: {project name}
Confirmed In: {list of projects where this pattern reappeared}
Description: {what the pattern is -- 2-3 sentences}
Application: {when to apply this pattern in future projects}
```

Store in `.claude/projects/*/memory/pattern-library.md`. Read at project kickoff (before the interview).

### Cross-Project Intelligence at Interview Time

During the Requirements Interview (see GENESIS.md), the platform SHOULD:

1. Read the pattern library
2. Check if any known anti-patterns match the new project's characteristics
3. Proactively warn: "In {previous project}, we hit {pattern}. For this project, consider {mitigation}."

---

## 12. Portfolio Dashboard

The portfolio dashboard provides a strategic view across ALL active projects.

> See S5 (Mission Control Dashboard) for the per-project view.
> See S8 (Project Lifecycle) for status definitions and done-checking.

### Portfolio View

```
PORTFOLIO DASHBOARD
================================================================

ACTIVE PROJECTS
  {project_1}: ACTIVE -- Phase: iteration -- Circles: 2 -- Health: *
  {project_2}: ACTIVE -- Phase: testing -- Circles: 0 -- Health: *
  {project_3}: PAUSED -- Phase: iteration -- Circles: 1 -- Health: o

STRATEGIC GOALS (portfolio-level)
  1. {goal} -- {metric} -- {target} -- {status}
  2. {goal} -- {metric} -- {target} -- {status}

STALLED PROJECTS (no activity > 7 days)
  {project_4}: Last touched 2026-03-01 -- Action: ask user to resume or abandon

READY FOR RETROSPECTIVE
  {project_5}: All TODOs done, success metric met -- Action: propose Done Declaration

FRAMEWORK HEALTH
  Version: v6.1.0
  Last evolution: {date} from {project}
  Next quarterly review: {date}
  Total patterns in library: {count}

================================================================
```

---

## 13. Decision Velocity Tracking

Track how fast decisions are being made and whether the framework is adding overhead or removing it.

> See TEAM.md for Council Protocol that produces the decisions being measured.
> See ITERATION.md for pass metrics that feed velocity calculations.

### Decision Velocity Metrics

| Metric | Healthy | Warning | Action |
|--------|---------|---------|--------|
| Time from question to Council decision | < 30 min | > 60 min | Simplify options or pre-filter with IESDS |
| Time from project start to first commit | < 3 hours | > 5 hours | Interview may be too long; adapt per GENESIS.md |
| Passes per feature (average) | 2-4 | > 6 | Objectives too broad; split per ITERATION.md |
| Circle detection to resolution | < 1 session | > 3 sessions | Escalation rules not being followed |

### Session Handoff Intelligence

WHEN context is lost between sessions, THEN the platform SHOULD detect gaps and re-establish context:

1. Read the Session Handoff Record (ITERATION.md)
2. Read the Circle Log (S5 Circle Log)
3. Read the Strategic Goals (S5 Strategic/Tactical Tracker)
4. Read the Project Registry (S8 Project Lifecycle)
5. Read the Cost Log (S7 AI Cost Tracking)
6. Synthesize: "Last session you were working on {pass objective}. There are {N} open circles. Your strategic goal is {goal}. Session cost so far: ${total}. Ready to continue?"

WHEN the handoff record is missing or stale (> 7 days old), THEN ask the user to confirm current state before resuming work.

---

## 14. Claude Code Subprocess Pattern

For projects that call `claude -p` autonomously (e.g., `/api/v1/implement` endpoint):

```python
import subprocess, sys, os

def run_claude_subprocess(prompt: str) -> str:
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    result = subprocess.run(
        ["claude", "-p", "--dangerously-skip-permissions", prompt],
        capture_output=True, text=True,
        stdin=subprocess.DEVNULL,   # NEVER let subprocess read from stdin
        env=env,                     # ALWAYS remove CLAUDECODE to avoid loop detection
        timeout=120,
    )
    return result.stdout
```

**Rules** (all four are MANDATORY -- any one omitted causes silent failure):

| Rule | What breaks without it |
|------|----------------------|
| Remove `CLAUDECODE` env var | Claude detects it's running inside itself and refuses execution |
| Set `stdin=subprocess.DEVNULL` | Interactive stdin prompt blocks forever |
| Set `timeout=` | Claude hangs on ambiguous prompts; subprocess never returns |
| Use `sys.executable` for Python | Wrong interpreter in venvs; import errors from wrong packages |

### sys.executable Rule

ALWAYS use the active interpreter for Python subprocesses:

```python
# WRONG -- breaks in venvs; may use system Python instead of .venv Python
subprocess.run(["python", "script.py"])

# RIGHT -- uses the active interpreter (same venv that started the parent)
subprocess.run([sys.executable, "script.py"])
```

Apply everywhere: Demucs, Wav2Lip, any ML subprocess that requires specific packages from the venv.

### Cooldown Pattern for Subprocess Failures

For long-lived servers that call Claude subprocesses:

```python
import time

COOLDOWN_FAILURES = 0
COOLDOWN_START = 0
COOLDOWN_SECS = 30
MAX_FAILURES = 3

def call_claude_with_cooldown(prompt: str) -> str:
    global COOLDOWN_FAILURES, COOLDOWN_START
    if COOLDOWN_FAILURES >= MAX_FAILURES:
        if time.time() - COOLDOWN_START < COOLDOWN_SECS:
            return "Service temporarily unavailable -- please try again shortly."
        COOLDOWN_FAILURES = 0  # Reset after cooldown
    try:
        result = run_claude_subprocess(prompt)
        COOLDOWN_FAILURES = 0
        return result
    except Exception:
        COOLDOWN_FAILURES += 1
        if COOLDOWN_FAILURES >= MAX_FAILURES:
            COOLDOWN_START = time.time()
        return "Natural fallback response while recovering."
```

3 consecutive failures then 30-second cooldown before retry. ALWAYS provide natural fallback responses rather than raw error messages.

### Multi-Provider Council Seat Invocation

For multi-model Council sessions (see TEAM.md), invoke each seat's model using the appropriate provider SDK. All providers share the same seat prompt template:

```python
import json, os

COUNCIL_SEAT_PROMPT = """You are {seat_name} on a 5-seat AI Council.

Your lens: {lens}
Your core question: {core_question}

## Context Brief
{context_brief}

## Options
{options}

## Instructions
1. Score each option 1-9 on your lens (1=terrible, 9=excellent)
2. Propose your preferred option
3. Provide rationale (2-3 sentences)
4. Issue a VETO only if an option has a critical flaw visible through your lens

Respond in JSON:
{{"seat": "{seat_name}", "proposal": "Option X",
  "scores": {{"Option A": N, "Option B": N}},
  "rationale": "...",
  "veto": null}}
"""
```

**OpenAI provider (o3, o4-mini):**

```python
def invoke_openai_seat(seat_name, lens, core_question, context_brief, options, model="o3"):
    import openai
    prompt = COUNCIL_SEAT_PROMPT.format(
        seat_name=seat_name, lens=lens, core_question=core_question,
        context_brief=context_brief, options=options
    )
    response = openai.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        response_format={"type": "json_object"},
        timeout=300 if model == "o3" else 120,
    )
    return json.loads(response.choices[0].message.content)
```

**Google provider (Gemini 2.5 Pro, Gemini 2.5 Flash):**

```python
def invoke_google_seat(seat_name, lens, core_question, context_brief, options, model="gemini-2.5-pro"):
    import google.generativeai as genai
    prompt = COUNCIL_SEAT_PROMPT.format(
        seat_name=seat_name, lens=lens, core_question=core_question,
        context_brief=context_brief, options=options
    )
    response = genai.GenerativeModel(model).generate_content(
        prompt,
        generation_config=genai.GenerationConfig(
            response_mime_type="application/json"
        ),
    )
    return json.loads(response.text)
```

**Claude provider (uses existing `run_claude_subprocess()`):**

```python
def invoke_claude_seat(seat_name, lens, core_question, context_brief, options):
    """Uses the claude -p subprocess pattern defined above."""
    prompt = COUNCIL_SEAT_PROMPT.format(
        seat_name=seat_name, lens=lens, core_question=core_question,
        context_brief=context_brief, options=options
    )
    raw = run_claude_subprocess(prompt)
    return json.loads(raw)
```

**Parallel seat orchestrator:**

```python
import concurrent.futures

# Map models to their invocation functions
PROVIDER_DISPATCH = {
    "o3": invoke_openai_seat,
    "o4-mini": invoke_openai_seat,
    "gemini-2.5-pro": invoke_google_seat,
    "gemini-2.5-flash": invoke_google_seat,
    "claude-opus": invoke_claude_seat,
}

def run_council_session(seat_assignments: dict, context_brief: str, options: str) -> list:
    """
    seat_assignments: {"C1 Architect": {"model": "gemini-2.5-pro", "lens": "...", "core_question": "..."},
                       "C2 Critic": {"model": "o3", ...}, ...}
    Returns list of seat responses (JSON dicts).
    """
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = {}
        for seat_name, config in seat_assignments.items():
            model = config["model"]
            fn = PROVIDER_DISPATCH.get(model, invoke_claude_seat)
            future = executor.submit(
                fn, seat_name=seat_name, lens=config["lens"],
                core_question=config["core_question"],
                context_brief=context_brief, options=options,
                **({"model": model} if model != "claude-opus" else {})
            )
            futures[future] = seat_name
        for future in concurrent.futures.as_completed(futures):
            seat = futures[future]
            try:
                results.append(future.result())
            except Exception as e:
                # Fallback: seat returns error, will be re-run as Claude Opus
                results.append({"seat": seat, "error": str(e), "fallback": True})
    return results
```

**Rules for multi-provider invocation:**

| Rule | Rationale |
|------|-----------|
| IDENTICAL prompt to every model | Information barrier -- no model gets extra context |
| Parallel execution (ThreadPoolExecutor) | Models must not see each other's output |
| Per-model timeout (120s fast / 300s reasoning) | Prevent latency drag anti-pattern |
| Fallback on error then Claude Opus | Every seat must produce scores; tag `[FALLBACK]` in Decision Record |
| Log cost per invocation | Prevent cost runaway anti-pattern |

---

## 15. Multi-Phase Verification Pipeline

Every project with automated builds gets a 3-tier verify pipeline. Scripts live in `scripts/`.

```bash
# verify-fast.sh -- target: < 60 seconds
# Checks: sanity (env/tools present), build (no signing), unit tests, smoke

# verify-full.sh -- full confidence
# Checks: fast + benchmark sanity + runtime launch

# completion-loop.sh -- strict cycles
# Runs: baseline -> full confidence -> acceptance
# On failure: classify -> record -> consult quality gate -> rerun -> verify
```

ALWAYS run `verify-fast` before any commit.
ALWAYS run `verify-full` before any release.
NEVER skip to acceptance without fast + full passing.

### Reusable Verify Toolkit

v6 provides a shared toolkit at `v6/scripts/verify-toolkit.sh` that eliminates per-project infrastructure rebuilding. Source it in your project's verify scripts:

```bash
#!/bin/bash
# verify-fast.sh -- Project-specific (50 lines, not 600)
set -euo pipefail
cd "$(dirname "$0")/.."
source /path/to/v6/scripts/verify-toolkit.sh

VERIFY_MODE="fast"
trap vtk_finalize EXIT
vtk_acquire_lock

# Register project-specific gates
vtk_register_gate G0 "Toolchain Gate"
vtk_register_gate G1 "Compile Gate"
vtk_register_gate G2 "Test Gate"
vtk_register_gate G9 "Release Gate"

# Snapshot source tree
vtk_snapshot_source_tree

# G0: Toolchain
vtk_gate_set G0 "running"
vtk_require_command swift
vtk_require_command xcodebuild
vtk_gate_set G0 "passed"

# G1: Compile
vtk_gate_set G1 "running"
xcodebuild -scheme MyApp CODE_SIGNING_ALLOWED=NO build
vtk_assert_source_tree "compile"
vtk_gate_set G1 "passed"

# G2: Test
vtk_gate_set G2 "running"
swift test
vtk_assert_source_tree "test"
vtk_gate_set G2 "passed"

vtk_gate_set G9 "passed" "Fast verification complete."
vtk_log "verify-fast: PASS"
```

The toolkit provides: gate management (`vtk_register_gate`, `vtk_gate_set`), source-tree integrity guard (`vtk_snapshot_source_tree`, `vtk_assert_source_tree`), review trigger logging, gate report JSON generation, and run locking.

Your project defines only: which gates exist, what commands to run, and in what order. The infrastructure (600+ lines in Podbot) becomes 50 lines of project-specific logic.

### verify-full.sh Template (with toolkit)

```bash
#!/bin/bash
# verify-full.sh -- Full confidence: fast + benchmarks + runtime
set -euo pipefail
cd "$(dirname "$0")/.."
source /path/to/v6/scripts/verify-toolkit.sh

VERIFY_MODE="full"
trap vtk_finalize EXIT
vtk_acquire_lock

# Register all gates (G0-G9)
vtk_register_gate G0 "Toolchain Gate"
vtk_register_gate G1 "Compile Gate"
vtk_register_gate G2 "Test Gate"
vtk_register_gate G3 "Runtime Smoke Gate"
vtk_register_gate G4 "Benchmark Gate"
vtk_register_gate G8 "UX/Product Gate"
vtk_register_gate G9 "Release Gate"

vtk_snapshot_source_tree

# ... fast gates (G0-G2) ...

# G3: Runtime smoke
vtk_gate_set G3 "running"
{launch_and_check_command}
vtk_assert_source_tree "runtime smoke"
vtk_gate_set G3 "passed"

# G4: Benchmark
vtk_gate_set G4 "running"
{benchmark_command}
vtk_gate_set G4 "passed"

# G8: Manual review
vtk_gate_set G8 "manual" "Run Steve quality review before release."

vtk_gate_set G9 "passed" "Full verification complete."
vtk_log "verify-full: PASS"
```

---

## 16. Council Session Reporting

Every Council session produces a structured Council Decision Record (CDR). The CDR uses the anthropomorphized persona names defined in TEAM.md §3 so that the record reads as a genuine deliberation -- not a model invocation log.

> See TEAM.md §10 for the full Council Protocol, seat definitions, and convergence mechanisms.
> See S5 (Council Session Log) for the dashboard-level summary that feeds from this record.

### Council Decision Record Template

Store at: `Docs/council-sessions/COUNCIL-{NNN}-{date}-{topic}.md`
Auto-generated after every Council session by `scripts/generate-council-report.sh`.

```markdown
# Council Session COUNCIL-{NNN}: {Topic}

**Date:** {YYYY-MM-DD}
**Convened by:** {Persona name} ({tier}) -- e.g., Aria (THINK)
**Reason convened:** {one sentence: what triggered this Council call}

---

## Who Was at the Table

| Seat | Persona | Model | Provider |
|------|---------|-------|----------|
| C1 -- The Architect | {name, e.g. Aria} | {model, e.g. claude-opus-4} | Anthropic |
| C2 -- The Critic | {name, e.g. Dr. Kai} | {model, e.g. o3} | OpenAI |
| C3 -- The Pragmatist | {name, e.g. Marcus} | {model, e.g. claude-sonnet-4-6} | Anthropic |
| P4 -- {Domain Seat} | {name} | {model} | {provider} |
| P5 -- {Domain Seat} | {name} | {model} | {provider} |

> Any seat marked `[FALLBACK]` means the assigned model was unavailable; Claude Opus stood in.

---

## What Each Seat Said

### C1 -- The Architect ({Persona Name})

> *Thinking like someone who maps unknown territory before building on it -- what structure survives 10x scale?*

{2-4 sentences written in The Architect's voice: focus on system design, structural integrity, future optionality. Reference the dependency graph. Be decisive but acknowledge tradeoffs.}

**Scores:** Option A: {N}/9 | Option B: {N}/9 | Option C: {N}/9
**Proposal:** Option {X}
**Veto issued:** None / Yes -- {reason}

---

### C2 -- The Critic ({Persona Name})

> *Thinking like a crash-test engineer -- how does this break, and can the defense survive the attack?*

{2-4 sentences written in The Critic's voice: adversarial, specific about failure modes, evidence-driven. Never vibes. Name the worst-case scenario explicitly.}

**Scores:** Option A: {N}/9 | Option B: {N}/9 | Option C: {N}/9
**Proposal:** Option {X}
**Veto issued:** None / Yes -- {reason with evidence}

---

### C3 -- The Pragmatist ({Persona Name})

> *Thinking like an engineer who builds the load-bearing room while the roofline debate continues -- what ships by Friday?*

{2-4 sentences written in The Pragmatist's voice: simplicity, user value, compute cost before theory. Push back on complexity that doesn't earn its weight.}

**Scores:** Option A: {N}/9 | Option B: {N}/9 | Option C: {N}/9
**Proposal:** Option {X}
**Veto issued:** None

---

### P4 -- {Domain Seat Name} ({Persona Name})

> *{One-sentence description of this seat's lens for this session.}*

{2-4 sentences in this seat's voice and domain lens.}

**Scores:** Option A: {N}/9 | Option B: {N}/9 | Option C: {N}/9
**Proposal:** Option {X}
**Veto issued:** None / Yes -- {reason}

---

### P5 -- {Domain Seat Name} ({Persona Name})

> *{One-sentence description of this seat's lens for this session.}*

{2-4 sentences in this seat's voice and domain lens.}

**Scores:** Option A: {N}/9 | Option B: {N}/9 | Option C: {N}/9
**Proposal:** Option {X}
**Veto issued:** None / Yes -- {reason}

---

## Convergence

**Mechanism used:** {Borda Count / Nash Bargaining / Approval Voting / Weighted Scoring}

### Score Summary

| Option | C1 Architect | C2 Critic | C3 Pragmatist | P4 {Seat} | P5 {Seat} | Normalized Avg |
|--------|-------------|-----------|---------------|-----------|-----------|----------------|
| Option A | {N}/9 | {N}/9 | {N}/9 | {N}/9 | {N}/9 | {avg} |
| Option B | {N}/9 | {N}/9 | {N}/9 | {N}/9 | {N}/9 | {avg} |
| Option C | {N}/9 | {N}/9 | {N}/9 | {N}/9 | {N}/9 | {avg} |

**Winning option:** Option {X} (normalized avg: {score})
**Margin over next-best:** {delta}

---

## The Decision

**Decided:** {Option name and one-sentence summary of what was chosen}

**Why:** {2-3 sentences explaining the reasoning that emerged from convergence -- not just the scores, but what the Council collectively understood that made this the right call. Written in plain English, not as a formula.}

---

## Dissent and Concerns

| Seat | Type | Detail |
|------|------|--------|
| {Seat} | Veto (BLOCKED) / Minority position / Risk accepted | {specific concern, evidence cited} |

> If no dissent: "All seats aligned. No vetoes, no minority positions."
> Vetoes that were not resolved block the decision. Record here and escalate to Human.

---

## Impact

**Files affected:**
- `{path/to/file.ext}` -- {what changes and why}
- `{path/to/file.ext}` -- {what changes and why}

**ADR required:** Yes -- write ADR-{NNN} / No
**Rollback plan:** {If this decision proves wrong in {N} passes, revert by: {specific rollback steps}}

---

*Generated by `scripts/generate-council-report.sh` on {datetime}*
*Session duration: {N} minutes | Total cost: ${cost} | Seats: {model list}*
```

### Council Reporting Cadence

- Auto-generated immediately after every Council session closes (convergence reached or veto escalated).
- The session summary in the Mission Control dashboard (S5 Council Session Log) is a one-row excerpt from this record.
- The Weekly Team Activity Report (S17) references these records by COUNCIL-NNN ID.

---

## 17. Team Activity Reporting

A weekly Team Activity Report aggregates what the team shipped, how tiers were used, which escalations happened, and what improved. It is the Kaizen reflection made permanent.

> See TEAM.md §3 for persona definitions and tier assignments.
> See S7 (AI Cost Tracking) for the cost data this report aggregates.
> See S9 (Retrospective Protocol) for how these reports feed retrospective analysis.

### Weekly Team Activity Report Template

Store at: `Docs/team-reports/TEAM-REPORT-{YYYY-MM-DD}.md`
Auto-generated at end of each week or project phase by `scripts/generate-team-report.sh`.

```markdown
# Team Activity Report -- Week of {YYYY-MM-DD}

**Project:** {project name}
**Phase:** {current phase -- e.g., iteration, testing}
**Passes completed this week:** {NNN} (P{start} -- P{end})
**Report generated:** {datetime}

---

## Team Performance Summary

| Team Member | Sessions | Tasks Completed | Escalations (out) | Est. Cost |
|-------------|----------|-----------------|-------------------|-----------|
| Aria (THINK / Claude Opus) | {N} | {N} | {N} | ${cost} |
| Marcus (BUILD / Claude Sonnet) | {N} | {N} | {N} | ${cost} |
| Zara (TALK / Claude Haiku) | {N} | {N} | {N} | ${cost} |
| Dr. Kai (Research / o3) | {N} | {N} | {N} | ${cost} |
| Pixel (Visual QA / Playwright) | {N} | {N} | N/A | $0 |
| **TOTAL** | | {N} | {N} | **${total}** |

> "Sessions" = number of separate invocations. "Tasks Completed" = TODOs closed. "Escalations (out)" = how many times this member escalated upward.

---

## Tier Distribution

| Tier | Target | Actual | Status |
|------|--------|--------|--------|
| TALK (Zara / Haiku) | 25% of tokens | {X}% | {On target / Over / Under} |
| BUILD (Marcus / Sonnet) | 60% of tokens | {X}% | {On target / Over / Under} |
| THINK (Aria / Opus) | 15% of tokens | {X}% | {On target / Over / Under} |
| COUNCIL (mixed) | Ad hoc | {N} sessions | -- |

> Over-THINK (>30%) signals BUILD is being bypassed -- review task routing.
> Under-BUILD (<40%) signals over-planning or over-escalation.

---

## Council Sessions This Week

**Count:** {N} sessions

| ID | Topic | Decision | Duration | Cost |
|----|-------|----------|----------|------|
| COUNCIL-{NNN} | {topic} | {one-line decision} | {N}m | ${cost} |
| COUNCIL-{NNN} | {topic} | {one-line decision} | {N}m | ${cost} |

> Full records in `Docs/council-sessions/`.

---

## Escalation Log

| # | From | To | Reason | Category | Outcome | Duration |
|---|------|----|--------|----------|---------|----------|
| ESC-{N} | {Persona} | {Persona / Human} | {brief reason} | TECHNICAL / ARCHITECTURAL / BLOCKED / POLICY / 3-FAIL | {resolution} | {N}m |

> Escalation categories: see S5 (Escalation Tracker) for definitions.
> Repeat escalations with the same FROM + REASON = signal to reassign task type.

---

## Circles Detected

| ID | Type | Description | Status | Resolution |
|----|------|-------------|--------|------------|
| CIRCLE-{NNN} | Type 1 / 2 / 3 | {brief description} | ACTIVE / RESOLVED | {resolution or "pending"} |

> Type 1: revisited decision. Type 2: repeated failure. Type 3: scope creep.
> "None detected this week" is a valid and good entry.

---

## Quality Gates

| Gate | Runs | Passed | Failed | Pass Rate |
|------|------|--------|--------|-----------|
| G0 Toolchain | {N} | {N} | {N} | {X}% |
| G1 Compile | {N} | {N} | {N} | {X}% |
| G2 Test | {N} | {N} | {N} | {X}% |
| G3 Runtime Smoke | {N} | {N} | {N} | {X}% |
| G4 Benchmark | {N} | {N} | {N} | {X}% |
| G8 UX/Product | {N} | {N} | {N} | {X}% |

> Gates with pass rate < 80% over 3+ runs signal a systemic issue -- open a circle.

---

## Kaizen Reflection

**What improved this week:**
1. {specific measurable improvement -- e.g., "Average pass duration dropped from 22m to 14m after splitting broad objectives"}
2. {specific improvement}

**What should improve next week:**
1. {specific target with hypothesis -- e.g., "BUILD tier at 48%; target 60% by routing boilerplate to Zara first"}
2. {specific target}

**Pattern noticed:**
{Any recurring theme -- good or bad -- that appeared 2+ times this week. If none: "No new patterns detected."}

---

*Generated by `scripts/generate-team-report.sh`*
*Data sources: session logs, cost log, escalation tracker, circle log, gate reports*
```

### Team Reporting Cadence

- Generated at the end of each week (Friday session end) or at every project phase boundary.
- Feeds into the Retrospective Report (S9) as the primary source of team performance data.
- The Kaizen Reflection section is NOT optional -- it is what converts a status report into an improvement engine.

---

## 18. Auto-Generation Hooks

The reporting pipeline is automated. Three hooks/scripts handle report generation so no session ends without a record.

### Hook and Script Map

| Trigger | File | Output |
|---------|------|--------|
| Session end | `.claude/hooks/session-end` | Session summary appended to `Docs/session-log.md` |
| Council session closes | `scripts/generate-council-report.sh` | `Docs/council-sessions/COUNCIL-{NNN}-{date}-{topic}.md` |
| Weekly / phase boundary | `scripts/generate-team-report.sh` | `Docs/team-reports/TEAM-REPORT-{date}.md` |

### `.claude/hooks/session-end`

Runs automatically when a Claude Code session ends. Appends a session summary to the session log and prompts for standup generation if not already done.

```bash
#!/bin/bash
# .claude/hooks/session-end -- Session end summary hook
set -euo pipefail
DOCS_DIR="$(git rev-parse --show-toplevel)/Docs"
mkdir -p "$DOCS_DIR"
SESSION_LOG="$DOCS_DIR/session-log.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")
echo "" >> "$SESSION_LOG"
echo "## Session End -- $TIMESTAMP" >> "$SESSION_LOG"
echo "<!-- Fill in: passes completed, TODOs closed, circles detected, next focus -->" >> "$SESSION_LOG"
echo "Session summary stub written to $SESSION_LOG"
```

### `scripts/generate-council-report.sh`

Generates a fully anthropomorphized Council Decision Record from the raw seat JSON output produced by `run_council_session()` (see S14). Seat scores, rationale, and proposals are formatted into the Council Decision Record template using the persona names from TEAM.md §3.

```bash
#!/bin/bash
# scripts/generate-council-report.sh -- Generate Council Decision Record
# Usage: generate-council-report.sh <session-json> <council-number> <topic-slug>
set -euo pipefail
SESSION_JSON="${1:?Usage: generate-council-report.sh <session.json> <NNN> <topic-slug>}"
COUNCIL_NNN="${2:?}"
TOPIC_SLUG="${3:?}"
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="$(git rev-parse --show-toplevel)/Docs/council-sessions"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/COUNCIL-${COUNCIL_NNN}-${DATE}-${TOPIC_SLUG}.md"
# Populate the template from session JSON using the persona map
python3 "$(dirname "$0")/council-report-formatter.py" \
    --session "$SESSION_JSON" \
    --number "$COUNCIL_NNN" \
    --topic "$TOPIC_SLUG" \
    --date "$DATE" \
    --output "$OUTPUT_FILE"
echo "Council Decision Record written to: $OUTPUT_FILE"
```

### `scripts/generate-team-report.sh`

Aggregates session logs, cost records, escalation tracker, and circle log to produce the Weekly Team Activity Report. Run at session end on the last day of the week, or whenever a phase boundary is reached.

```bash
#!/bin/bash
# scripts/generate-team-report.sh -- Generate Weekly Team Activity Report
# Usage: generate-team-report.sh [YYYY-MM-DD]
set -euo pipefail
REPORT_DATE="${1:-$(date +%Y-%m-%d)}"
OUTPUT_DIR="$(git rev-parse --show-toplevel)/Docs/team-reports"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/TEAM-REPORT-${REPORT_DATE}.md"
python3 "$(dirname "$0")/team-report-aggregator.py" \
    --week-of "$REPORT_DATE" \
    --output "$OUTPUT_FILE"
echo "Team Activity Report written to: $OUTPUT_FILE"
```

### Auto-Generation Rules

- NEVER skip report generation at session end -- even a stub is better than silence.
- ALWAYS name files with zero-padded numbers (`COUNCIL-001`, not `COUNCIL-1`) so directory listings sort correctly.
- WHEN a Council session produces a veto that blocks the decision, THEN mark the CDR `STATUS: BLOCKED` in the header and escalate before archiving.
- WHEN the team report shows the same circle type 3+ weeks in a row, THEN open a framework evolution ticket (S10).

---

## 19. Source-Tree Integrity Guard

Build tools sometimes silently modify tracked files -- xcodeproj state, lock files, package resolution artifacts, auto-generated code. The integrity guard prevents false-green builds by failing the verification run if any tracked file mutates during the build.

### Pattern

```bash
# 1. Snapshot tracked-file state at verification start
BASELINE="$(git diff --name-only && git diff --cached --name-only | sort -u)"

# 2. Assert after each build/test phase
assert_source_tree_integrity() {
  local stage="$1"
  local current
  current="$(git diff --name-only && git diff --cached --name-only | sort -u)"
  if [[ "${current}" != "${BASELINE}" ]]; then
    echo "Source-tree integrity guard FAILED after ${stage}" >&2
    diff <(echo "$BASELINE") <(echo "$current") >&2
    exit 1
  fi
}

# 3. Call after every phase
run_build
assert_source_tree_integrity "build phase"
run_tests
assert_source_tree_integrity "test phase"
```

### When to Use

ALWAYS use in verify-fast.sh and verify-full.sh.
ALWAYS assert after: package resolution, compilation, test execution, benchmark runs.
WHEN the guard triggers, THEN investigate which tool mutated files -- do NOT just `git checkout` the changes and continue.

### Common Causes

| Mutated File | Likely Cause | Fix |
|-------------|-------------|-----|
| `*.xcodeproj/project.pbxproj` | Xcode regenerated project state | Isolate DerivedData; use `-clonedSourcePackagesDirPath` |
| `Package.resolved` | Swift PM resolved dependencies | Pin exact versions; resolve before build |
| `*.lock` | Lock file updated during build | Commit lock file before verification |
| Generated source files | Code generation step | Run codegen before snapshotting baseline |

---

## 20. Framework Versioning Protocol

The NewDevelopment framework itself is versioned. Every change to v6 files is tracked, committed with clear provenance, and logged in the INDEX.md version table.

> See S10 (Framework Evolution) for the evolution protocol that drives version changes.
> See S9 (Retrospective Protocol) for the retrospective protocol that produces evolution recommendations.

### Version Format

```
v{major}.{minor}.{patch}

patch (v6.0.1):
  Typo fixes, wording improvements, template tweaks.
  Does not change behavior. Safe to apply without review.

minor (v6.1.0):
  New sections, new anti-patterns, new templates, expanded protocols.
  Adds capability without breaking existing workflows.

major (v7.0.0):
  Structural reorganization, removed protocols, philosophy changes.
  Breaking changes. Requires reading the changelog before continuing.
```

### Commit Message Format

Every framework change MUST be committed with this format:

```
framework(v6.X.Y): {description}

Source: {project name} retrospective | quarterly review | platform creation
Finding: {what was identified -- one sentence}
Change: {what was modified -- file and section}
```

### What Triggers a Version Bump

| Trigger | Version Type | Example |
|---------|-------------|---------|
| Project retrospective finding | patch or minor | "Add API timeout anti-pattern to GENESIS.md" |
| Quarterly holistic review | patch or minor | "Fix contradiction between ITERATION.md and QUALITY.md" |
| New protocol or capability | minor | "Add MVP Tracker to OPERATIONS.md" |
| Structural reorganization | major | "Split ARCHITECTURE.md into separate files" |
| Philosophy change | major | "Add sixth principle" |

### Version History Location

The authoritative version history lives in INDEX.md's Framework Version table. Every version bump MUST add a row.

### Quarterly Holistic Review

Every quarter (or after every 3 completed projects, whichever comes first):

```
QUARTERLY REVIEW CHECKLIST

[ ] Read ALL framework files end-to-end
[ ] Check for contradictions between files
[ ] Check for unused protocols (defined but never referenced)
[ ] Check for missing protocols (gaps discovered in 2+ projects)
[ ] Check for outdated references (model IDs, tool versions)
[ ] Check for bloat (sections that could be consolidated)
[ ] Produce review summary with recommended changes
[ ] Apply changes per S10 auto-evolution rules
[ ] Bump version and update INDEX.md
```

### Framework Diff Reports

After every minor or major version bump, generate a diff report showing what changed and why:

```markdown
# Framework Diff Report -- v{old} -> v{new}

## Changes by File
| File | Section | Change Type | Description | Source |
|------|---------|-------------|-------------|--------|

## Rationale Chain
Each change traces back to a specific finding:
1. {change} <- {finding} <- {source}
```

Store diff reports as `v6/versions/v{X.Y.Z}-diff.md`.

---

## Related Directives

- See TEAM.md for specialists who produce the code these operations support
- See TEAM.md for escalation protocol when operations fail
- See QUALITY.md for the quality trifecta (test/lint/type) that feeds Build, Tests, and Lint monitors
- See ITERATION.md for the pass loop, trend log, and variance tracking
- See ITERATION.md for circle detection in the pass loop
- See ITERATION.md for session handoff records
- See GENESIS.md for project bootstrapping and requirements interview
- See GENESIS.md for strategic and tactical thinking framework
- See ARCHITECTURE.md for data modeling and self-healing infrastructure
- See DESIGN.md for visual QA that feeds the Screenshots monitor
- See PHILOSOPHY.md for the five-lens test applied to all operational decisions
- See HANDHOLDING.md for newcomer companion and preemptive problem detection
- See CLAUDE.md for platform activation and operating mode routing

---

## Framework Navigation

> **You Are Here:** `OPERATIONS.md` — Dev environment, dashboard, MVP tracker, reporting, versioning
> **Core Method:** Kaizen · Deming · Unix · AI-Native · Parallel → PHILOSOPHY.md

| File | When To Read |
|------|-------------|
| CLAUDE.md | Session start, operating mode routing, unbreakable rules |
| PHILOSOPHY.md | Principle check, five-lens test, enforcement rules |
| GENESIS.md | New project kickoff, requirements interview, probe/bootstrap |
| TEAM.md | AI model selection, Council decisions, persona profiles |
| ARCHITECTURE.md | Module design, dependency management, MAP manifests |
| ITERATION.md | Pass loop, swim lanes, circle detection, session handoff |
| QUALITY.md | Gate verification G0-G9, completion loop, testing |
| DESIGN.md | Visual identity, design gates, component system |
| HANDHOLDING.md | Newcomer guidance, glossary, preemptive help |
| OPERATIONS.md | ★ You are here |
| CHARACTER-TRACKING.md | Team performance, calibration, persona metrics |

> **If lost:** Start at CLAUDE.md. If a concept is unclear, check HANDHOLDING.md §9 Glossary.
> **If stuck:** ITERATION.md §7 Failure Gates (1-fail retry, 2-fail pivot, 3-fail Council).
> **If quality uncertain:** QUALITY.md §1 Gate Runner. If design: DESIGN.md §5 Design Gates.
