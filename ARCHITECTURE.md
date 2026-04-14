# ARCHITECTURE.md -- Structure, Features, Dependencies

> **Kaizen** -- self-healing schemas, evolving architecture, continuous structural improvement.
> **Deming** -- plan-do-study-act, measure everything, eliminate variance before adding features.
> **Unix** -- layered single-responsibility, one authority per state, composable modules.
> **AI-Native** -- AI is a first-class collaborator, not an afterthought bolted onto human workflows.
> **Parallel** -- parallelize by default, serialize only when data depends on a prior step.
> NEVER let a layer import from above. ALWAYS let infrastructure heal itself.

> **Persona Ownership:** Aria (THINK) authors architecture decisions. Marcus (BUILD) applies the module gate. Dr. Kai designs benchmarks. → See CHARACTER-TRACKING.md

---

## 1. Four-Layer Stack

ALWAYS structure non-trivial projects into exactly four layers.
ALWAYS enforce strict downward dependency flow.
NEVER import from a layer above -- stop and refactor.

```
+-----------------------------------+
|           UI Layer                |  Renders state. Captures input.
+----------------+------------------+
                 | calls
                 v
+-----------------------------------+
|          API Layer                |  Validates input. Routes calls.
+----------------+------------------+
                 | calls
                 v
+-----------------------------------+
|        Engine Layer               |  Computes. Decides. Transforms.
+----------------+------------------+
                 | calls
                 v
+-----------------------------------+
|       Storage Layer               |  Reads. Writes. Persists.
+-----------------------------------+
```

### Interface Contracts

| Boundary | Contract |
|----------|----------|
| UI -> API | Request/Response (HTTP, WebSocket, function calls) |
| API -> Engine | Domain types in, domain types out (no HTTP types leak down) |
| Engine -> Storage | Query/Command pattern (read queries, write commands) |

### Layer Rules

| Layer | MUST | MUST NEVER |
|-------|------|-----------|
| UI | Render state, capture input, own visual logic | Contain business logic, query databases |
| API | Validate input, route calls, enforce auth | Contain business logic, render UI |
| Engine | All business logic as pure functions | Import from API/UI, know about HTTP/HTML/DB |
| Storage | Own connections, queries, caching | Contain business logic, return raw rows |

### Example

```
ImageBot:
  UI (index.html, app.js, app.css)
    -> API (FastAPI on :3001)
      -> Engine (prompt construction, edit chain parsing)
        -> Storage (Playwright browser, research.db)
```

---

## 2. Single Source of Truth

EVERY piece of state MUST have exactly one authoritative owner.
EVERYTHING else MUST be a projection that reads from the authority.
NEVER create a second copy of state "for convenience" -- copies drift.

### Anti-Pattern: Dual Ownership

```typescript
// BAD: Two components both own "tasks"
const [tasks, setTasks] = useState([]);  // TaskList.tsx -- owns tasks
const [tasks, setTasks] = useState([]);  // TaskDashboard.tsx -- ALSO owns <- BUG

// GOOD: One authority, multiple projections
const taskStore = { tasks: [], async add(t) { /* post + refresh */ } };
const tasks = useStore(taskStore, s => s.tasks);  // both components read
```

ALWAYS ask: "If this state changes, how many places must I update?" WHEN answer > 1, THEN refactor.

| Situation | Authority | Projections |
|-----------|-----------|-------------|
| User auth | Auth service / JWT | UI login state, API middleware |
| Document editing | Backend daemon or CRDT | Editor UI, word count, outline |
| Feature flags | Config file or service | UI conditionals, API guards |
| Form state | The form component | Preview panel, validation summary |

---

## 3. Feature Registry Pattern

ALWAYS register new capabilities as Feature objects in a single file.
NEVER scatter if-statements or feature checks throughout the codebase.
WHEN an app has 3+ toggleable capabilities, THEN use a registry.

### Feature Interface

```typescript
interface Feature {
  id: string;          // kebab-case: "word-count-goal"
  name: string;        // "Word Count Goal"
  description: string; // One sentence: what it does for the user
  enabled: boolean;    // Toggleable at runtime
  init(): void;        // Called once at startup (if enabled)
  destroy(): void;     // Clean up listeners, DOM, timers
}
```

### Registry (single extension point)

```typescript
// features/registry.ts -- THE ONLY FILE TO EDIT WHEN ADDING A FEATURE
export const features: Feature[] = [wordCountGoal, darkMode];

export function initFeatures(): void {
  for (const f of features) {
    if (f.enabled) {
      try { f.init(); }
      catch (err) { console.error(`[feature] ${f.id} failed:`, err); f.enabled = false; }
    }
  }
}
export function toggleFeature(id: string, on: boolean): void {
  const f = features.find(x => x.id === id);
  if (!f) return;
  if (on && !f.enabled) { f.enabled = true; f.init(); }
  else if (!on && f.enabled) { f.destroy(); f.enabled = false; }
}
```

---

## 4. Feature Lifecycle (6-Stage Pipeline)

ALWAYS move features through this pipeline. NEVER skip stages. NEVER promote without exit criteria.

```
proposed -> approved -> in-progress -> testing -> shipped -> deprecated
```

### Entry/Exit Criteria

| Stage | Entry | Exit |
|-------|-------|------|
| proposed | Problem identified; registry checked for dupes; deps identified | Proposal complete; reviewer has read it |
| approved | Proposal complete; no unanswered questions | Owner assigned; decision recorded; target release set |
| in-progress | Owner assigned; branch created; `needs` deps shipped; registry updated | Code done; tests passing; `files` list updated; no lint errors |
| testing | Code complete; tests exist; registry set to `testing` | Functional + visual QA pass; no regressions; perf acceptable |
| shipped | Testing passed; code review approved | Merged; registry updated; `blocks` notified; release notes |
| deprecated | Replacement exists or feature retired | Code fully removed (deprecation protocol) |

### Feature Proposal Template

```markdown
## Feature: <Name>
**ID**: <kebab-case>  **Category**: core|enhancement|experiment
**Owner**: <name>  **Priority**: P0|P1|P2  **Effort**: S|M|L|XL
### Dependencies
**Needs**: <id>: <why>    **Blocks**: <id>: <what becomes possible>
### Problem
<What user problem? Who? How often?>
### Proposed Solution
<2-3 sentences: what the user sees and interacts with>
### Files Affected
- `path/to/file` -- change description
### Testing Plan
- [ ] Unit: <assertion>  - [ ] Visual: <screenshot check>
### Rollback Plan
<How to safely disable>
```

| Category | Stability |
|----------|-----------|
| **core** | MUST never break. Highest coverage. |
| **enhancement** | MUST be stable. Covered by tests. |
| **experiment** | MAY break. Minimal coverage OK. |

### Sync Points Checklist

ALWAYS verify before promoting to `shipped`.

| Pair | Drift Signal | Detection |
|------|-------------|-----------|
| HTML <-> JS | IDs, classes, data-* | `querySelector` returns null |
| JS <-> Config | Flags, keys, URLs | Feature loads but misbehaves |
| Config <-> DB | Schema fields, columns | Migration errors |
| Tests <-> Code | Selectors, assertions | Test fails, feature works |
| Docs <-> Code | Descriptions, API docs | Docs diverge from behavior |

### Deprecation Protocol (6 steps)

1. **Mark deprecated** in registry: `status: 'deprecated'`, `deprecated_at`, `reason`, `replacement`.
2. **Runtime warning** for 1 release cycle: `console.warn` + optional toast.
3. **Remove UI entry points**: buttons, menu items, nav links.
4. **Remove code**: implementation files, imports, unused utilities.
5. **Remove tests**: test files, update integration tests.
6. **Update docs**: remove from README/FEATURES, add to CHANGELOG.

WHEN security requires immediate removal, THEN skip warning period (emergency deprecation).

---

## 5. Self-Healing Infrastructure

ALWAYS build systems that fix themselves on startup.
NEVER require manual migration for additive changes.
ALWAYS log every self-heal action.
NEVER auto-drop or auto-rename columns -- destructive changes require manual migration.

```python
import sqlite3

def ensure_schema(db_path: str):
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode=WAL")
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )""")
    existing = {row[1] for row in cursor.execute("PRAGMA table_info(items)")}
    for col, sql in {
        "summary": "ALTER TABLE items ADD COLUMN summary TEXT DEFAULT ''",
        "score":   "ALTER TABLE items ADD COLUMN score REAL DEFAULT 0.0",
    }.items():
        if col not in existing:
            cursor.execute(sql); print(f"[schema] Added: {col}")
    conn.commit(); conn.close()
```

### Degradation Hierarchy

| Level | Condition | Behavior |
|-------|-----------|----------|
| 1 | All services up | Normal operation |
| 2 | Optional services down | Core works, degraded features logged |
| 3 | Write services down | Read-only, no mutations |
| 4 | Network down | Cached data only |
| 5 | Core service down | Clear error + recovery instructions |

NEVER silently fail. ALWAYS log what degraded. ALWAYS show user what is available.

---

## 6. File Organization

| Factor | Single-File SPA | Component Tree |
|--------|-----------------|----------------|
| Views | 1-3 | 5+ |
| Lines of JS | < 500 | > 500 |
| Team size | 1 (you + AI) | 2+ |
| Lifespan | Prototype / tool | Long-lived product |
| Build step | None (file://) | Required (Vite) |

WHEN `app.js` exceeds ~500 lines or needs 3+ views, THEN graduate to component tree.

**Single-File SPA**: `index.html` + `app.js` + `app.css` + `server.py` + `CLAUDE.md`

**Component Tree**: `src/{main.tsx, App.tsx, pages/, components/, features/, hooks/, stores/, types/, utils/}` + `tests/` + `CLAUDE.md`

### Config-Driven vs Code-Driven

| Factor | Config (JSON/YAML) | Code (TypeScript) |
|--------|-------------------|-------------------|
| Non-devs change behavior | Yes | No |
| Multiple deployments | Yes | No |
| Type safety | No | Yes |

**Default**: Start code-driven. Move to config-driven ONLY with concrete need.

---

## 7. State Management Spectrum

ALWAYS match storage strategy to data lifecycle.

```
Ephemeral <---------------------------------------------> Permanent
Component state    Module cache    localStorage    DB    External API
```

| Data Type | Store | Cache | Persist | Real-time |
|-----------|-------|-------|---------|-----------|
| User prefs | localStorage | No | Yes | No |
| Document | Backend DB | 30s cache | No | WebSocket |
| Market prices | External API | 5s cache | No | WebSocket |
| UI layout | Component state | No | localStorage | No |
| Auth token | Memory + localStorage | No | Yes | No |
| Form draft | Component state | No | localStorage | No |

---

## 8. Dependency Management

### Per-Ecosystem Rules

**Python**: ALWAYS one `.venv/` per project. ALWAYS pin ranges with annotations. ALWAYS log incompatibilities in CLAUDE.md.
```txt
fastapi>=0.100,<1.0          # avoid 1.0 breaking changes
playwright>=1.40,<2.0         # major versions break browser APIs
transformers>=4.40,<5.0       # coqui-tts incompatible with 5.x
```

**Node.js**: ALWAYS commit lockfile. ALWAYS `--save-exact` for unstable libs. ALWAYS specify engine: `{ "engines": { "node": ">=20 <22" } }`

**Rust**: ALWAYS workspace deps in root `Cargo.toml`. ALWAYS feature flags for optional deps. ALWAYS `cargo tree --duplicates`.
```toml
[workspace.dependencies]
axum = "0.7"
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
```

### Vendoring Protocol

VENDOR ONLY when upstream unresponsive AND patch critical.
NEVER vendor 50+ transitive deps. ALWAYS set quarterly review.

1. Copy to `vendor/<name>/`. 2. Pin original version. 3. Apply minimal patches.
4. Document in `vendor/<name>/PATCHES.md`. 5. Update imports. 6. Set review date.

```markdown
# Patches for <library> v<X.Y.Z>
**Vendored from**: <URL>  **On**: <date>  **Reason**: <why>
**Upstream issue**: <link>  **Review date**: <next quarter>
## Patch 1: <title>
**File**: `<path>`  **Reason**: <why>  **Change**: <what>
```

### Dependency Health Report

ALWAYS run on first Monday of every month.

| Ecosystem | Outdated | Security | Tree |
|-----------|----------|----------|------|
| Python | `pip list --outdated` | `pip-audit` | `pipdeptree` |
| Node.js | `npm outdated` | `npm audit` | `npm ls` |
| Rust | `cargo outdated` | `cargo audit` | `cargo tree` |

### Feature-Module Dependency Matrix

ALWAYS maintain. WHEN dep breaks, search "Depends On" for blast radius.

| Feature | Depends On | Constraint | Status | Risk | Notes |
|---------|-----------|------------|--------|------|-------|
| {feature} | {lib} | {ver} | healthy/fragile/vendored | low/med/high/crit | {notes} |

| Risk | Definition | Action |
|------|-----------|--------|
| low | Stdlib, well-maintained | Monitor monthly |
| medium | Maintained, has broken before | Pin range, test on update |
| high | Abandoned, no replacement | Vendor or migrate |
| critical | Known CVE, actively breaking | Fix now, escalate to Council |

### AI Model Dependency Table

| Workflow | Primary | Fallback 1 | Fallback 2 | Tokens | Cost |
|----------|---------|------------|------------|--------|------|
| Architecture | Opus | Sonnet (degraded) | Human | ~8K | high |
| Implementation | Sonnet | Opus (overkill) | Haiku (shallow) | ~12K | medium |
| Quick tasks | Haiku | Sonnet | (wait) | ~2K | low |
| Code review | Opus | Sonnet | (wait) | ~6K | high |
| Research | o3 | Opus | (wait) | ~10K | high |
| Visual QA | Playwright | -- | -- | 0 | free |
| Council (multi-model) | Opus + o3 + Gemini | Opus (all seats) | Sonnet (all seats) | ~25K combined | very high |

```
Fallback chains:
  Architecture:    Opus -> Sonnet (degraded) -> Human
  Implementation:  Sonnet -> Opus -> Haiku
  Quick tasks:     Haiku -> Sonnet -> (wait)
  Research:        o3 -> Opus -> (wait)
  Council:         Multi-model (Opus + o3 + Gemini) -> Single-model (Opus all seats) -> Reduced (Sonnet) -> Human
```

**Council fallback detail**: If any external model (o3, Gemini) is unavailable during a multi-model Council session, that seat falls back to Claude Opus with a `[FALLBACK]` tag. If ALL external models are unavailable, the Council degrades to single-model Opus (all 5 seats). See TEAM.md §10.2 (seat assignment) and §10.8 (session protocol).

ALWAYS test before migrating model versions. ALWAYS log migrations.

---

## 9. Structured Output Pattern for AI Pipelines

When Claude Code needs to output code that will be applied programmatically (autonomous feature implementation, patch application), use XML file tags:

```
<FILE path="src/components/Button.tsx">
[file contents]
</FILE>
```

**Why XML tags?** This format survives learning-mode prose injection — AI prose will not corrupt the file content the way markdown code blocks can. A subprocess that parses `<FILE path="...">` blocks is robust to surrounding explanation text.

ALWAYS use this format when:
- An LLM subprocess writes code that another process will apply to disk
- An `/api/implement` endpoint receives code from Claude and writes it to files
- A pipeline chains AI output as input to another transformation

NEVER rely on markdown code fences (``` ```) for machine-parsed output — prose can wrap inside them and corrupt the content.

---

## 10. Edit Chain Pattern

For iterative AI-driven modifications where each edit builds on the last:

- Lock the prompt format: `Edit the file {filename}: <instruction>`
- Parse with a regex: `EDIT_PROMPT_RE = r'^Edit the (?:image|file) (.+?): (.+)$'`
- Chain: output of pass N = input of pass N+1
- Max chain depth: 5 (same as screenshot verification loop -- see QUALITY.md)

```python
import re
EDIT_PROMPT_RE = re.compile(r'^Edit the (?:image|file) (.+?): (.+)$')

def parse_edit_prompt(prompt: str):
    m = EDIT_PROMPT_RE.match(prompt)
    if not m:
        return None, None
    return m.group(1), m.group(2)  # filename, instruction
```

ALWAYS enforce the format -- a regex parse failure is a hard error, not a fallback. If the format is not matched, return a clear error explaining the required format. This keeps the edit chain's state machine explicit.

---

## 11. Multi-Process SQLite

Required when FastAPI + Playwright (or any two processes) share the same SQLite file:

```python
conn = sqlite3.connect(DB_PATH, timeout=30)  # ALWAYS set timeout for multi-process
conn.execute("PRAGMA journal_mode=WAL")       # WAL allows concurrent readers + 1 writer
conn.execute("PRAGMA busy_timeout=5000")      # 5s busy wait before SQLITE_BUSY error
```

| Setting | Default | Multi-Process Setting | Reason |
|---------|---------|----------------------|--------|
| `timeout` | 5s | 30s | Other process may hold lock during heavy write |
| `journal_mode` | DELETE | WAL | WAL allows N readers + 1 writer simultaneously |
| `busy_timeout` | 0ms | 5000ms | Spin-wait before raising SQLITE_BUSY |

ALWAYS apply all three when the database is shared between processes. NEVER assume a single-process SQLite config is safe in multi-process environments.

---

## 12. Architecture Decision Records (ADR)

ALWAYS create an initial ADR set before the first feature. One ADR per irreversible architectural decision.

ALWAYS write the rollback plan before writing the implementation. An irreversible ADR without a rollback plan is a trap.

### ADR Template

```markdown
# ADR-{N}: {Title}

## Context
{What technical situation prompted this decision?}

## Decision
{What was decided, in one sentence}

## Alternatives Considered
- {Option A}: {tradeoffs}
- {Option B}: {tradeoffs}

## Consequences
- {positive consequence}
- {risk or negative consequence}

## Validation Metrics
- {measurable signal that this decision is working}

## Rollback
{How to reverse this decision if it proves wrong}
```

### Initial ADR Set (Every Project -- Minimum)

| ADR | Decision Domain | Why Minimum |
|-----|----------------|-------------|
| ADR-001 | Data authority -- which store owns what | State without a single owner drifts |
| ADR-002 | Failure/degradation policy -- what degrades before what | Failure modes must be designed in, not discovered |
| ADR-003 | Tech stack selection -- stack + reason + escape hatch | Stack is the most expensive decision to reverse |

APPLY to: any decision that is expensive to reverse (tech stack, data model, auth strategy, external service lock-in, communication protocol).
SKIP for: decisions reversible with `git revert` + < 1 hour of recovery work.

---

## 13. Unix Module Gate

A formal decomposition checklist applied to any new module or subsystem. Makes the Unix principle enforceable, not just aspirational.

**ADVISORY**: Not required for single-file scripts, configuration files, or glue code. APPLY when: adding a new module/subsystem, refactoring a module that does >1 thing, or when a module is first consumed by another.

```
UNIX MODULE GATE: {module_name}
[ ] SRP: Describable in one sentence?
[ ] Interface: Typed Protocol/interface defined?
[ ] Failure Mode: Degraded behavior explicitly stated?
[ ] Layer Discipline: Imports only from layers below?
[ ] Isolation: Testable without its dependents?
[ ] Metric: At least one measurable performance indicator?
GATE RESULT: PASS / SPLIT (split if any box unchecked)
```

### Decomposition Ritual (Precedes Module Gate)

Run this before designing any new module or subsystem:

1. State the problem in one sentence
2. List minimum single-responsibility modules needed
3. Draw dependency graph (no upward arrows allowed)
4. Write Protocol/interface for each
5. Define failure mode for each
6. Apply Module Gate to each

WHEN the gate result is SPLIT, THEN decompose the module and re-run the gate on each part. NEVER integrate a module that fails the gate -- the cost of fixing it before integration is always lower than after.

---

## 14. Benchmark Harness Pattern

For any module with measurable runtime behavior (ML inference, audio/video processing, parsing, search):

```python
# Pattern: fixtures -> scenarios -> metrics -> comparisons
class BenchmarkHarness:
    def run(self, fixture: Fixture, scenario: Scenario) -> BenchmarkResult:
        """Run one scenario against one fixture, return metrics."""
        ...

    def compare(self, baseline: BenchmarkResult, candidate: BenchmarkResult) -> Delta:
        """Compare two runs. Regression if any metric degrades > threshold."""
        ...
```

ALWAYS run benchmarks against a fixed fixture set (not live data).
ALWAYS compare against a baseline before shipping.
NEVER accept a regression as "acceptable" without a documented tradeoff.
ALWAYS store benchmark results as dated artifacts -- see OPERATIONS.md §14 Runtime Artifact Collection.

| Benchmark Dimension | Threshold Policy |
|--------------------|-----------------|
| Latency (p50, p95, p99) | Regression if p95 increases > 10% |
| Throughput | Regression if decreases > 10% |
| Memory | Regression if peak increases > 20% |
| Error rate | Regression if increases by any amount |

---

## 15. Initial Architecture Brief

ALWAYS produce an architecture brief before writing the first feature. The brief generates the **option space** that the Council then evaluates. It sits between "Council decides stack" and "start coding."

ADVISORY: Required for projects with 3+ modules or algorithmic subsystems. SKIP for single-file tools or CRUD apps where the architecture is obvious.

### Brief Template

```markdown
# Architecture Brief -- {Project Name}

## 1. Engineering Restatement
{One paragraph: what we are building, in engineering terms, stripped of marketing}

## 2. Repository Structure
{Directory tree with module names and purposes}

## 3. Module-by-Module Architecture
{For each module: name, responsibility, key interfaces, dependencies}

## 4. Initial ADR Set
{List of ADR IDs with one-line decisions -- see §12}

## 5-7. Option Matrices (per algorithmic subsystem)

For each subsystem with multiple valid approaches, lay out 3 options:

| Axis | Option A | Option B | Option C |
|------|----------|----------|----------|
| Efficiency | A > B > C | | |
| Quality | C > B > A | | |
| Stability risk | A < B < C | | |
| Explainability | A >= B > C | | |

Recommended: {which option and why}
Council decides: {feed this matrix to the Council -- see TEAM.md §Council Protocol}

## 8. Degradation Policy
{Ordered list: what degrades first through last -- see ADR-002}

## 9. First Vertical Slice Plan
{Reference GENESIS.md §9 format}

## 10. Core Protocol/Type Definitions
{Where interface contracts live: file paths + protocol names}
```

### Why Option Matrices?

An ADR captures a single decision. The option matrix captures the **decision space** -- all viable approaches with their tradeoff axes. The Council evaluates the matrix; the ADR records the outcome.

NEVER present the Council with a single option. ALWAYS generate at minimum 2, ideally 3 options with explicit tradeoff axes. Options A/B/C should span the efficiency-quality spectrum, not be minor variations of the same approach.

Store the brief as `Docs/INITIAL-ARCHITECTURE-BRIEF.md` in the project root.

### Architecture Brief Versioning

The initial brief is a genesis document. Architecture evolves. WHEN the PDSA Act phase results in a major scope change (new subsystem, new pillar, fundamental architecture shift), THEN produce an updated Architecture Brief:

```
Docs/INITIAL-ARCHITECTURE-BRIEF.md        <- v1 (genesis)
Docs/ARCHITECTURE-BRIEF-V2.md             <- v2 (after first major pivot)
Docs/ARCHITECTURE-BRIEF-V3.md             <- v3 (after second major pivot)
```

Each new version MUST include:
1. What changed since the previous version and why
2. New option matrices for any new subsystems
3. Updated degradation policy
4. Updated module list and protocol definitions

NEVER modify the original brief -- it is an audit trail. The MVP Tracker's "Incongruencies" section is a signal that a new brief version is needed -- the system has grown past what the current brief designed.

-> See ITERATION.md §PDSA Cycle -- Act option 5 (Re-brief) triggers a new version.

---

## 16. Decomposition Protocol

A formal process for breaking existing projects into reusable Smallest Viable Components (SVCs), then recomposing them into new products. Where §13 (Module Gate) governs *new* modules, this protocol governs *extraction* from existing systems.

APPLY when: building a new product from 2+ existing projects, or extracting a subsystem for reuse.
SKIP when: greenfield projects with no existing code to extract from.

### Phase 1: INVENTORY

Map every module in every source project.

```
For each module:
  1. State its SRP in one sentence
  2. List its imports -- what does it depend on?
  3. Tag domain coupling:
     - foundation      -- zero domain knowledge (schedulers, stores, metrics)
     - dev-infrastructure -- knows about code/projects, not specific products
     - domain-specific -- knows about a specific product domain (audio, podcasts, portfolios)
  4. Tag portability:
     - portable -- no domain-specific imports, could move to any project
     - coupled  -- imports domain types or domain-specific modules
```

Output: a Component Map table with columns: Component | Files | SRP | Tier | Portable?

### Phase 2: EXTRACT

For each portable component targeted for reuse:

```
1. Define its Protocol/interface (contract-first -- the interface IS the component)
2. Remove all domain-specific imports
3. Replace domain types with generics or protocol constraints
4. Ensure the component passes the Unix Module Gate (§13)
5. Write 1+ tests that exercise the component in isolation (no domain fixtures)
```

NEVER extract a component that is still tightly coupled -- decouple first, extract second.
WHEN extraction requires changing the source project's behavior, THEN fork/copy, do not modify in place.

### Phase 3: TIER

Assign every SVC to exactly one tier:

| Tier | Name | Rule | Examples |
|------|------|------|----------|
| 1 | **Foundation** | Zero domain knowledge. Pure infrastructure. | WorkScheduler, TypedSQLiteStore, HealthMetrics, FeatureFlags, BackupManager |
| 2 | **Dev Infrastructure** | Knows about code/projects, not about specific products. | PortfolioScanner, ServerFleet, VerifyToolkit, PersonaEngine, NLPProvider |
| 3 | **Domain** | Knows about a specific product domain. | TranscriptPipeline, PodcastPlayback, ContentTaxonomy, ProjectDashboard |

**Tier Dependency Rule**: Tier N may import from Tier N-1 or lower. NEVER import upward. This is the layer discipline from §1 applied to component tiers.

```
Tier 3 (Domain)           -> may use Tier 2 + Tier 1
Tier 2 (Dev Infrastructure) -> may use Tier 1 only
Tier 1 (Foundation)        -> may use stdlib only
```

### Phase 4: INTEGRATE

Build the new product by composing SVCs bottom-up:

```
1. Foundation tier first -- store, scheduler, flags, metrics, backup
2. Dev infrastructure tier -- scanner, fleet, verify, persona
3. Domain tier -- transcript, playback, taxonomy
4. API + UI on top (standard 4-layer stack from §1)
```

At each integration point:
- Apply the Module Gate (§13) to the composed subsystem
- Write an ADR (§12) for each irreversible composition decision
- Define the degradation order (§5) -- which domain surfaces degrade first?

### Decomposition Checklist

```
DECOMPOSITION PROTOCOL: {source_projects} -> {target_product}

Phase 1: INVENTORY
[ ] Component Map table complete for all source projects
[ ] Every module tagged: tier (foundation/dev-infra/domain)
[ ] Every module tagged: portability (portable/coupled)

Phase 2: EXTRACT
[ ] Protocol/interface defined for each SVC (contract-first)
[ ] Domain imports removed from all portable components
[ ] Domain types replaced with generics/protocol constraints
[ ] Each SVC passes Unix Module Gate (§13)
[ ] Each SVC has isolated tests (no domain fixtures)

Phase 3: TIER
[ ] Every SVC assigned to exactly one tier
[ ] No upward tier imports (Tier 1 <- Tier 2 <- Tier 3)
[ ] Dependency graph drawn -- no upward arrows

Phase 4: INTEGRATE
[ ] Foundation tier composed and tested
[ ] Dev infrastructure tier composed and tested
[ ] Domain tier composed and tested
[ ] API + UI layers applied (4-layer stack from §1)
[ ] ADR written for each composition decision
[ ] Degradation order defined

PROTOCOL RESULT: READY / BLOCKED (blocked if any box unchecked)
```

---

## 17. Module Access Protocol (MAP)

Every module in the system MUST declare a manifest that describes what it provides, what it requires, and how it can be accessed. This is the contract that makes modules composable across projects without tight coupling.

ALWAYS declare a `module.yaml` manifest at the root of every module directory.
NEVER import a module that lacks a manifest -- the manifest IS the contract.
ALWAYS declare what capabilities a module NEEDS, not WHO provides them.

### Module Manifest (`module.yaml`)

```yaml
# module.yaml -- Module Access Protocol manifest
name: work-scheduler                    # unique kebab-case identifier
version: 1.0.0                         # semver
description: "Schedule and execute work items with priority queuing"

provides:                               # capabilities this module offers
  - capability: task-scheduling
    interface: WorkScheduler
    protocol: python-class              # python-class | http-api | grpc | cli
  - capability: priority-queuing
    interface: PriorityQueue
    protocol: python-class

requires:                               # capabilities this module needs (NOT specific modules)
  - capability: persistent-storage
    interface: KeyValueStore
    optional: false
  - capability: metrics-collection
    interface: MetricsCollector
    optional: true                      # module works without this, degraded

exports:                                # public surface area
  - path: scheduler.py
    symbols: [WorkScheduler, Task, Priority]
  - path: queue.py
    symbols: [PriorityQueue, QueueConfig]

access_modes:                           # how consumers can reach this module
  - mode: direct-import                 # Python/TS import
    entry: scheduler.py
  - mode: http-api                      # auto-generated REST endpoint
    port: auto
    routes: ["/schedule", "/status", "/cancel"]
  - mode: runtime-composition           # compose.yaml orchestration
    compose_key: work-scheduler

metadata:
  tier: 1                               # foundation / dev-infra / domain (see §16 Phase 3)
  layer: engine                          # ui / api / engine / storage (see §1)
  owner: core-team
  tags: [scheduling, infrastructure]
```

### Three Access Modes

| Mode | When to Use | Coupling | Performance |
|------|------------|----------|-------------|
| **Direct Import** | Same process, same language, tight performance needs | High (compile-time) | Fastest |
| **HTTP API** (auto-generated) | Cross-process, cross-language, or network boundary | Low (runtime) | Network latency |
| **Runtime Composition** (`compose.yaml`) | Multi-module orchestration, deployment topology | None (config-time) | Depends on mode |

#### Direct Import

```python
# Consumer declares: requires capability "task-scheduling"
# Registry resolves: work-scheduler provides it
from work_scheduler.scheduler import WorkScheduler

scheduler = WorkScheduler(store=resolved_store)
scheduler.schedule(task)
```

#### HTTP API (Auto-Generated)

WHEN a module declares `access_modes: http-api`, THEN the framework auto-generates a REST endpoint from the module's typed interface. The module author writes zero HTTP code.

```yaml
# In compose.yaml
services:
  work-scheduler:
    module: work-scheduler
    access: http-api
    port: 3010
```

The framework reads the module's `provides` interfaces, generates routes from method signatures, and serves them. Consumers call the HTTP endpoint; they never import the module directly.

#### Runtime Composition (`compose.yaml`)

```yaml
# compose.yaml -- declares which modules run and how they connect
version: 1
services:
  scheduler:
    module: work-scheduler
    access: direct-import
    provides: [task-scheduling, priority-queuing]

  storage:
    module: sqlite-store
    access: direct-import
    provides: [persistent-storage]

  metrics:
    module: prometheus-metrics
    access: http-api
    port: 9090
    provides: [metrics-collection]

bindings:
  # Resolve "requires" -> "provides" by capability name
  scheduler.persistent-storage: storage
  scheduler.metrics-collection: metrics
```

### MAP Rules

1. **Capability-based requires**: Modules declare what they NEED (capabilities), not WHO provides it. The registry or `compose.yaml` resolves bindings. This means a module that requires `persistent-storage` works with SQLite, Postgres, or any store that provides that capability.

2. **Manifest-first development**: ALWAYS write the `module.yaml` before writing the implementation. The manifest is the design document. WHEN the manifest cannot be written clearly, THEN the module's responsibility is not well-defined -- apply the Unix Module Gate (§13).

3. **No hidden dependencies**: EVERY import that crosses a module boundary MUST be declared in `requires`. NEVER import from another module without declaring the dependency. Undeclared dependencies are invisible coupling -- they break when the provider changes.

4. **Version pinning in requires**: WHEN a module depends on a specific version range of a capability, THEN declare it:
   ```yaml
   requires:
     - capability: persistent-storage
       version: ">=1.0,<2.0"
   ```

5. **Graceful degradation for optional requires**: WHEN a required capability is marked `optional: true` and is unavailable, THEN the module MUST still initialize and operate in a degraded mode. NEVER crash because an optional dependency is missing.

### MAP Validation Checklist

```
MAP VALIDATION: {module_name}
[ ] module.yaml exists at module root
[ ] name is unique across the project
[ ] Every provides entry has a typed interface
[ ] Every requires entry uses capability names, not module names
[ ] Every cross-module import is declared in requires
[ ] access_modes list is complete and accurate
[ ] Optional requires have degraded behavior defined
[ ] Version constraints specified where needed
MAP RESULT: VALID / INVALID (invalid if any box unchecked)
```

---

## 18. Cross-Project Module Registry

A shared registry that enables modules to be published from one project and consumed by another. This is the mechanism that makes the Module Access Protocol (§17) work across project boundaries.

**Location**: `/Users/mikeudem/Projects/.module-registry/`

ALWAYS publish modules through the registry before consuming them in another project.
NEVER copy module source code between projects manually -- use the registry.
ALWAYS run isolation tests before publishing.
ALWAYS version-pin consumed modules.

### Registry Structure

```
/Users/mikeudem/Projects/.module-registry/
  index.yaml                              # catalog of all published modules
  work-scheduler/
    module.yaml                           # MAP manifest (see §17)
    src/                                  # source code
      scheduler.py
      queue.py
    tests/                                # isolation tests (must pass before publish)
      test_scheduler.py
    CHANGELOG.md                          # version history
  sqlite-store/
    module.yaml
    src/
      store.py
    tests/
      test_store.py
    CHANGELOG.md
  prometheus-metrics/
    module.yaml
    src/
      metrics.py
    tests/
      test_metrics.py
    CHANGELOG.md
```

### Registry Index (`index.yaml`)

```yaml
# /Users/mikeudem/Projects/.module-registry/index.yaml
registry:
  version: 1
  updated_at: "2026-03-26T00:00:00Z"

modules:
  - name: work-scheduler
    version: 1.0.0
    tier: 1
    provides: [task-scheduling, priority-queuing]
    published_by: podbot
    published_at: "2026-03-20T00:00:00Z"
    status: stable                        # stable | beta | deprecated

  - name: sqlite-store
    version: 2.1.0
    tier: 1
    provides: [persistent-storage, key-value-store]
    published_by: module-maker
    published_at: "2026-03-22T00:00:00Z"
    status: stable

  - name: prometheus-metrics
    version: 1.2.0
    tier: 1
    provides: [metrics-collection]
    published_by: podbot
    published_at: "2026-03-18T00:00:00Z"
    status: stable
```

### Registry Operations

#### PUBLISH

Add or update a module in the registry.

```
PUBLISH PROTOCOL:
1. Ensure module has a valid module.yaml (MAP manifest -- see §17)
2. Run all isolation tests in the module's tests/ directory
3. WHEN any test fails, THEN STOP -- do not publish broken modules
4. Copy module directory to registry: /Users/mikeudem/Projects/.module-registry/{name}/
5. Update index.yaml with module metadata
6. Git commit the registry change with message: "publish: {name} v{version}"
7. Log the publish event
```

```bash
# Example publish workflow
cd /Users/mikeudem/Projects/.module-registry/
# 1. Validate manifest
cat work-scheduler/module.yaml | yq '.name, .version, .provides'
# 2. Run isolation tests
python -m pytest work-scheduler/tests/ -v
# 3. Update index
# (edit index.yaml -- add or update module entry)
# 4. Commit
git add work-scheduler/ index.yaml
git commit -m "publish: work-scheduler v1.0.0"
```

#### CONSUME

Use a module from the registry in a project.

```
CONSUME PROTOCOL:
1. Search index.yaml for a module that provides the needed capability
2. Read the module's module.yaml to understand its interface
3. Pin the version in your project's dependency declaration
4. Choose an access mode (direct-import, http-api, or compose.yaml)
5. Wire the binding in your project's compose.yaml or import statements
6. NEVER modify the consumed module's source -- fork to registry if changes needed
```

```yaml
# In consuming project's compose.yaml
dependencies:
  registry: /Users/mikeudem/Projects/.module-registry/
  modules:
    - name: work-scheduler
      version: "1.0.0"                   # pinned -- NEVER use "latest"
      access: direct-import
    - name: sqlite-store
      version: ">=2.0,<3.0"
      access: direct-import
```

#### UPDATE

Upgrade a consumed module to a new version.

```
UPDATE PROTOCOL:
1. Check index.yaml for new version availability
2. Read CHANGELOG.md for breaking changes
3. WHEN major version changed, THEN review all consuming code for compatibility
4. Update version pin in consuming project
5. Run consuming project's full test suite
6. WHEN tests fail, THEN fix consuming code or roll back version pin
7. Commit with message: "update: {name} v{old} -> v{new}"
```

#### AUDIT

Verify registry health and detect drift.

```
AUDIT PROTOCOL (run monthly or before major releases):
1. For each module in index.yaml:
   a. Verify module directory exists
   b. Verify module.yaml matches index.yaml metadata
   c. Run isolation tests -- flag any failures
   d. Check for unused modules (not consumed by any project)
   e. Check for version drift (consumed version != latest published)
2. Output: Audit Report table

| Module | Published | Consumed By | Latest | Pinned At | Tests | Status |
|--------|-----------|-------------|--------|-----------|-------|--------|
| {name} | {date} | {projects} | {ver} | {ver} | pass/fail | ok/drift/unused |
```

### Registry Rules

1. **Every module needs a MAP manifest**: A module without `module.yaml` cannot be published. The manifest is the contract -- see §17.

2. **Isolation tests before publish**: NEVER publish a module whose tests fail. Tests must run without any external project context -- they validate the module in isolation.

3. **Version pinning**: Consuming projects MUST pin to a specific version or a constrained range. NEVER use "latest" or unbounded ranges. Version drift is silent coupling.

4. **Git-tracked**: The entire registry directory is a git repository. Every publish, update, and audit is a git commit. This provides full traceability of what was available when.

5. **No circular dependencies**: WHEN module A requires a capability that module B provides, AND module B requires a capability that module A provides, THEN one of them must be split. Apply the Unix Module Gate (§13) to find the right decomposition.

---

## 19. Graceful Degradation Model

Every feature that depends on an external resource (API, network, hardware sensor, third-party service, model endpoint) MUST define an explicit degradation chain. This is not optional error handling -- it is a design requirement.

ALWAYS define the full degradation chain before writing the implementation.
NEVER let a feature crash because a dependency is unavailable.
ALWAYS preserve user-facing continuity -- the user must always see something useful.
ALWAYS make degradation triggers measurable and observable.

### Degradation Chain

Every feature with external dependencies MUST define exactly five states:

```
Full -> Reduced -> Minimal -> Off -> Fallback
```

| State | Definition | User Experience |
|-------|-----------|-----------------|
| **Full** | All dependencies available, all features active | Complete functionality, real-time data, full fidelity |
| **Reduced** | Primary dependency available, secondary degraded | Core feature works, some enrichment missing, user notified |
| **Minimal** | Primary dependency degraded or slow | Basic output only, cached/stale data acceptable, clear notice |
| **Off** | Primary dependency unavailable | Feature hidden from UI, no broken buttons, no error screens |
| **Fallback** | Extended outage or permanent loss | Alternative workflow offered, data preserved, recovery path clear |

### Hard Constraint: User-Facing Continuity

The user MUST always see something useful. NEVER show a blank screen, a spinner that never resolves, or an error message without an action path.

```
CONTINUITY RULE:
  WHEN state = Full    -> show full output
  WHEN state = Reduced -> show partial output + "[some data unavailable]" notice
  WHEN state = Minimal -> show cached/basic output + "[operating in limited mode]" notice
  WHEN state = Off     -> hide the feature entirely, show remaining features
  WHEN state = Fallback -> offer alternative workflow + "[service unavailable, try X]" prompt
```

### Measurable Triggers

Each state transition MUST be triggered by a measurable, observable condition. NEVER use subjective or untestable triggers.

| Trigger Type | Metric | Example Threshold |
|-------------|--------|-------------------|
| CPU load | `cpu_percent` | Full -> Reduced at > 80% sustained 30s |
| Thermal state | `thermal_state` | Full -> Reduced at thermal_state >= 2 |
| API latency | `response_time_p95` | Full -> Reduced at p95 > 2s; Reduced -> Minimal at p95 > 5s |
| API error rate | `error_rate_5m` | Full -> Reduced at > 5%; Reduced -> Minimal at > 25% |
| API availability | `consecutive_failures` | Minimal -> Off at 3 consecutive failures |
| Memory pressure | `memory_percent` | Full -> Reduced at > 85% |
| Network quality | `bandwidth_mbps` | Full -> Reduced at < 1 Mbps; Reduced -> Minimal at < 0.1 Mbps |
| Disk space | `disk_free_percent` | Full -> Reduced at < 10%; Reduced -> Minimal at < 5% |

### Degradation Chain Template

ALWAYS fill out this template for every feature with external dependencies:

```markdown
## Degradation Chain: {Feature Name}

### Dependencies
| Dependency | Type | Critical? | Health Check |
|-----------|------|-----------|-------------|
| {dep} | API/network/hardware/model | yes/no | {how to check} |

### States
| State | Active Dependencies | User Sees | Trigger (enter) | Trigger (exit) |
|-------|-------------------|-----------|-----------------|----------------|
| Full | all | {description} | all healthy | -- |
| Reduced | {which} | {description} | {measurable condition} | {recovery condition} |
| Minimal | {which} | {description} | {measurable condition} | {recovery condition} |
| Off | none | feature hidden | {measurable condition} | {recovery condition} |
| Fallback | none | {alternative} | extended outage > {time} | manual re-enable |

### Recovery
- Auto-recovery: WHEN trigger condition clears for > {duration}, THEN promote state
- Manual recovery: {what operator does}
- Data preservation: {what is cached/saved during degradation}

### ADR Reference
ADR-{N}: Degradation policy for {Feature Name}
```

### Example: Podcast Transcript Feature

```
Degradation Chain: Podcast Transcript

Full:
  - Whisper API available, GPU available, network stable
  - User sees: real-time transcription with speaker diarization

Reduced:
  - Trigger: Whisper API latency p95 > 3s OR GPU thermal_state >= 2
  - User sees: transcription with 10s delay, no speaker diarization
  - Notice: "[transcription delayed -- running in reduced mode]"

Minimal:
  - Trigger: Whisper API error_rate > 25% OR consecutive_failures >= 2
  - User sees: pre-cached transcript if available, otherwise "processing" indicator
  - Notice: "[transcript temporarily unavailable -- showing cached version]"

Off:
  - Trigger: Whisper API consecutive_failures >= 3
  - User sees: transcript tab hidden, other features remain
  - No broken UI elements

Fallback:
  - Trigger: Whisper API down > 30 minutes
  - User sees: "Upload audio for manual transcription" prompt
  - Data: audio file preserved for later processing
  - Recovery: batch-process queued audio when API returns
```

### Each Step is an ADR Decision

WHEN defining a degradation chain for a critical feature, THEN the degradation policy MUST be recorded as an ADR (see §12). The ADR captures:
- Why these specific thresholds were chosen
- What alternatives were considered (e.g., aggressive degradation vs. tolerant)
- How to adjust thresholds if they prove wrong

ALWAYS prefer conservative thresholds (degrade early) over optimistic ones (degrade late). A feature that degrades gracefully under light pressure is better than one that works perfectly until it crashes.

---

## 20. Two-Phase Processing Pattern

For any operation where the user expects immediate feedback but full processing takes significant time. This pattern ensures the user is never waiting without output.

ALWAYS provide Phase 1 output within 3 seconds of user action.
NEVER make the user stare at a spinner for more than 3 seconds without useful content.
ALWAYS replace Phase 1 output with Phase 2 output when ready -- seamlessly, without page reload.
NEVER discard Phase 1 output if Phase 2 fails -- Phase 1 is the safety net.

### Pattern Structure

```
User Action
    |
    v
Phase 1 (Quick): minimum viable output (<3s)
    |
    |--- display Phase 1 immediately
    |
    v
Phase 2 (Deferred): full analysis in background
    |
    |--- WHEN complete, replace Phase 1 with Phase 2 output
    |--- WHEN failed, keep Phase 1 output + log error
```

### Phase 1: Quick Response

Phase 1 produces the minimum viable output that is useful to the user. It prioritizes speed over completeness.

| What Phase 1 Does | What Phase 1 Skips |
|-------------------|--------------------|
| Parse the input | Deep analysis |
| Apply heuristics or cached results | Model inference |
| Return structured skeleton | Enrichment from external APIs |
| Show partial data immediately | Cross-referencing with other data |

**Hard constraint**: Phase 1 MUST complete in under 3 seconds. WHEN Phase 1 cannot complete in 3 seconds, THEN the operation is too complex for Phase 1 -- simplify the Phase 1 scope.

### Phase 2: Deferred Processing

Phase 2 runs in the background after Phase 1 is displayed. It performs the full computation and replaces Phase 1's output when ready.

```python
# Pattern implementation
import asyncio
from typing import TypeVar, Generic, Callable, Awaitable

T = TypeVar('T')

class TwoPhaseProcessor(Generic[T]):
    """
    Phase 1: quick result displayed immediately.
    Phase 2: full result replaces Phase 1 when ready.
    """

    async def process(
        self,
        input_data: any,
        quick_fn: Callable[[any], T],
        full_fn: Callable[[any], Awaitable[T]],
        on_phase1: Callable[[T], None],
        on_phase2: Callable[[T], None],
        on_phase2_error: Callable[[Exception], None],
    ) -> None:
        # Phase 1: synchronous, fast
        phase1_result = quick_fn(input_data)
        on_phase1(phase1_result)

        # Phase 2: asynchronous, thorough
        try:
            phase2_result = await full_fn(input_data)
            on_phase2(phase2_result)
        except Exception as e:
            on_phase2_error(e)
            # Phase 1 result remains displayed -- user is not left with nothing
```

### Replacement Rules

| Phase 2 Outcome | Action |
|-----------------|--------|
| Succeeds, better than Phase 1 | Replace Phase 1 output with Phase 2 output |
| Succeeds, same as Phase 1 | No visual change -- user sees no flicker |
| Fails with recoverable error | Keep Phase 1 output, log error, retry once |
| Fails with permanent error | Keep Phase 1 output, log error, mark feature as Reduced (see §19) |
| Times out | Keep Phase 1 output, log timeout, show "[full analysis unavailable]" |

### UI Integration

ALWAYS indicate when Phase 1 is displayed and Phase 2 is pending:

```
Phase 1 visible:  "[Quick analysis] ..."        (subtle indicator)
Phase 2 pending:  "[Analyzing...] ..."           (progress shown)
Phase 2 complete: content replaces silently       (no indicator needed)
Phase 2 failed:   "[Quick analysis] ..."         (indicator persists, tooltip explains)
```

NEVER show a jarring transition between Phase 1 and Phase 2. The replacement MUST be smooth -- ideally the user does not notice the swap, only that the content became richer.

### Example: Search Results

```
User types query and hits Enter.

Phase 1 (< 1s):
  - Search local index
  - Return top 10 results by keyword match
  - Display immediately with title, snippet, score

Phase 2 (5-15s):
  - Run semantic search via embedding model
  - Re-rank results by relevance
  - Enrich with metadata from external APIs
  - Replace result list when ready
  - If Phase 2 fails: keyword results remain, user sees "[semantic ranking unavailable]"
```

### Example: Document Summary

```
User opens a long document.

Phase 1 (< 2s):
  - Extract first paragraph + section headings
  - Display as "Quick Summary" with document outline

Phase 2 (10-30s):
  - Run LLM summarization on full document
  - Generate key points, action items, sentiment
  - Replace "Quick Summary" with "Full Analysis" when ready
  - If Phase 2 fails: section headings remain, user sees "[full summary processing]"
```

### Two-Phase Checklist

```
TWO-PHASE PROCESSING: {operation_name}

Phase 1 (Quick):
[ ] Completes in < 3 seconds
[ ] Output is useful (not just a placeholder)
[ ] No external API calls required
[ ] Displayed immediately to user

Phase 2 (Deferred):
[ ] Runs in background after Phase 1 displayed
[ ] Replaces Phase 1 output seamlessly when ready
[ ] Phase 1 preserved if Phase 2 fails
[ ] Timeout defined (default: 30s)
[ ] Error logged and degradation state updated (see §19)

PATTERN RESULT: READY / BLOCKED (blocked if any box unchecked)
```

---

## Architecture Checklist

```
[ ] CLAUDE.md exists with all required sections
[ ] 4-layer pattern enforced (UI -> API -> Engine -> Storage)
[ ] No upward dependencies
[ ] Single source of truth per state
[ ] Feature registry if 3+ toggleable features
[ ] Schemas self-heal on startup
[ ] Optional deps degrade gracefully
[ ] File org matches complexity
[ ] State strategy documented
[ ] Env vars documented with defaults
[ ] Feature-module dep matrix maintained
[ ] AI model fallback chains defined
[ ] Monthly dep health check scheduled
[ ] Initial ADR set created (ADR-001, ADR-002, ADR-003)
[ ] Unix Module Gate passed for each new module
[ ] Benchmark harness defined for performance-critical modules
[ ] Initial Architecture Brief produced (if applicable)
[ ] Decomposition Protocol completed (if building from existing projects)
[ ] MAP manifest (module.yaml) exists for every module
[ ] Cross-Project Module Registry updated for published modules
[ ] Graceful Degradation Chain defined for every feature with external deps
[ ] Two-Phase Processing applied where user expects immediate feedback
```

---

## Related Directives

- -> See PHILOSOPHY.md -- kaizen-deming-unix-AI-native-parallel principles enforced structurally
- -> See GENESIS.md -- bootstrap sequence establishing initial architecture
- -> See GENESIS.md §§ Tech Stack Decision Matrix -- opinionated stack defaults
- -> See TEAM.md §Council Protocol -- council sessions for major decisions
- -> See QUALITY.md -- quality gates per lifecycle stage
- -> See ITERATION.md -- pass-based feature implementation
- -> See OPERATIONS.md -- runtime artifact collection and operational patterns

---

## Framework Navigation

> **You Are Here:** `ARCHITECTURE.md` — Structure, MAP manifests, module gate, dependency management
> **Core Method:** Kaizen · Deming · Unix · AI-Native · Parallel → PHILOSOPHY.md

| File | When To Read |
|------|-------------|
| CLAUDE.md | Session start, operating mode routing, unbreakable rules |
| PHILOSOPHY.md | Principle check, five-lens test, enforcement rules |
| GENESIS.md | New project kickoff, requirements interview, probe/bootstrap |
| TEAM.md | AI model selection, Council decisions, persona profiles |
| ARCHITECTURE.md | ★ You are here |
| ITERATION.md | Pass loop, swim lanes, circle detection, session handoff |
| QUALITY.md | Gate verification G0-G9, completion loop, testing |
| DESIGN.md | Visual identity, design gates, component system |
| HANDHOLDING.md | Newcomer guidance, glossary, preemptive help |
| OPERATIONS.md | Dev environment, dashboard, MVP tracker, reporting |
| CHARACTER-TRACKING.md | Team performance, calibration, persona metrics |

> **If lost:** Start at CLAUDE.md. If a concept is unclear, check HANDHOLDING.md §9 Glossary.
> **If stuck:** ITERATION.md §7 Failure Gates (1-fail retry, 2-fail pivot, 3-fail Council).
> **If quality uncertain:** QUALITY.md §1 Gate Runner. If design: DESIGN.md §5 Design Gates.
