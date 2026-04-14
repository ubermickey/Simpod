# CHARACTER-TRACKING.md -- Living Team Roster, Performance Logs & Cross-Reference Map

> **Kaizen** -- Every team member is a system to measure and improve; track actuals, adjust routing, iterate.
> **Unix** -- Each persona does one thing well; performance data is composable, not monolithic.
> **Deming** -- Fix the routing process, not the individual; calibrate from data, not from intuition.
> **AI-Native** -- Machine-parseable tables; cold-start AI reads this file and knows where every persona lives.
> **Parallel** -- Performance logs are written concurrently by all active agents; no serialization needed.
> NEVER let routing drift from data. ALWAYS re-calibrate every 5 sessions or at every phase boundary.

---

## Table of Contents

1. [Core Team Roster](#1-core-team-roster)
   - 1.1 Aria — THINK / Opus
   - 1.2 Marcus — BUILD / Sonnet
   - 1.3 Zara — TALK / Haiku
   - 1.4 Dr. Kai — Research / o3
   - 1.5 Pixel — Visual QA / Playwright
2. [Council Seats Aggregate Tracking](#2-council-seats-aggregate-tracking)
3. [Cross-Reference Master Map](#3-cross-reference-master-map)
4. [Team Efficiency Dashboard](#4-team-efficiency-dashboard)
5. [Kaizen Improvement Protocol](#5-kaizen-improvement-protocol)

---

## 1. Core Team Roster

---

### 1.1 Aria — THINK Tier, Principal Architect

| Attribute | Detail |
|-----------|--------|
| **Persona** | Aria |
| **Tier** | THINK |
| **Model** | Claude Opus 4.6 (`claude-opus-4-6`) |
| **Inspired By** | Dario Amodei (physicist's instinct for system laws) + Chris Olah (cartographer patience, interpretability) |
| **One-Line** | Sees system-level structure before anyone else; can explain it on a napkin. |
| **Cost** | $$$ — high cost, moderate speed (10-60s) |
| **Framework Authority** | CLAUDE.md, TEAM.md §1-§6/§10, ARCHITECTURE.md §1-§4, GENESIS.md §0-§6, ITERATION.md §1, QUALITY.md §1, PHILOSOPHY.md, OPERATIONS.md §5/§9 |

#### Performance Log

| Date | Project | Task | Outcome | Sessions | Lines Reviewed | Duration (s) | Escalated From | Escalated To | Notes |
|------|---------|------|---------|----------|----------------|--------------|----------------|--------------|-------|
| {date} | {project} | {task} | {outcome} | {n} | {n} | {n} | {from} | {to} | {notes} |

#### Efficiency Metrics

| Metric | Target | Actual | Delta | Last Updated |
|--------|--------|--------|-------|--------------|
| Architectural decision accuracy (no reversal within sprint) | ≥90% | {n}% | {n}% | {date} |
| Council session median duration | ≤45 min | {n} min | {n} min | {date} |
| Escalation to HUMAN rate (Council deadlocks) | ≤10% | {n}% | {n}% | {date} |
| PDSA hypothesis hit rate (expected vs. observed) | ≥70% | {n}% | {n}% | {date} |
| Sessions where BUILD was stuck before Aria engaged | ≤2/project | {n} | {n} | {date} |
| Cross-file architectural consistency score (gate G4) | 100% | {n}% | {n}% | {date} |

#### Growth Log (Kaizen)

| Date | What Improved | How | Measured By |
|------|---------------|-----|-------------|
| {date} | {improvement} | {method} | {metric} |

#### Calibration Notes

- **Over-utilization signals**: Aria is being called for single-file, obviously-correct fixes that BUILD could handle. Check if escalation threshold is set too low.
- **Under-utilization signals**: BUILD is stuck 3+ attempts on cross-cutting issues without escalating. Check if escalation protocol is being skipped.
- **Cost creep signal**: Aria session count exceeds 15% of total sessions in a week — review whether THINK tasks are genuinely THINK-tier.
- **Quality signal**: If architectural reversals exceed 10% per sprint, Aria's decision pattern needs review via Council.
- **Routing reminder**: Aria NEVER self-implements. All implementation work delegates to Marcus.

#### Cross-Reference Map

| File | Sections | Role |
|------|----------|------|
| CLAUDE.md | Three-Tier AI Model, Operating Modes, Session Start Protocol, Unbreakable Rules | OWNER — orchestrates all operating modes |
| PHILOSOPHY.md | Five-Lens Test, Activity Matrix (Team row), Enforcement Hooks (AI-Native/Parallel) | ENFORCE — five-lens arbiter |
| GENESIS.md | §0 Requirements Interview, §1 60-Second Probe, §2-§5 Bootstrap, §6 Council #1, Swim Lane Planning | LEAD — runs project kickoff |
| ARCHITECTURE.md | §1 Four-Layer Stack, §2 MAP, §3 Module Registry, §4 Degradation Model | OWNER — structural authority |
| ITERATION.md | §1 PDSA Outer Loop, Phase Cadence ritual, Circle Detection | LEAD — PDSA hypothesis author |
| QUALITY.md | §1 Gate Orchestration, G0-G4 design/architecture gates | OWNER — gate authority |
| DESIGN.md | Design Gate criteria, Identity Block review | ENFORCE — design gate judge |
| TEAM.md | §1 Three-Tier Model, §2 Org Chart, §3.1 Aria Profile, §6 Delegation, §7.1-7.2, §10 Council Chair | OWNER — Council Chair |
| HANDHOLDING.md | Guide panel triggers, escalation path descriptions | ref |
| OPERATIONS.md | §5 Dashboard (session tracking), §9 Retrospective, §Framework Versioning | LEAD — retrospective chair |
| CHARACTER-TRACKING.md | §1.1 (this section), §2 Council, §3 Master Map, §4 Dashboard, §5 Kaizen Protocol | AUTHOR |

---

### 1.2 Marcus — BUILD Tier, Senior Engineer

| Attribute | Detail |
|-----------|--------|
| **Persona** | Marcus |
| **Tier** | BUILD |
| **Model** | Claude Sonnet 4.6 (`claude-sonnet-4-6`) |
| **Inspired By** | Tom Brown (engineering-driven research, pragmatic shipping) + Zac Hatfield-Dodds (property-based testing, systematic failure-space exploration) |
| **One-Line** | Ships fast and tests rigorously; reads existing code before writing a single line. |
| **Cost** | $$ — medium cost, fast speed (5-30s) |
| **Framework Authority** | QUALITY.md §3-§4, ITERATION.md §2, ARCHITECTURE.md §13, OPERATIONS.md §4 |

#### Performance Log

| Date | Project | Task | Outcome | Lines Written | Lines Modified | Duration (s) | Escalated From | Escalated To | Notes |
|------|---------|------|---------|---------------|----------------|--------------|----------------|--------------|-------|
| {date} | {project} | {task} | {outcome} | {n} | {n} | {n} | {from} | {to} | {notes} |

#### Efficiency Metrics

| Metric | Target | Actual | Delta | Last Updated |
|--------|--------|--------|-------|--------------|
| First-pass implementation acceptance rate (no rework needed) | ≥75% | {n}% | {n}% | {date} |
| Average lines per implemented task | ≤200 | {n} | {n} | {date} |
| Functions exceeding 40-line limit (Unix gate) | 0 | {n} | {n} | {date} |
| Test coverage delta per feature (lines added) | ≥80% | {n}% | {n}% | {date} |
| Escalation to Aria rate (stuck 2+ attempts) | ≤20% | {n}% | {n}% | {date} |
| Regression introduction rate per sprint | ≤5% | {n}% | {n}% | {date} |

#### Growth Log (Kaizen)

| Date | What Improved | How | Measured By |
|------|---------------|-----|-------------|
| {date} | {improvement} | {method} | {metric} |

#### Calibration Notes

- **Over-utilization signals**: Marcus is being routed tasks that are boilerplate, templating, or parallel-identical — these should be Zara fan-outs.
- **Under-utilization signals**: TALK-tier agents are writing implementation logic or modifying multi-file codepaths — route back to Marcus.
- **Escalation check**: If Marcus is stuck 2+ attempts on the same task without escalating to Aria, the escalation protocol is broken.
- **Test rigor check**: If coverage delta drops below 60% on any sprint, audit whether Marcus is deferring tests.
- **Pattern signal**: Repeated same-cause bugs across sprints = process issue, not Marcus issue (Deming: fix the process).

#### Cross-Reference Map

| File | Sections | Role |
|------|----------|------|
| CLAUDE.md | Three-Tier AI Model (BUILD row), Operating Modes §ACTIVE PROJECT | ref |
| PHILOSOPHY.md | Unix Enforcement (40-line rule, 500-line file rule), Kaizen Enforcement (measurable delta) | ENFORCE |
| GENESIS.md | First Feature implementation, Bootstrap scaffolding tasks | LEAD — implementation executor |
| ARCHITECTURE.md | §13 Module Gate (one-sentence test), §SVC tiers, MAP provides/requires | ENFORCE |
| ITERATION.md | §2 Pass Loop Executor (DO phase), PDSA DO step, Swim Lane execution within lanes | LEAD — pass executor |
| QUALITY.md | §3 Trifecta (correctness/performance/security), §4 Testing Pyramid, G5-G9 implementation gates | OWNER |
| DESIGN.md | Identity Block implementation, CSS/component scaffolding | LEAD |
| TEAM.md | §3.2 Marcus Profile, §7.1 Design Pattern (BUILD step), §7.2 Review Pattern (writer + reviser), §7.3 Research Pattern (builder), §8 Parallel Execution (executor) | ref |
| HANDHOLDING.md | Code examples, implementation walkthroughs | ref |
| OPERATIONS.md | §4 Git Workflow (commit standards, branch strategy) | OWNER |
| CHARACTER-TRACKING.md | §1.2 (this section) | AUTHOR |

---

### 1.3 Zara — TALK Tier, Speed Engineer

| Attribute | Detail |
|-----------|--------|
| **Persona** | Zara |
| **Tier** | TALK |
| **Model** | Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) |
| **Inspired By** | Daniela Amodei (operational clarity, translates mission to action) + Jack Clark (synthesis at speed, identifies what matters first) |
| **One-Line** | Processes N independent tasks in parallel before you finish your coffee; returns clean results, no commentary. |
| **Cost** | $ — very low cost, very fast (1-5s) |
| **Framework Authority** | TEAM.md §8.1, OPERATIONS.md §5, ITERATION.md §10 |

#### Performance Log

| Date | Project | Task | Outcome | Tasks Parallelized | Avg Duration (s) | Escalated From | Escalated To | Notes |
|------|---------|------|---------|-------------------|------------------|----------------|--------------|-------|
| {date} | {project} | {task} | {outcome} | {n} | {n} | {from} | {to} | {notes} |

#### Efficiency Metrics

| Metric | Target | Actual | Delta | Last Updated |
|--------|--------|--------|-------|--------------|
| Fan-out task completion rate (no retry needed) | ≥95% | {n}% | {n}% | {date} |
| Median task duration | ≤5s | {n}s | {n}s | {date} |
| Tasks incorrectly routed to Zara requiring escalation | ≤5% | {n}% | {n}% | {date} |
| Session handoff auto-generation success rate | ≥98% | {n}% | {n}% | {date} |
| Boilerplate quality gate pass rate (no manual fixes) | ≥90% | {n}% | {n}% | {date} |

#### Growth Log (Kaizen)

| Date | What Improved | How | Measured By |
|------|---------------|-----|-------------|
| {date} | {improvement} | {method} | {metric} |

#### Calibration Notes

- **Over-utilization signals**: Zara is being routed multi-file, context-heavy, or architectural tasks — these require Marcus or Aria.
- **Under-utilization signals**: Marcus is spending time on boilerplate templates, parallel-identical unit tests, or status updates — fan out to Zara.
- **Fan-out quality check**: If Zara fan-out results require >10% manual correction, task decomposition instructions need improvement (not Zara's issue).
- **Session handoff check**: If handoff records are missing or incomplete after sessions, verify Zara's auto-generation hook is active.
- **Cost check**: Zara should represent ~25% of total invocations by count. Higher = Aria/Marcus under-routing to fan-out. Lower = missed parallelism.

#### Cross-Reference Map

| File | Sections | Role |
|------|----------|------|
| CLAUDE.md | Three-Tier AI Model (TALK row) | ref |
| PHILOSOPHY.md | Parallel Enforcement (fan-out requirement), Parallel Principles | ENFORCE |
| GENESIS.md | Parallel research sub-tasks during probe phase, boilerplate scaffolding | ref |
| ARCHITECTURE.md | Config file generation, scaffolding N similar components | ref |
| ITERATION.md | §10 Session Handoff Auto-Generation, parallel pass execution across swim lanes | OWNER (§10) |
| QUALITY.md | Parallel test writing fan-out (G5-G9 test generation) | ref |
| DESIGN.md | Boilerplate Identity Block generation across N components | ref |
| TEAM.md | §3.3 Zara Profile, §8.1 Fan-Out Pattern (executor), §8.4 Status Check (non-blocking monitor) | OWNER (§8.1) |
| HANDHOLDING.md | Status check queries, quick FAQ responses | ref |
| OPERATIONS.md | §5 Dashboard Status Updates (TALK-tier status queries) | OWNER (§5 status) |
| CHARACTER-TRACKING.md | §1.3 (this section) | AUTHOR |

---

### 1.4 Dr. Kai — Research Scientist, Novel Problem Solver

| Attribute | Detail |
|-----------|--------|
| **Persona** | Dr. Kai |
| **Tier** | External / Research |
| **Model** | OpenAI o3 (or latest reasoning model) |
| **Inspired By** | Jared Kaplan (scaling laws, physics-grade empiricism) + Jan Leike (AIXI theoretical depth, principled alignment rigor) |
| **One-Line** | Finds laws in mathematical chaos; presents counterarguments before you ask for them. |
| **Cost** | $$$$ — high cost, variable speed (30s-5min) |
| **Framework Authority** | TEAM.md §10.2 (C2 Critic default), QUALITY.md §7, PHILOSOPHY.md (Deming/PDSA), ARCHITECTURE.md §14 |

#### Performance Log

| Date | Project | Problem | Approach | Outcome | Duration (s) | Adopted By | Notes |
|------|---------|---------|---------|---------|--------------|------------|-------|
| {date} | {project} | {problem} | {approach} | {outcome} | {n} | {agent} | {notes} |

#### Efficiency Metrics

| Metric | Target | Actual | Delta | Last Updated |
|--------|--------|--------|-------|--------------|
| Novel algorithm adoption rate (Dr. Kai proposes → BUILD implements) | ≥60% | {n}% | {n}% | {date} |
| Adversarial case coverage per Council session (C2 seat) | ≥5 failure modes | {n} | {n} | {date} |
| PDSA hypothesis falsification rate (cases where Dr. Kai found the flaw) | tracked | {n}% | — | {date} |
| Rollback drill design adequacy (gate G7) | 100% coverage | {n}% | {n}% | {date} |
| Cost per research invocation (vs. value delivered) | reviewed monthly | ${n} | — | {date} |
| Council C2 veto rate (evidence-backed vetoes upheld) | ≥80% | {n}% | {n}% | {date} |

#### Growth Log (Kaizen)

| Date | What Improved | How | Measured By |
|------|---------------|-----|-------------|
| {date} | {improvement} | {method} | {metric} |

#### Calibration Notes

- **Over-utilization signals**: Dr. Kai is being invoked for standard programming tasks, code reviews, or previously-solved problems — route to Marcus or Aria.
- **Under-utilization signals**: Complex optimization, formal proofs, or multi-paper synthesis problems are being attempted by BUILD without research support.
- **Cost governance**: Dr. Kai invocations must be logged in OPERATIONS.md AI cost tracker. Any week with >3 Dr. Kai invocations requires a cost justification note.
- **Proposal handoff**: Dr. Kai proposes; Aria validates; Marcus builds. The chain must not collapse into Dr. Kai implementing directly.
- **Council C2**: Dr. Kai is the default C2 Critic seat. If o3 is unavailable, fall back to Claude Opus with [FALLBACK] tag.

#### Cross-Reference Map

| File | Sections | Role |
|------|----------|------|
| CLAUDE.md | Three-Tier AI Model (External row) | ref |
| PHILOSOPHY.md | Deming Principles (PDSA hypothesis testing), Five-Lens Test (Deming lens) | ENFORCE (Deming) |
| GENESIS.md | 60-Second Probe novel domain research, Research Pattern kickoff | ref |
| ARCHITECTURE.md | §14 Benchmark Harness design, novel algorithm specification | OWNER (§14) |
| ITERATION.md | PDSA Plan phase (hypothesis design), Circle Detection (adversarial) | ref |
| QUALITY.md | §7 Rollback Drill Designer, adversarial gate design (G2 Critic scenarios) | OWNER (§7) |
| DESIGN.md | Adversarial UX edge cases | ref |
| TEAM.md | §3.4 Dr. Kai Profile, §7.3 Research Pattern (o3 explores step), §10.2 Council C2 Critic (default seat) | OWNER (C2 default) |
| HANDHOLDING.md | Novel problem escalation path | ref |
| OPERATIONS.md | AI Cost Tracking (highest-cost tier), External Model Registry (§3.8) | ref |
| CHARACTER-TRACKING.md | §1.4 (this section) | AUTHOR |

---

### 1.5 Pixel — Visual QA, Deterministic Verification

| Attribute | Detail |
|-----------|--------|
| **Persona** | Pixel |
| **Tier** | Tooling (not an LLM) |
| **Tool** | Playwright + Screenshot Loop |
| **Inspired By** | Zac Hatfield-Dodds's testing philosophy: systematic exploration of failure space applied to pixels |
| **One-Line** | Compares pixels with no opinions; returns PASS or FAIL with a diff image. |
| **Cost** | Zero LLM cost, 2-10s per test |
| **Framework Authority** | QUALITY.md §9-§10, DESIGN.md §5 |

#### Performance Log

| Date | Project | UI Component Tested | Gate | Outcome | Pixel Diff % | Threshold | Duration (s) | Fix Required | Notes |
|------|---------|--------------------|----|---------|-------------|-----------|--------------|--------------|-------|
| {date} | {project} | {component} | {gate} | PASS/FAIL | {n}% | {n}% | {n} | {yes/no} | {notes} |

#### Efficiency Metrics

| Metric | Target | Actual | Delta | Last Updated |
|--------|--------|--------|-------|--------------|
| Screenshot test suite run time (full regression) | ≤120s | {n}s | {n}s | {date} |
| False positive rate (FAIL with no real visual defect) | ≤2% | {n}% | {n}% | {date} |
| Defect detection rate (found before human review) | ≥95% | {n}% | {n}% | {date} |
| CI integration uptime | ≥99% | {n}% | {n}% | {date} |
| Pixel diff threshold calibration accuracy | reviewed per-project | {n}% | — | {date} |

#### Growth Log (Kaizen)

| Date | What Improved | How | Measured By |
|------|---------------|-----|-------------|
| {date} | {improvement} | {method} | {metric} |

#### Calibration Notes

- **Threshold drift**: If false positive rate exceeds 2%, pixel diff threshold needs per-project recalibration — do not raise threshold globally.
- **Scope reminder**: Pixel NEVER runs for backend-only changes, API design, or performance testing. Check if CI trigger conditions are correctly scoped.
- **Loop closure**: Every Pixel FAIL triggers a Marcus fix cycle. Verify fix → re-run Pixel → confirm PASS before closing the gate.
- **Baseline freshness**: Screenshot baselines must be updated after intentional design changes. Stale baselines produce false positives.
- **Responsive coverage**: Track % of viewport sizes covered. Narrow coverage means mobile or wide-screen regressions go undetected.

#### Cross-Reference Map

| File | Sections | Role |
|------|----------|------|
| CLAUDE.md | Three-Tier AI Model routing (Visual QA node) | ref |
| PHILOSOPHY.md | Deming Enforcement (systematic verification, not sampling) | ref |
| GENESIS.md | UI lane setup, Playwright scaffold in bootstrap phase | ref |
| ARCHITECTURE.md | Module Gate (UI components), degradation model (visual layer) | ref |
| ITERATION.md | VERIFY phase (screenshot gate step), swim lane UI verification gate | ref |
| QUALITY.md | §9 Screenshot Verification, §10 CI Integration, G6-G8 visual quality gates | OWNER |
| DESIGN.md | §5 Design Gate Data Source (pixel diff feeds design gate pass/fail) | OWNER (§5) |
| TEAM.md | §3.5 Pixel Profile, §7.1 Pipeline Pattern (VERIFY step) | ref |
| HANDHOLDING.md | Visual defect explanation for newcomers | ref |
| OPERATIONS.md | CI pipeline health monitoring | ref |
| CHARACTER-TRACKING.md | §1.5 (this section) | AUTHOR |

---

## 2. Council Seats Aggregate Tracking

### Session History

| Session # | Date | Project | Question | Seats Convened | Decision | Convergence Mechanism | Duration (min) | Human Escalated | Notes |
|-----------|------|---------|---------|---------------|---------|----------------------|---------------|-----------------|-------|
| {n} | {date} | {project} | {question} | C1+C2+C3+{P?}+{P?} | {decision} | {mechanism} | {n} | {yes/no} | {notes} |

### Seat Utilization

| Seat | Persona Name | Inspired By | Sessions Active | Avg Score Contribution | Veto Count | Vetoes Upheld | Most Common Lens Applied | Notes |
|------|-------------|-------------|-----------------|----------------------|-----------|---------------|--------------------------|-------|
| C1 Architect | The Architect | Chris Olah | {n} | {n} | {n} | {n} | System scalability | Permanent core seat |
| C2 Critic | The Critic | Evan Hubinger + Jan Leike | {n} | {n} | {n} | {n} | Failure modes / adversarial | Permanent core seat; Dr. Kai default |
| C3 Pragmatist | The Pragmatist | Tom Brown + Benjamin Mann | {n} | {n} | {n} | {n} | Shipping speed / simplicity | Permanent core seat; Claude Opus default |
| P1 Aesthete | The Aesthete | Amanda Askell | {n} | {n} | {n} | {n} | Design coherence / UX delight | Project-specific |
| P2 Oracle | The Oracle | Jared Kaplan + Durk Kingma | {n} | {n} | {n} | {n} | Prior art / scaling patterns | Project-specific |
| P3 Broker | The Broker | Daniela Amodei + Jack Clark | {n} | {n} | {n} | {n} | Compliance / operations | Project-specific |
| P4 Hacker | The Hacker | Evan Hubinger + Nicholas Schiefer | {n} | {n} | {n} | {n} | Security / red teaming | Project-specific |
| P5 Scientist | The Scientist | Sam McCandlish + Deep Ganguli | {n} | {n} | {n} | {n} | Statistical rigor | Project-specific |
| P6 Showrunner | The Showrunner | Amanda Askell + Deep Ganguli | {n} | {n} | {n} | {n} | User journey / emotional arc | Project-specific |

### Convergence Mechanism Effectiveness

| Mechanism | Times Used | Decisions Reached | Human Escalations Required | Avg Rounds to Convergence | Notes |
|-----------|-----------|------------------|---------------------------|--------------------------|-------|
| Schelling Focal Point | {n} | {n} | {n} | {n} | First pass — obvious dominant choice |
| IESDS (Iterated Elimination of Dominated Strategies) | {n} | {n} | {n} | {n} | Eliminates clearly inferior options |
| Nash Bargaining | {n} | {n} | {n} | {n} | Balanced multi-objective decisions |
| Minimax Regret | {n} | {n} | {n} | {n} | Minimizes worst-case outcome |
| Speed Council (C3 unilateral) | {n} | {n} | {n} | 1 | Low-stakes, max regret ≤2 |
| Human Escalation | {n} | {n} | — | — | Deadlock or safety-critical |

---

## 3. Cross-Reference Master Map

Legend:
- **OWNER** — primary author and authority; changes require this persona's review
- **LEAD** — leads execution within this file's domain
- **ENFORCE** — actively enforces rules from this file
- **AUTHOR** — wrote specific tracked sections
- **ref** — referenced; reads context from this file

| Framework File | Aria (THINK/Opus) | Marcus (BUILD/Sonnet) | Zara (TALK/Haiku) | Dr. Kai (Research/o3) | Pixel (Playwright) | Council (Aggregate) |
|----------------|-------------------|-----------------------|-------------------|-----------------------|--------------------|---------------------|
| **CLAUDE.md** | OWNER | ref | ref | ref | ref | ref |
| **PHILOSOPHY.md** | ENFORCE | ENFORCE (Unix) | ENFORCE (Parallel) | ENFORCE (Deming) | ref | ref |
| **GENESIS.md** | LEAD §0-§6 | LEAD (First Feature) | ref | ref | ref | LEAD (Council #1) |
| **ARCHITECTURE.md** | OWNER §1-§4 | ENFORCE §13 | ref | OWNER §14 | ref | ref |
| **ITERATION.md** | LEAD §1 (PDSA) | LEAD §2 (Pass Loop) | OWNER §10 (Handoff) | ref | ref | ref |
| **QUALITY.md** | OWNER §1 (Gates) | OWNER §3-§4 (Testing) | ref | OWNER §7 (Rollback) | OWNER §9-§10 (Visual) | ref |
| **DESIGN.md** | ENFORCE (Gates) | LEAD (Implementation) | ref | ref | OWNER §5 (Gate Data) | LEAD (P1 Aesthete) |
| **TEAM.md** | OWNER §1-§6/§10 | ref | OWNER §8.1 (Fan-Out) | OWNER (C2 default) | ref | OWNER §10 |
| **HANDHOLDING.md** | ref | ref | ref | ref | ref | ref |
| **OPERATIONS.md** | LEAD §9 (Retro) | OWNER §4 (Git) | OWNER §5 (Status) | ref (Cost Tracking) | ref | ref |
| **CHARACTER-TRACKING.md** | AUTHOR §1.1/§2/§3/§4/§5 | AUTHOR §1.2 | AUTHOR §1.3 | AUTHOR §1.4 | AUTHOR §1.5 | AUTHOR §2 |

### Detailed Section Index

| Framework File | Sections | Aria | Marcus | Zara | Dr. Kai | Pixel | Council |
|----------------|----------|------|--------|------|---------|-------|---------|
| TEAM.md | §1 Three-Tier Model | OWNER | ref | ref | ref | ref | ref |
| TEAM.md | §2 Org Chart | OWNER | ref | ref | ref | ref | ref |
| TEAM.md | §3.1 Aria Profile | AUTHOR | — | — | — | — | — |
| TEAM.md | §3.2 Marcus Profile | — | AUTHOR | — | — | — | — |
| TEAM.md | §3.3 Zara Profile | — | — | AUTHOR | — | — | — |
| TEAM.md | §3.4 Dr. Kai Profile | — | — | — | AUTHOR | — | — |
| TEAM.md | §3.5 Pixel Profile | — | — | — | — | AUTHOR | — |
| TEAM.md | §7 Delegation Patterns | LEAD | LEAD | ref | ref | ref | ref |
| TEAM.md | §8.1 Fan-Out Pattern | ref | ref | OWNER | — | — | — |
| TEAM.md | §10 Council Protocol | LEAD (Chair) | ref | ref | LEAD (C2) | — | OWNER |
| QUALITY.md | §1 Gate Orchestration | OWNER | ref | ref | ref | ref | ref |
| QUALITY.md | §3 Trifecta | ref | OWNER | — | ref | — | — |
| QUALITY.md | §7 Rollback Drills | ref | ref | — | OWNER | — | — |
| QUALITY.md | §9 Screenshot Verification | — | ref | — | — | OWNER | — |
| QUALITY.md | §10 CI Integration | — | ref | — | — | OWNER | — |
| ARCHITECTURE.md | §1-§4 Stack/MAP | OWNER | ref | — | ref | — | ref |
| ARCHITECTURE.md | §13 Module Gate | ENFORCE | ENFORCE | — | — | — | — |
| ARCHITECTURE.md | §14 Benchmark Harness | ref | ref | — | OWNER | — | — |
| ITERATION.md | §1 PDSA Outer Loop | LEAD | ref | — | ref | — | — |
| ITERATION.md | §2 Pass Loop | ref | LEAD | — | — | — | — |
| ITERATION.md | §10 Session Handoff | — | — | OWNER | — | — | — |
| OPERATIONS.md | §4 Git Workflow | ref | OWNER | — | — | — | — |
| OPERATIONS.md | §5 Dashboard | LEAD | — | OWNER (status) | — | — | — |
| OPERATIONS.md | §9 Retrospective | LEAD | — | — | — | — | — |
| OPERATIONS.md | AI Cost Tracking | ref | — | — | ref (highest cost) | ref (zero cost) | ref |

---

## 4. Team Efficiency Dashboard

### Tier Distribution Tracker

**Target Distribution:**

| Tier | Target % of Invocations | Target % of Cost | Agent | Model |
|------|------------------------|-----------------|-------|-------|
| TALK | 25% | 5% | Zara | claude-haiku-4-5-20251001 |
| BUILD | 60% | 50% | Marcus | claude-sonnet-4-6 |
| THINK | 15% | 35% | Aria | claude-opus-4-6 |
| Research | ≤5% | ≤10% | Dr. Kai | openai-o3 |
| Visual QA | unlimited | 0% LLM | Pixel | playwright |

**Actual (current tracking period: {start_date} to {end_date}):**

| Tier | Agent | Invocations | % of Total | Cost ($) | % of Cost | On-Target? |
|------|-------|-------------|------------|----------|-----------|------------|
| TALK | Zara | {n} | {n}% | ${n} | {n}% | {yes/no} |
| BUILD | Marcus | {n} | {n}% | ${n} | {n}% | {yes/no} |
| THINK | Aria | {n} | {n}% | ${n} | {n}% | {yes/no} |
| Research | Dr. Kai | {n} | {n}% | ${n} | {n}% | {yes/no} |
| Visual QA | Pixel | {n} | n/a | $0 | 0% | n/a |
| **TOTAL** | — | **{n}** | 100% | **${n}** | 100% | — |

### Cost Tracking Per Tier

| Period | TALK ($) | BUILD ($) | THINK ($) | Research ($) | Total ($) | Budget ($) | Variance ($) |
|--------|----------|-----------|-----------|-------------|-----------|-----------|--------------|
| {week/sprint} | ${n} | ${n} | ${n} | ${n} | ${n} | ${n} | ${n} |

### Weekly Snapshot Template

```
## Team Efficiency Snapshot — Week of {date}

### Tier Distribution (actual vs. target)
| Tier   | Invocations | Target % | Actual % | Status    |
|--------|-------------|----------|----------|-----------|
| TALK   | {n}         | 25%      | {n}%     | ON/OVER/UNDER |
| BUILD  | {n}         | 60%      | {n}%     | ON/OVER/UNDER |
| THINK  | {n}         | 15%      | {n}%     | ON/OVER/UNDER |
| Ext    | {n}         | ≤5%      | {n}%     | ON/OVER/UNDER |

### Cost Summary
- Total: ${n}  |  TALK: ${n}  |  BUILD: ${n}  |  THINK: ${n}  |  Research: ${n}
- Budget used: {n}%

### Escalation Events
- BUILD → THINK: {n} times (cause: {most common cause})
- THINK → Council: {n} times (cause: {most common cause})
- Council → Human: {n} times (cause: {most common cause})

### Circle Detections
- Circles detected: {n}
- Circles resolved: {n}
- Circles requiring pattern change: {n}

### Notable Performance Events
- {observation_1}
- {observation_2}

### Routing Adjustments Made
- {adjustment_1} (reason: {reason})

### Next Calibration Due
- {date} (5 sessions from last calibration OR next phase boundary)
```

---

## 5. Kaizen Improvement Protocol

### When to Calibrate

Calibration is MANDATORY at:
1. Every 5 sessions (rolling count from last calibration)
2. Every project phase boundary (Genesis → Active → Retrospective)
3. Whenever tier distribution drifts >10% from target for 2+ consecutive sessions
4. After any circle is declared resolved — verify routing change prevented recurrence
5. After any Council session that escalated to Human — retrospect on whether routing or escalation protocol failed

### How to Update

**Step 1 — Read actuals.** Load CHARACTER-TRACKING.md §4 Weekly Snapshot for the past period.

**Step 2 — Compare to targets.** For each tier:
- TALK: target 25% of invocations. If actual <20% → fan-out under-utilized; if actual >30% → boilerplate tasks crowding out real TALK work.
- BUILD: target 60% of invocations. If actual <50% → implementation tasks leaking to THINK or Research; if actual >70% → insufficient architecture planning up front.
- THINK: target 15% of invocations. If actual <10% → escalation path may be broken; if actual >20% → over-consulting on trivial decisions.
- Research: target ≤5%. If exceeded → review each Dr. Kai invocation for routing correctness.

**Step 3 — Update Calibration Notes** for the affected persona(s) in §1 of this file.

**Step 4 — Adjust routing rules.** If a pattern is systemic (3+ sessions), update CLAUDE.md routing guidance or TEAM.md model selection matrix. Follow the framework evolution protocol in OPERATIONS.md §Framework Versioning.

**Step 5 — Log the calibration.** Add a row to the affected persona's Growth Log table with what changed, how it was changed, and what metric proves it worked.

### Session-End Hook: Auto-Append Performance Data

At the end of every session, append the following record to the relevant persona's Performance Log table:

```markdown
| {YYYY-MM-DD} | {project_name} | {task_description_1_sentence} | {PASS/FAIL/PARTIAL} | {invocation_count} | {lines_written_or_reviewed} | {total_duration_seconds} | {tier_escalated_from} | {tier_escalated_to} | {free_text_notes} |
```

Rules for session-end auto-append:
- ALWAYS use ISO 8601 dates (YYYY-MM-DD)
- Task description MUST fit in one sentence (Unix: one-sentence test)
- Escalation fields: use tier name (TALK/BUILD/THINK/Research/Human) or "—" if no escalation
- If Pixel ran, append to §1.5 Performance Log using its own table format
- If a Council session ran, append to §2 Session History table
- NEVER skip the log because "nothing interesting happened" — null results are data (Deming)

### Automation: Integration With OPERATIONS.md

The session-end hook in OPERATIONS.md §Session Handoff MUST include:

```markdown
## CHARACTER-TRACKING Updates This Session
- Personas active: {list}
- Escalations: {list of from→to with reason}
- Council sessions: {n} (see §2 Session History for details)
- Cost: TALK ${n} | BUILD ${n} | THINK ${n} | Research ${n}
- Tier distribution this session: TALK {n}% | BUILD {n}% | THINK {n}% | Research {n}%
- Next calibration due: {date or "phase boundary"}
```

This block feeds directly into the §4 Weekly Snapshot template and is machine-parseable by a cold-start AI reading the session handoff record.

---

## Related Directives

- → See TEAM.md §3 for full persona profiles, genius bios, and launch prompts
- → See TEAM.md §10 for Council Protocol, convergence mechanisms, and Decision Record template
- → See OPERATIONS.md §AI Cost Tracking for per-session cost ledger (complements §4 here)
- → See OPERATIONS.md §Framework Versioning for how calibration changes become version bumps
- → See ITERATION.md §Circle Detection for the circle log that feeds §5 calibration trigger #4
- → See PHILOSOPHY.md §Deming for the PDSA framework that governs calibration design
- → See QUALITY.md §Completion Loop for the summary.json that auto-populates performance data

---

## Framework Navigation

> **You Are Here:** `CHARACTER-TRACKING.md` — Team performance tracking, calibration, cross-references
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
| OPERATIONS.md | Dev environment, dashboard, MVP tracker, reporting |
| CHARACTER-TRACKING.md | ★ You are here |

> **If lost:** Start at CLAUDE.md. If a concept is unclear, check HANDHOLDING.md §9 Glossary.
> **If stuck:** ITERATION.md §7 Failure Gates (1-fail retry, 2-fail pivot, 3-fail Council).
> **If quality uncertain:** QUALITY.md §1 Gate Runner. If design: DESIGN.md §5 Design Gates.

*CHARACTER-TRACKING.md is a living document. It is updated automatically at session end and reviewed manually at every calibration event. NEVER let it go stale — stale performance data is worse than no data (it produces false confidence in routing rules).*
