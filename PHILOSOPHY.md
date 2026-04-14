# PHILOSOPHY.md -- Kaizen-Deming-Unix-AI-Native-Parallel Foundation

> **Kaizen (改善)** -- perfection is a direction; measure, improve, measure again.
> **Unix** -- each tool does one thing; compose small sharp tools via clean interfaces.
> **Deming** -- design quality in; measure systems not events; eliminate variation through process.
> **AI-Native** -- design for AI participation from day 0; lock invariants explicitly.
> **Parallel** -- decompose into independent lanes; maximize concurrency; serial-when-parallel is waste.
> NEVER ship a component that violates all five. ALWAYS split or rethink.

> **Persona Ownership:** Aria enforces the five-lens test. Dr. Kai enforces PDSA hypothesis rigor. All team members are subject to these principles. → See CHARACTER-TRACKING.md

---

## The Five Principles

### Kaizen Principles

ALWAYS treat every artifact as improvable -- nothing is ever finished.
ALWAYS compound small, continuous improvements rather than attempting big-bang rewrites.
ALWAYS measure before and after every change; improvement without measurement is guessing.
NEVER skip the feedback loop: produce, analyze, modify, evaluate.
WHEN an iteration produces no measurable improvement, THEN change the approach, not the effort.

### Unix Principles

ALWAYS give each module, agent, and tool a single clear purpose.
ALWAYS compose small units through clean interfaces -- imports, pipes, function calls.
NEVER build monoliths; split until each piece is describable in one sentence.
WHEN a component handles two concerns, THEN extract one into its own module.
ALWAYS prefer composability over convenience.

### Deming Principles

ALWAYS design quality in from the start — NEVER inspect quality in after the fact.
ALWAYS use PDSA (Plan-Do-Study-Act) as the scientific method of software: Plan (hypothesis + acceptance criteria), Do (smallest safe implementation), Study (expected vs. observed, regressions), Act (standardize/revise/rollback).
ALWAYS measure trends and variances across sessions, not just individual pass/fail outcomes.
WHEN a team member (human or AI) repeatedly makes the same mistake, THEN fix the process, not the person.
NEVER accept a regression as "acceptable" without a documented tradeoff and a process change.
ALWAYS write the rollback plan before writing the implementation.

### AI-Native Principles

ALWAYS create `CLAUDE.md` before the first feature. It is a first-class artifact, not documentation afterthought.
ALWAYS include an `## Unbreakable Rules` section that locks invariants AI must not override.
ALWAYS use structured output formats (XML file tags) when AI output will be machine-parsed.
ALWAYS use `.claude/hooks/` to enforce rules that must not depend on AI discretion.
NEVER rely on AI to remember cross-session context — write and read Session Handoff Records.
WHEN an AI subprocess calls another AI, THEN remove `CLAUDECODE` env var and set `stdin=DEVNULL`.

### Parallel Principles

ALWAYS identify independent workstreams before starting sequential work.
ALWAYS decompose into swim lanes at project kickoff.
NEVER block Lane B waiting on Lane A unless there is a genuine data dependency.
ALWAYS fan out to parallel agents for independent tasks.
ALWAYS compose results at sync points, not after every step.
A serial plan that could be parallel is waste (muda in kaizen terms).
WHEN you catch yourself waiting for one thing to finish before starting an unrelated thing, THEN parallelize.

---

## Enforcement Hooks

v5 stated principles aspirationally. v6 makes them enforceable. Every principle has concrete enforcement mechanisms.

### Kaizen Enforcement

- Every pass MUST produce a measurable delta (not just "I worked on it")
- Every session MUST append to the Trend Log (automated via completion loop — → See OPERATIONS.md §Trend Log)
- Every retrospective MUST produce at least 1 framework patch
- Every 3rd session MUST review Trend Log for systemic patterns

### Unix Enforcement

- Every new module MUST pass the one-sentence test before creation (→ See ARCHITECTURE.md §Unix Module Gate)
- Every function >40 lines triggers automatic split review
- Every file >500 lines triggers automatic decomposition review
- Every MAP manifest MUST have provides/requires — no monolith modules (→ See ARCHITECTURE.md §MAP)

### Deming Enforcement

- Every feature MUST have PDSA Plan before DO phase begins (→ See ITERATION.md §PDSA Cycle)
- Every completion loop MUST produce summary.json with variance data (→ See QUALITY.md §Completion Loop)
- Every phase boundary MUST run the Phase Cadence ritual (→ See ITERATION.md §Phase Cadence)
- Rollback drills MUST be run before irreversible deployments (→ See QUALITY.md §Rollback Drills)

### AI-Native Enforcement

- Every project MUST have CLAUDE.md before first feature
- Every cross-session boundary MUST have a handoff record (→ See ITERATION.md §Session Handoff)
- Every hook MUST be in .claude/hooks/, never in AI memory
- Three-tier model MUST be followed: Talk/Think/Build (→ See TEAM.md §Three-Tier AI Model)

### Parallel Enforcement

- Every project with 2+ workstreams MUST have a swim lane DAG (→ See ITERATION.md §Swim Lane Model)
- Council sessions MUST run Phase 1 in parallel (→ See TEAM.md §Parallel Council Invocation)
- Fan-out MUST be used for N independent identical tasks (→ See TEAM.md §Parallel Execution Patterns)
- NEVER sync more often than necessary — sync is overhead

---

## The Five-Lens Test

APPLY this test to every component, feature, and module:

> If a component cannot be described in one sentence (Unix),
> does not improve with each measured iteration (Kaizen),
> lacks a PDSA hypothesis and acceptance criteria (Deming),
> cannot be understood by a cold-start AI agent (AI-Native),
> or runs serially when lanes are independent (Parallel)
> — split it or rethink it.

WHEN a component fails the Unix test, THEN decompose it into smaller units.
WHEN a component fails the Kaizen test, THEN add a measurement loop and iterate.
WHEN a component fails the Deming test, THEN write the PDSA Plan before proceeding.
WHEN a component fails the AI-Native test, THEN fix CLAUDE.md and add session handoffs.
WHEN a component fails the Parallel test, THEN decompose into independent swim lanes.

---

## Activity Matrix

| Domain | Kaizen | Unix | Deming | AI-Native | Parallel |
|--------|--------|------|--------|-----------|----------|
| Architecture | Evolving schemas, self-healing | SRP, layered, one authority per state | ADR for irreversible decisions | CLAUDE.md with Unbreakable Rules | MAP capability wiring enables parallel module development |
| Features | Small incremental ships, never big-bang | Each feature = one independent unit | PDSA vertical slice | Structured output for AI pipelines | Swim lane DAG decomposes features into concurrent lanes |
| Testing | Continuous verification loops | Each test checks one thing | Completion loop with quality gates | Workflow recovery tests; real DBs | Fan-out test writing to parallel TALK agents |
| Iteration | Produce, analyze, modify, evaluate | One objective per pass, no compound goals | PDSA + variance tracking | Session Handoff for cross-session continuity | Parallel passes across independent swim lanes |
| Design | Refine endlessly toward the ideal | Max 3 rule — restraint as design principle | Design gates (5 criteria as quality bar) | Identity Block prevents AI drift | Design review parallelized with implementation |
| Team | Continuous model evaluation + escalation | Each model specializes: Talk/Think/Build | Custom persona learnings | Claude Code as first-class team member | Council seats brief in parallel; fan-out for grunt work |
| Decomposition | Extract smallest viable components; measure reuse | Each SVC passes Module Gate; protocol-first | SVC tiers (Foundation → DevInfra → Domain) | Component Map as structured inventory | Module registry enables parallel extraction across projects |
| Operations | Maintenance cadence drives improvement; AI cost tracking | Each script does one thing | Multi-phase verify pipeline | Claude subprocess pattern; hooks enforce | Thread tracker shows concurrent agent activity |

---

## Principle Relationships

```
Kaizen    — measure and improve every artifact continuously
Unix      — single responsibility, composable, clean interfaces
Deming    — design quality in; PDSA as outer loop; fix process not people
AI-Native — design for AI participation from day 0, lock invariants explicitly
Parallel  — decompose into independent lanes; maximize concurrency
```

The five lenses reinforce each other:
- A **Unix-style** module with a single responsibility is easier for an **AI** to understand and modify.
- A **Kaizen** measurement loop gives AI agents feedback signals to improve on.
- An **AI-native** CLAUDE.md keeps both Kaizen and Unix principles enforced across sessions.
- **Deming's** PDSA cycle structures the outer loop that guides when to ship, when to pivot, and when to rollback.
- **Parallel** decomposition into swim lanes lets Kaizen iterations run concurrently, Deming gates verify in parallel, and AI agents work without blocking each other.

---

## Canonical Definition

This file is the SOLE authority on the five-principle philosophy. Other files MUST weave the principles into their domain-specific directives but MUST NOT redefine the core principles. WHEN a domain file needs philosophical grounding, THEN reference `PHILOSOPHY.md` — never duplicate.

---

## Related Directives

- → See GENESIS.md — bootstrap rituals apply all five principles from project minute zero
- → See ARCHITECTURE.md — structural patterns enforce Unix layering, Kaizen self-healing, MAP composability, and ADR for irreversible decisions
- → See ARCHITECTURE.md §Module Gate — makes the Unix principle enforceable, not just aspirational
- → See DESIGN.md — visual design applies design gates (Deming), identity blocks (Kaizen), and max-3 rule (Unix)
- → See ITERATION.md — PDSA outer loop structures the iteration engine; swim lanes enforce Parallel; phase cadence enforces Deming
- → See QUALITY.md — completion loop automates Deming verification; rollback drills validate plans; health matrix tests composition
- → See TEAM.md — three-tier model applies Unix (each tier does one thing); parallel council invocation applies Parallel

---

## Framework Navigation

> **You Are Here:** `PHILOSOPHY.md` — Five-lens foundation (sole authority on core principles)
> **Core Method:** Kaizen · Deming · Unix · AI-Native · Parallel (defined HERE)

| File | When To Read |
|------|-------------|
| CLAUDE.md | Session start, operating mode routing, unbreakable rules |
| PHILOSOPHY.md | ★ You are here |
| GENESIS.md | New project kickoff, requirements interview, probe/bootstrap |
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
- → See OPERATIONS.md — AI cost tracking applies Kaizen to spending; multi-phase verify applies Deming quality gates
