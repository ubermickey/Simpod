# GENESIS.md -- Simpod Project Kickoff Ritual

## Simpod Pre-Context (read before interview)
> **Project:** Simpod — reliable, fast podcast player
> **Core goals:** rock-solid playback, fast startup, offline support, clean Unix-style architecture
> **Method:** kaizen-deming-Unix — measure before adding, small sharp composable modules
> Use this context to inform the requirements interview below. Skip questions already answered.

---

> **Kaizen (改善)** -- perfection is a direction; measure, improve, measure again.
> **Unix** -- each tool does one thing; compose small sharp tools via clean interfaces.
> **Deming** -- design quality in; measure systems not events; eliminate variation through process.
> **AI-Native** -- design for AI participation from day 0; lock invariants explicitly.
> **Parallel** -- decompose into independent lanes; maximize concurrency; serial-when-parallel is waste.
> NEVER skip steps. ALWAYS follow the order. ALWAYS hit every checkbox by end of day 1.

> **Persona Ownership:** Aria (THINK) leads the entire kickoff — interview, probe, bootstrap, first Council. Marcus implements the first vertical slice. → See CHARACTER-TRACKING.md

---

## 0. Deep Requirements Interview (before anything else)

ALWAYS run the deep requirements interview BEFORE the 60-Second Probe. The probe tests the RIGHT risk only if requirements are clear.

> Run the Interview Protocol (Strategic + Tactical layers) defined in this section.
> Output: Requirements Brief (Section 0.3).

The Requirements Brief feeds into:
- Section 1 Probe Target -- which technical risk to test
- Section 2 Research Scope -- what to research and what prior art exists
- Section 5 Tech Stack -- informed by tactical preferences and constraints
- Section 6 Council Agenda -- decisions for Council Session #1
- Section 9.5 Swim Lane Planning -- parallel decomposition of features
- Section 10 Module Contracts -- provides/requires for each major module
- TEAM.md Section 8 Team Assembly -- which team members and Council seats to assign

NEVER skip this step for new projects. Even an abbreviated interview (7 questions) produces a better probe target than guessing.

WHEN continuing an existing project (not new), THEN skip the interview -- the Requirements Brief already exists. Re-read it instead.

### 0.1 Strategic Layer

The strategic layer establishes vision, problem space, and success criteria. These questions shape WHAT we build.

```
STRATEGIC INTERVIEW QUESTIONS

S1. VISION
    "In one sentence, what does this project do for its user?"
    -> Forces clarity. If the answer is two sentences, the scope is unclear.

S2. PROBLEM SPACE
    "What specific pain point or opportunity triggered this project?"
    -> Distinguishes real problems from interesting ideas.

S3. TARGET USER
    "Who is the primary user? Describe their context, not demographics."
    -> "A developer debugging at 2am" beats "males 25-35."

S6. SUCCESS DEFINITION
    "How will you know this project succeeded? Name one measurable signal."
    -> Fisher-style: one metric, not five. "Daily active users > 10" beats "people love it."

S7. ANTI-GOALS
    "What will this project explicitly NOT do? Name 2-3 things you will refuse to add."
    -> Anti-goals are as important as goals. They prevent scope creep (Circle Type 3).

S8. TIME HORIZON
    "Is this a weekend hack, a month-long build, or a long-term product?"
    -> Determines architecture depth, testing investment, and framework ceremony level.

S10. RISK APPETITE
    "Are you exploring (fail fast, learn) or building (ship reliable, iterate)?"
    -> Exploring = minimal ceremony, spike-heavy. Building = full PDSA, ADRs, quality gates.
```

#### Optional Strategic Questions

These questions add depth for month+ builds and enterprise projects. SKIP for weekend hacks unless the answers are already known.

```
OPTIONAL STRATEGIC QUESTIONS

S4. EXISTING SOLUTIONS
    "What do people use today instead? Why is that insufficient?"
    -> If the answer is "nothing," probe harder -- there is always a workaround.

S5. COMPETITIVE LANDSCAPE
    "Name 1-3 existing tools/products that overlap. What would you steal from each? What would you reject?"
    -> Prevents reinventing wheels. Feeds into GENESIS.md Section 2 Research Phase.

S9. PORTFOLIO CONTEXT
    "Does this project relate to any of your other active projects? Does it share users, data, or components?"
    -> Feeds into cross-project learning and decomposition protocol (ARCHITECTURE.md Section 16).
```

### 0.2 Tactical Layer

The tactical layer establishes constraints, preferences, and the build plan. These questions shape HOW we build.

```
TACTICAL INTERVIEW QUESTIONS

T1. CORE FLOW
    "Walk me through the #1 user action, step by step. What does the user see, click, and get?"
    -> This becomes the first vertical slice (GENESIS.md Section 9).

T2. USER STORIES (top 3)
    "Give me the top 3 things a user needs to do, in priority order."
    -> Only 3. More = scope creep. These become the feature backlog and feed Pillar Definition (Section 11).

T3. DATA MODEL
    "What are the core entities? What are their relationships?"
    -> Sketch, not schema. Feeds ADR-001 (data authority).

T4. TECH PREFERENCES
    "Any strong preferences on language, framework, or infrastructure?"
    -> If none, use GENESIS.md Section 5 Tech Stack Decision Matrix defaults.

T5. CONSTRAINTS
    "Any hard constraints? (Budget, platform, accessibility, compliance, offline support)"
    -> Hard constraints override preferences. Feed into Council agenda.

T6. INTEGRATION POINTS
    "Does this project talk to external APIs, databases, or services?"
    -> Each integration point is a risk. Feeds into the 60-Second Probe target.

T7. UI REQUIREMENTS
    "Does this project have a visual UI? If yes: web, mobile, desktop, or CLI?"
    -> Determines whether DESIGN.md applies and Visual QA team member is needed.

T8. AUTHENTICATION & AUTHORIZATION
    "Who can access what? Single user? Multi-user with roles?"
    -> Feeds ADR-003 and Council Session #1.

T9. DEPLOYMENT TARGET
    "Where does this run? Local only, single VPS, cloud, or zero-ops?"
    -> Feeds OPERATIONS.md and tech stack decision.

T10. TIMELINE & MILESTONES
    "What does 'done enough to use' look like? When do you want to reach that point?"
    -> Defines the MVP boundary. Everything beyond it is post-MVP backlog.
```

### 0.3 Requirements Brief Output

The interview produces a structured Requirements Brief that feeds all downstream steps.

```markdown
# Requirements Brief -- {Project Name}

## Strategic Summary
- **Vision**: {S1 answer -- one sentence}
- **Problem**: {S2 answer}
- **User**: {S3 answer}
- **Success metric**: {S6 answer}
- **Anti-goals**: {S7 answers}
- **Time horizon**: {S8 answer}
- **Risk appetite**: {S10 answer -- exploring or building}

## Competitive Analysis (optional -- included for month+ builds)
- **Existing solutions**: {S4 + S5 answers}
- **Steal from**: {what to borrow}
- **Reject from**: {what to avoid}

## Tactical Plan
- **Core flow**: {T1 answer -- step by step}
- **Top 3 stories**: {T2 answers}
- **Core entities**: {T3 answer}
- **Tech preferences**: {T4 answer}
- **Hard constraints**: {T5 answers}
- **Integration points**: {T6 answers}
- **UI type**: {T7 answer}
- **Auth model**: {T8 answer}
- **Deploy target**: {T9 answer}
- **MVP definition**: {T10 answer}

## Probe Target (feeds GENESIS.md Section 1)
The #1 technical risk to probe: {derived from T6 integration points + S2 problem space}

## Council Agenda (feeds GENESIS.md Section 6)
Decisions for Council Session #1:
1. {tech stack -- informed by T4 + T5}
2. {data model -- informed by T3}
3. {auth strategy -- informed by T8}

## Team Composition (feeds TEAM.md Section 8)
- Visual QA needed? {yes/no based on T7}
- Research Scientist needed? {yes/no based on S5 competitive landscape}
- Council seats: {2 project-specific seats based on T5 constraints + S3 user context}

## Pillar Mapping (feeds GENESIS.md Section 11)
- Pillar 1: {T2 story #1} -- Backend: {tbd} | UI: {tbd} | Overall: {tbd}
- Pillar 2: {T2 story #2} -- Backend: {tbd} | UI: {tbd} | Overall: {tbd}
- Pillar 3: {T2 story #3} -- Backend: {tbd} | UI: {tbd} | Overall: {tbd}

## Portfolio Links (optional -- included when S9 answered)
- Related projects: {S9 answer}
- Shared components: {any from ARCHITECTURE.md Section 16 decomposition}
```

### 0.4 Interview Adaptation Rules

Not every project needs the full 20-question interview. The abbreviated mode is the DEFAULT for weekend hacks.

| Project Type | Interview Mode | Questions | Skip |
|-------------|---------------|-----------|------|
| Weekend hack / exploration | **Abbreviated (DEFAULT)** | S1, S2, S6, S10, T1, T4, T7 (7 questions) | Everything else |
| Month-long build | Full | S1-S3, S6-S8, S10, T1-T10 (14 questions) | S4, S5, S9 unless volunteered |
| Enterprise / long-term product | Complete | All 20 questions (S1-S10, T1-T10) | Nothing |
| Continuation of existing project | Re-evaluate | S6 (re-evaluate success), T2 (re-prioritize stories) | Rest inherited from original brief |
| Component extraction | Targeted | S9 (portfolio context), T3 (data model), T6 (integration points) | Strategic layer mostly skipped |

WHEN the user signals impatience during the interview, THEN compress remaining questions into groups of 2-3. NEVER skip the interview entirely -- even 3 questions produce a better outcome than zero.

WHEN the time horizon (S8) is "weekend hack" and no explicit mode is requested, THEN use the 7-question abbreviated mode. Do not ask whether to abbreviate -- just do it.

WHEN the time horizon (S8) is "month-long build," THEN use the 14-question full mode. Include optional strategic questions only if the user volunteers the information or asks to go deeper.

WHEN the time horizon (S8) is "long-term product" or "enterprise," THEN use the complete 20-question mode. Every question matters at this scale.

---

## 1. 60-Second Capability Probe

ALWAYS identify the core technical risk before investing hours.
ALWAYS write the simplest test: one file, <50 lines, <60 seconds.
NEVER add frameworks, architecture, or design to the probe.
WHEN the probe fails after 3 attempts, THEN pivot or kill.

```
1. IDENTIFY the one thing that kills the project if it fails.
2. WRITE a single-file test that validates only that assumption.
3. RUN IT.  Pass -> Section 2.  Fail (fixable) -> re-probe, max 3.  Fail (fundamental) -> kill.
```

### Probe Template (Python)

```python
#!/usr/bin/env python3
"""60-Second Capability Probe: {project_name}
Core risk: {one_sentence_description_of_risk}
"""
import sys, time
start = time.time()
try:
    # Step 1: minimal setup  # Step 2: risky operation  # Step 3: validate
    assert {condition}, f"Expected {expected}, got {actual}"
    print(f"PROBE PASSED in {time.time()-start:.1f}s"); sys.exit(0)
except Exception as e:
    print(f"PROBE FAILED in {time.time()-start:.1f}s -- {e}"); sys.exit(1)
```

### Probe Template (JavaScript)

```javascript
#!/usr/bin/env node
const start = Date.now();
async function probe() {
  // Step 1: minimal setup  // Step 2: risky operation  // Step 3: validate
  if (!condition) throw new Error(`Expected ${expected}, got ${actual}`);
}
probe()
  .then(() => { console.log(`PROBE PASSED in ${((Date.now()-start)/1000).toFixed(1)}s`); process.exit(0); })
  .catch((e) => { console.log(`PROBE FAILED -- ${e.message}`); process.exit(1); });
```

---

## 2. 15-Minute Research Phase

ALWAYS survey before writing production code. NEVER reinvent wheels.
-> See ARCHITECTURE.md Section Dependency Management for per-ecosystem rules.

| # | Step | Action | Time |
|---|------|--------|------|
| 1 | Prior art | Search GitHub/PyPI/npm/crates.io; read top 3 READMEs | 5 min |
| 2 | Dep audit | Updated <6mo? >1K stars? License OK? CVEs clean? | 4 min |
| 3 | API eval | Free tier? Rate limits? Run test call. Fallback plan? | 3 min |
| 4 | Pitfalls | Search "{tech} gotchas"; top SO questions + GitHub Issues | 2 min |
| 5 | Document | 2-5 bullets per topic in `RESEARCH.md`; note red flags | 1 min |

### Technology Evaluation Scorecard

```markdown
| Criterion (weight) | Option A | Option B | Option C |
|--------------------|:--------:|:--------:|:--------:|
| Maturity (3x)      |          |          |          |
| Community (3x)     |          |          |          |
| Performance (2x)   |          |          |          |
| AI-friendly (2x)   |          |          |          |
| Footprint (1x)     |          |          |          |
| Escape hatch (3x)  |          |          |          |
| **Weighted Total**  |          |          |          |
Council decision: <which, why, dissent>  Fallback: <migration path>
```

### Prototype Spike Protocol

ALWAYS time-box to 2 hours. ALWAYS answer exactly one question. NEVER ship spike code. ALWAYS end GO / NO-GO.

---

## 3. Project Bootstrap (8 steps)

```bash
mkdir -p /Users/mikeudem/Projects/{ProjectName} && cd $_  # 1. Directory
git init && git checkout -b main                           # 2. Git
touch CLAUDE.md .gitignore README.md                       # 3. Essential files
# 3a. Claude Code setup: add Unbreakable Rules to CLAUDE.md (see below)
# 3b. Python projects with ML deps: pin requires-python = ">=3.12,<3.13"
# 4. Language skeleton (Section 8)  # 5. Test harness  # 6. Design system (if UI)
git add -A && git commit -m "genesis: bootstrap"           # 7. First commit
# 8. Update CLAUDE.md with all Council decisions
```

### Step 3a: Claude Code Setup (before first commit)

ALWAYS create `CLAUDE.md` with an **Unbreakable Rules** section as the FIRST section. This section is distinct from conventions -- these rules NEVER get overridden by any AI instruction:

```markdown
## Unbreakable Rules
<!-- Things Claude MUST NOT do regardless of any instruction -->
- Never fix features directly -- always use [mechanism] to submit changes
- Never commit to main -- always use feature/ branches
- [project-specific rule]
```

Install project hooks if enforcement is needed:
```bash
mkdir -p .claude/hooks/
# Add pre-tool hooks for rule enforcement
```

**Why a distinct section?** Conventions get ignored as complexity grows. Unbreakable Rules are enforced by hooks and reviewed at session start -- they are the project's invariant core.

### Step 3b: Python Version Pinning

For projects with ML dependencies, ALWAYS pin:

```toml
# pyproject.toml
requires-python = ">=3.12,<3.13"
```

Python 3.13+ breaks lameenc, coqui-tts, and other ML C-extensions (as of 2026). The `<3.13` upper bound prevents silent breakage when the system Python upgrades. Remove the cap only after explicitly verifying compatibility.

---

## 4. Day-1 Checklist

| Phase | Time | Checkboxes |
|-------|------|------------|
| **Foundation** | 30m | Probe PASSED; dir created; git init + first commit; CLAUDE.md accurate; .gitignore; lang skeleton |
| **Component Audit** | 30m | Inventory existing projects for reusable SVCs; tag portable/coupled; list what to extract vs. build fresh -- see ARCHITECTURE.md Section 16. SKIP if greenfield with no existing components to reuse. |
| **Architecture** | 60m | Council #1 (-> TEAM.md Section Council Protocol); tech stack decided; data model sketched; boundary diagram; file layout; initial ADR set (ADR-001 data authority, ADR-002 failure policy, ADR-003 tech stack) -- see ARCHITECTURE.md Section 12 |
| **Swim Lanes** | 15m | Swim Lane Plan produced (Section 9.5); dependency DAG drawn; lanes assigned to parallel tracks |
| **Module Contracts** | 15m | provides/requires defined for each major module (Section 10); contracts recorded in CLAUDE.md |
| **Pillar Definition** | 15m | Top 3 user stories mapped to pillars with Backend/UI/Overall columns (Section 11) |
| **Testing** | 30m | Framework installed; 1+ smoke test passing; test cmd in CLAUDE.md; headless, no manual steps |
| **Team** | 15m | Composition decided (-> TEAM.md); 2 project-specific Council seats; recorded in CLAUDE.md |
| **First Feature** | rest | Core flow identified; feature implemented; feature tested; works end-to-end |

**Success criteria**: User performs core action. 1+ test proves it. CLAUDE.md accurate. Council blessed architecture. Swim lanes defined. Module contracts recorded.

```
 0:00-0:05  Probe          0:05-0:15  Bootstrap       0:15-0:30  Research
 0:30-1:00  Component Audit (if reusing existing projects -- skip if greenfield)
 1:00-2:00  Council #1     2:00-2:15  Swim Lanes      2:15-2:30  Module Contracts
 2:30-2:45  Pillar Def     2:45-3:15  Test harness    3:15-3:30  Team
 3:30-5:00  First feature  5:00-5:30  Tests           5:30-6:00  Docs + commit
```

---

## 5. Tech Stack Decision Matrix

ALWAYS use these defaults. Override ONLY with Council input.

| Category | Condition | Use | Default |
|----------|-----------|-----|---------|
| **Frontend** | file:// access | Vanilla JS | **Vanilla JS unless state mgmt needed** |
| | Complex state | React + Vite + TS | |
| | Simple dashboard | HTMX + templates | |
| **Backend** | Python ML libs | FastAPI | **FastAPI (AI lingua franca)** |
| | Max performance | Rust + Axum | |
| | Rapid prototype | Express / Fastify | |
| **Database** | Single-user | SQLite | **SQLite local, PostgreSQL multi-user** |
| | Multi-user | PostgreSQL | |
| | Documents | PostgreSQL + JSONB | |
| **Auth** | Single-user | None / basic token | **Sessions for web, JWT for APIs** |
| | Web + API | Hybrid sessions + JWT | |
| **Deploy** | Personal tool | Run locally | **Single VPS** |
| | Web app | Single VPS | |
| | Zero-ops | Vercel + Railway | |

---

## 6. First Council Session

ALWAYS bring enumerable options. NEVER ask open-ended questions. -> See TEAM.md Section Council Protocol

```markdown
## Council Session #1: Architecture
- **Name**: {project}  **Description**: {what}  **User**: {who}
- **Core flow**: {step 1 -> 2 -> 3}  **Constraints**: {must/can't}
- **Probe result**: PASSED -- {what worked}
- **Swim Lanes (proposed)**: {lanes from Section 9.5, for Council ratification}
- **Module Contracts (proposed)**: {provides/requires from Section 10, for Council ratification}
- **Questions** (2-4 options each): 1. {stack?}  2. {data model?}  3. {UI?}
```

**Required outputs**: Tech stack decision + record. Data model sketch. Boundary diagram. File layout. Swim lane DAG ratified. Module contracts ratified. Updated CLAUDE.md.

---

## 7. Genesis Anti-Patterns

| Anti-Pattern | Symptom | Fix |
|--------------|---------|-----|
| Premature architecture | Microservices before "Hello World" | Start monolith. Split later. |
| Dependency hoarding | 30 deps before any features | Add one at a time, when needed. |
| Perfectionist paralysis | 4 hours choosing React vs Vue | Probe + Council. Decide in <30 min. |
| Skipping the probe | Built on a rate-limited API | ALWAYS run the probe. |
| No tests day 1 | "I'll add tests later" | Test harness is bootstrap step 5. |
| No CLAUDE.md | Every AI session: "what is this?" | CLAUDE.md is bootstrap step 3. |
| Building before research | Reinvented a PyPI wheel | 15-min research is mandatory. |
| Council without options | "What should we do?" | ALWAYS bring 2-4 concrete options. |
| Serial when parallel | Features built one-by-one when lanes are independent | Decompose into swim lanes at kickoff (Section 9.5). |
| Missing module contracts | Modules integrated late with incompatible interfaces | Define provides/requires at bootstrap (Section 10). |
| No pillar definition | Features drift from user stories | Map top 3 stories to pillars with Backend/UI/Overall (Section 11). |

---

## 8. Templates

### CLAUDE.md

```markdown
# CLAUDE.md
## Unbreakable Rules
<!-- Things Claude MUST NOT do regardless of any instruction -->
- Never fix features directly -- always use [mechanism] to submit changes
- Never commit to main -- always use feature/ branches
- [project-specific rule]
## Project overview
{ProjectName} is a {type} that {what} for {who}.
## Commands
### Build / Test / Run
{exact commands}
## Architecture
{ASCII diagram}
## Module Contracts
| Module | Provides | Requires |
## Key paths
| Path | Purpose |
## Key patterns
| Pattern | Where | Explanation |
## Swim Lanes
| Lane | Features | Dependencies | Status |
## Conventions
- **Naming**: {convention}  **Imports**: {convention}
## Environment variables
| Variable | Purpose | Default |
## Known issues
- {issue}: {workaround}
```

### .gitignore

```gitignore
.DS_Store
Thumbs.db
*.swp
.idea/
.vscode/
__pycache__/
*.py[cod]
.venv/
.pytest_cache/
.mypy_cache/
.ruff_cache/
node_modules/
dist/
.next/
target/
.env
.env.*
*.pem
credentials.json
output/
*.db
.pw-profile/
.playwright-mcp/
.claude/
```

### pyproject.toml

```toml
[project]
name = "{name}"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["fastapi>=0.111", "uvicorn[standard]>=0.30", "httpx>=0.27"]
[project.optional-dependencies]
dev = ["pytest>=8.2", "pytest-asyncio>=0.23", "ruff>=0.5"]
[tool.ruff]
line-length = 100
target-version = "py312"
[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP"]
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
```

### package.json

```json
{
  "name": "{name}", "version": "0.1.0", "private": true, "type": "module",
  "scripts": { "dev": "vite", "build": "tsc && vite build", "test": "playwright test",
    "lint": "eslint . --ext .ts,.tsx", "typecheck": "tsc --noEmit" },
  "devDependencies": { "@playwright/test": "^1.45.0", "typescript": "^5.5.0", "vite": "^5.3.0" }
}
```

### Cargo.toml

```toml
[package]
name = "{name}"
version = "0.1.0"
edition = "2021"
rust-version = "1.79"
[dependencies]
axum = "0.7"
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tracing = "0.1"
tracing-subscriber = "0.3"
[dev-dependencies]
reqwest = { version = "0.12", features = ["json"] }
tokio-test = "0.4"
```

---

## 9. First Feature as Vertical Slice (PDSA-Driven)

Structure the first feature as a PDSA vertical slice -- not just "implement core flow" but a hypothesis-driven, testable, rollback-ready delivery.

```markdown
VERTICAL SLICE PLAN
- Problem: {one user-facing problem, one sentence}
- Hypothesis: If we build {X}, then user can {Y}
- Acceptance criteria: {testable assertions -- each binary}
- Rollback: {how to revert if hypothesis fails}
- Swim Lane: {which lane from Section 9.5 this slice belongs to}
- Minimum modules: {list from Decomposition Ritual -- see ARCHITECTURE.md Section 13}
- Module contracts used: {which provides/requires from Section 10 are exercised}
- Definition of done: {user performs core action + test proves it}
```

ALWAYS write the vertical slice plan before writing any code. The plan IS the first deliverable.

### Pre-Flight Gate (Before PDSA DO Phase)

BEFORE writing any implementation code, complete this pre-flight checklist. This shifts verification left -- catch problems before they're built, not after.

```
PRE-FLIGHT GATE: {feature_name}
[ ] Acceptance criteria written as test assertions (not prose)
[ ] Test file exists and FAILS (red state -- proves the test is real)
[ ] Module Gate checklist passed for any new module (-> ARCHITECTURE.md Section 13)
[ ] Protocol/interface defined for any new module (contract-first)
[ ] Module contract (provides/requires) registered in Section 10
[ ] Swim lane assignment confirmed (Section 9.5) -- no lane conflicts
[ ] Rollback plan written (how to revert if hypothesis fails)
[ ] Five-lens test passed (-> PHILOSOPHY.md Section Five-Lens Test)
GATE RESULT: FLY / HOLD (hold if any box unchecked)
```

**Why test-first for AI?** Without pre-flight, the cycle is: implement -> verify -> fail -> fix -> verify -> pass (reactive, 4-10 cycles). With pre-flight: define tests -> implement -> verify -> pass (preventive, 1-2 cycles). The completion loop should rarely need more than 2 cycles. If it consistently needs more, the pre-flight gate is being skipped or the tests are too weak.

NEVER build more than the minimum modules needed for the first vertical slice -- premature modules become tech debt before the hypothesis is proven.

WHEN the project has algorithmic subsystems with multiple valid approaches, THEN produce an Initial Architecture Brief (-> See ARCHITECTURE.md Section 15) before the first vertical slice. The brief generates the option space; the Council evaluates it; the vertical slice implements the winning option.

WHEN the first vertical slice fails acceptance criteria, THEN pivot the hypothesis (change what you're building), NOT just the implementation (change how you're building it).

---

## 9.5. Swim Lane Planning (after Council #1)

ALWAYS decompose features into parallel swim lanes after Council Session #1 ratifies the architecture. Serial-when-parallel is waste (-> PHILOSOPHY.md Section Parallel Principles).

### Swim Lane Decomposition Process

```
SWIM LANE PLANNING

1. LIST all features from the Requirements Brief (T2 top 3 stories + core flow).
2. IDENTIFY dependencies between features:
   - Data dependencies: Feature B reads data Feature A writes
   - Interface dependencies: Feature B calls an API Feature A exposes
   - Shared-state dependencies: Features A and B mutate the same state
3. DRAW a dependency DAG (directed acyclic graph):
   - Nodes = features or feature groups
   - Edges = "must complete before" relationships
   - ONLY draw edges for genuine data/interface dependencies
   - NEVER draw edges for "it would be nice to have X first" -- that is serial thinking
4. GROUP independent nodes into swim lanes:
   - Each lane can proceed without waiting on other lanes
   - Each lane has a clear deliverable and acceptance criteria
   - Each lane maps to one or more pillars (Section 11)
5. IDENTIFY sync points:
   - Where do lanes need to merge? (integration, shared state, UI assembly)
   - What is the minimum viable sync? (contract test, not full integration)
6. RECORD the plan in the Swim Lane Plan template below.
```

### Swim Lane Plan Template

```markdown
# Swim Lane Plan -- {Project Name}

## Dependency DAG
{ASCII diagram or list of edges}

Example:
  [Auth] --> [User Profile] --> [Dashboard]
  [Data Ingestion] --> [Dashboard]
  [Auth] and [Data Ingestion] are independent -- parallel lanes

## Lanes

### Lane 1: {name}
- Features: {list}
- Depends on: {nothing / Lane N sync point}
- Deliverable: {what is done when this lane completes}
- Acceptance criteria: {testable}
- Estimated effort: {S/M/L}

### Lane 2: {name}
- Features: {list}
- Depends on: {nothing / Lane N sync point}
- Deliverable: {what is done when this lane completes}
- Acceptance criteria: {testable}
- Estimated effort: {S/M/L}

### Lane 3: {name} (if applicable)
- Features: {list}
- Depends on: {nothing / Lane N sync point}
- Deliverable: {what is done when this lane completes}
- Acceptance criteria: {testable}
- Estimated effort: {S/M/L}

## Sync Points
| Sync Point | Lanes Merging | Trigger | Integration Test |
|------------|--------------|---------|-----------------|
| {name} | Lane 1 + Lane 2 | {when both deliverables pass} | {what to test} |

## Execution Order
1. Start Lane 1 and Lane 2 in parallel
2. {sync point} when both complete
3. Start Lane 3 (if dependent on sync)
4. Final integration
```

### Swim Lane Rules

ALWAYS identify at least 2 independent lanes. If everything is genuinely serial, document why -- the five-lens test (Parallel lens) demands justification for serial execution.

NEVER block a lane waiting on another lane unless the dependency DAG explicitly shows a data or interface dependency.

WHEN a lane is blocked by an unfinished dependency, THEN stub the dependency with a contract test and continue. Real integration happens at sync points.

WHEN the project is a weekend hack (abbreviated interview mode), THEN swim lanes may be informal -- a simple list of "these 2 things can happen in parallel" is sufficient. The DAG and sync-point formalism is for month+ builds.

WHEN using parallel AI agents (fan-out), THEN assign one agent per lane. Each agent gets the lane's scope, the module contracts it depends on, and nothing else.

---

## 10. Module Contracts

ALWAYS define provides/requires for each major module at bootstrap. Module contracts are the connective tissue between swim lanes -- they let lanes develop independently against stable interfaces.

### Module Contract Format

```markdown
MODULE CONTRACT: {module_name}

PROVIDES:
- {function/endpoint/event}: {signature or shape}
- {function/endpoint/event}: {signature or shape}

REQUIRES:
- {module_name}.{function/endpoint/event}: {expected signature or shape}
- {external_service}.{capability}: {expected behavior}

INVARIANTS:
- {rule that must always hold -- e.g., "never returns null for authenticated users"}
- {rule that must always hold}

OWNER: {swim lane or team member}
STATUS: DRAFT | RATIFIED (by Council) | IMPLEMENTED | TESTED
```

### Module Contract Rules

ALWAYS write module contracts BEFORE writing module code. The contract IS the design.

ALWAYS include at least one invariant per module. Invariants are the Unbreakable Rules of the module level.

NEVER change a RATIFIED contract without a Council decision. Contract changes cascade across swim lanes -- they are architectural decisions, not implementation details.

WHEN two modules need to communicate, THEN define the contract from the CONSUMER's perspective. The consumer knows what it needs; the provider adapts to serve.

WHEN a module contract is too complex to describe in 5-10 lines, THEN the module is too large. Apply the Unix lens: split until each piece is describable in one sentence.

### Module Contract Registry

Record all module contracts in CLAUDE.md under the `## Module Contracts` section. This is the single source of truth for inter-module interfaces.

```markdown
## Module Contracts (in CLAUDE.md)

| Module | Provides | Requires | Invariants | Status |
|--------|----------|----------|------------|--------|
| {name} | {list} | {list} | {list} | DRAFT/RATIFIED/IMPLEMENTED |
```

---

## 11. Pillar Definition

During the tactical interview (T2: User Stories), map the top 3 user stories to "pillars." Each pillar tracks a user story across Backend, UI, and Overall progress. Pillars are the strategic view of what the project delivers; swim lanes are the tactical view of how work is parallelized.

### Pillar Template

```markdown
# Pillar Tracker -- {Project Name}

## Pillar 1: {User Story #1 -- e.g., "User can upload and process a document"}
| Dimension | Status | Key Deliverables | Acceptance Criteria |
|-----------|--------|-------------------|-------------------|
| Backend | NOT STARTED | {API endpoints, data processing, storage} | {testable criteria} |
| UI | NOT STARTED | {screens, components, interactions} | {testable criteria} |
| Overall | NOT STARTED | {end-to-end flow works} | {user can perform the action} |

## Pillar 2: {User Story #2}
| Dimension | Status | Key Deliverables | Acceptance Criteria |
|-----------|--------|-------------------|-------------------|
| Backend | NOT STARTED | {deliverables} | {criteria} |
| UI | NOT STARTED | {deliverables} | {criteria} |
| Overall | NOT STARTED | {end-to-end flow} | {criteria} |

## Pillar 3: {User Story #3}
| Dimension | Status | Key Deliverables | Acceptance Criteria |
|-----------|--------|-------------------|-------------------|
| Backend | NOT STARTED | {deliverables} | {criteria} |
| UI | NOT STARTED | {deliverables} | {criteria} |
| Overall | NOT STARTED | {end-to-end flow} | {criteria} |
```

### Pillar Rules

ALWAYS define exactly 3 pillars. More = scope creep. Fewer = the project scope is unclear.

ALWAYS include Backend, UI, and Overall dimensions even for projects without a visual UI. For CLI or API-only projects, "UI" becomes "Interface" (CLI commands, API surface).

NEVER mark a pillar's Overall status as DONE until both Backend and UI dimensions pass their acceptance criteria AND the end-to-end flow works.

WHEN a pillar is blocked, THEN the blocking issue becomes the next pass objective (-> ITERATION.md). Pillar health drives iteration priority.

WHEN the project is a weekend hack, THEN pillars can be informal -- a simple list of "Story 1: backend done, UI todo" is sufficient. The full table is for month+ builds.

### Pillar-to-Swim-Lane Mapping

Each pillar maps to one or more swim lanes. The mapping is recorded in the Swim Lane Plan:

```
PILLAR-LANE MAPPING
- Pillar 1 -> Lane 1 (backend), Lane 3 (UI)
- Pillar 2 -> Lane 2 (backend + UI -- small enough for one lane)
- Pillar 3 -> Lane 1 (backend, shared with Pillar 1), Lane 3 (UI, shared with Pillar 1)
```

This mapping ensures that every swim lane contributes to a visible user-facing pillar, and every pillar has a clear execution path through the swim lane DAG.

---

## Related Directives

- -> See PHILOSOPHY.md -- kaizen-deming-unix-AI-native-parallel foundation applied from minute zero; five-lens test for every component
- -> See ARCHITECTURE.md Section Four-Layer Stack -- patterns from Council Session #1
- -> See ARCHITECTURE.md Section Feature Lifecycle -- first feature pipeline
- -> See ARCHITECTURE.md Section Dependency Management -- per-ecosystem dep rules
- -> See ARCHITECTURE.md Section 13 -- Decomposition Ritual and Module Gate for new modules
- -> See ARCHITECTURE.md Section 15 -- Initial Architecture Brief for algorithmic subsystems
- -> See ARCHITECTURE.md Section 16 -- Cross-project component decomposition
- -> See ITERATION.md -- pass loop, completion loop, and variance tracking
- -> See QUALITY.md -- quality gates, testing protocol, and regression policy
- -> See TEAM.md Section Council Protocol -- full Council protocol and decision records
- -> See TEAM.md Section 8 -- team composition and Council seat selection

---

## Framework Navigation

> **You Are Here:** `GENESIS.md` — Project kickoff: interview → probe → bootstrap → swim lanes
> **Core Method:** Kaizen · Deming · Unix · AI-Native · Parallel → PHILOSOPHY.md

| File | When To Read |
|------|-------------|
| CLAUDE.md | Session start, operating mode routing, unbreakable rules |
| PHILOSOPHY.md | Principle check, five-lens test, enforcement rules |
| GENESIS.md | ★ You are here |
| TEAM.md | AI model selection, Council decisions, persona profiles |
| ARCHITECTURE.md | Module design, dependency management, MAP manifests |
| ITERATION.md | Pass loop, swim lanes, circle detection, session handoff |
| QUALITY.md | Gate verification G0-G9, completion loop, testing |
| DESIGN.md | Visual identity, design gates, component system |
| HANDHOLDING.md | Newcomer guidance, glossary, preemptive help |
| OPERATIONS.md | Dev environment, dashboard, MVP tracker, reporting |
| CHARACTER-TRACKING.md | Team performance, calibration, persona metrics |

> **If lost:** Start at CLAUDE.md. If a concept is unclear, check HANDHOLDING.md §9 Glossary.
> **If stuck:** ITERATION.md §7 Failure Gates (1-fail retry, 2-fail pivot, 3-fail Council).
> **If quality uncertain:** QUALITY.md §1 Gate Runner. If design: DESIGN.md §5 Design Gates.
- -> See OPERATIONS.md -- deployment, framework versioning, and trend logging
