# HANDHOLDING.md — Newcomer Companion & Preemptive Helper System

> **Kaizen** — Every interaction teaches the system to help better; every project makes guidance more precise.
> **Unix** — Each guidance component does one thing: the Guide Panel orients, the Glossary defines, the Helper predicts.
> **Deming** — Measure confusion, not just completion; fix the explanation, not the user.
> **AI-Native** — Guide content is machine-readable; the AI adjusts depth per user experience level.
> **Parallel** — Preemptive detection runs asynchronously; never block the user's workflow to scan for problems.
> The system is always watching your context and ready to help — you are never alone.

> **Persona Ownership:** Aria (THINK) runs preemptive problem detection. Zara (TALK) delivers guide panel content. The Showrunner (P6) champions the user journey. → See CHARACTER-TRACKING.md

---

## §1 Companion Philosophy

Five principles govern how the platform holds a newcomer's hand. These are enforceable design constraints, not aspirational goals.

### 1.1 You Are Never Alone

The system is always watching the user's context and ready to help. Every screen has a Guide Panel. Every form field has a tooltip. Every dead end has a recovery path. A newcomer should never stare at a blank screen wondering "what now?"

**Enforcement**: Every view MUST have a `guideContent` entry. Every interactive element MUST have a `data-guide` attribute. Every screen MUST have a visible "next action" button or prompt.

### 1.2 Explain Before Asking

Every question the system asks is preceded by WHY it matters. Users do not resist questions — they resist unexplained questions. When the system asks "What is your success metric?", it first explains what a success metric is, why it matters, and shows an example.

**Enforcement**: Every interview question MUST include: the question, why it matters, an example answer, and what happens with the answer downstream.

### 1.3 Anticipate Before Failing

AI predicts likely problems and surfaces solutions BEFORE the user encounters them. This is the Preemptive Problem Detection protocol (§3). The system does not wait for failure — it scans for common failure patterns at every step and warns proactively.

**Enforcement**: Every lifecycle phase transition MUST trigger a preemptive scan. Warnings appear in the Guide Panel's "HEADS UP" section, not as blocking dialogs.

### 1.4 Show Don't Tell

Examples and previews over abstract descriptions. When explaining what a "60-Second Probe" is, show a real probe from a past project. When explaining what a good Requirements Brief looks like, show a completed brief. Abstract explanations are always backed by concrete instances.

**Enforcement**: Every Guide Panel entry MUST include at least one concrete example. Framework concepts MUST have real-world analogies.

### 1.5 Progressive Depth

Start simple, reveal complexity only when needed. A newcomer sees Layer 1 explanations (one paragraph). A returning user sees Layer 0 (one sentence tooltip). An expert sees nothing unless they ask. Complexity is opt-in, never imposed.

**Enforcement**: Guide content uses the 3-layer explanation system (§4). The Guide Panel tracks user experience level and adjusts depth automatically.

---

## §2 The Guide Panel

A persistent, always-visible side panel that updates based on current context. This is the primary hand-holding mechanism.

### 2.1 Structure

```
+-----------------------------------------+
| WHERE YOU ARE                            |
| Phase: {current_phase}                   |
| Step {n} of {total} -- "{step_name}"     |
| =========*=================== {pct}%    |
|                                          |
| WHY THIS MATTERS                         |
| {1-2 paragraphs explaining the           |
|  reasoning behind this step}             |
|                                          |
| WHAT GOOD LOOKS LIKE                     |
| {concrete example of a good answer       |
|  or good output for this step}           |
|                                          |
| HEADS UP (preemptive)                    |
| {AI-generated warnings based on          |
|  the user's previous answers and         |
|  common failure patterns}                |
|                                          |
| WHAT'S NEXT                              |
| {preview of the next step and how        |
|  this step feeds into it}                |
|                                          |
| FRAMEWORK CONNECTION                     |
| {link to the relevant .md file and       |
|  section}                                |
|                                          |
| [Expanded] [Compact] [Hidden]            |
+-----------------------------------------+
```

### 2.2 Modes

| Mode | What Shows | Default For | Toggle |
|------|-----------|-------------|--------|
| **Expanded** | All sections — WHERE, WHY, GOOD, HEADS UP, NEXT, FRAMEWORK | First 3 projects | Click "Expanded" or press `E` |
| **Compact** | WHERE YOU ARE + progress bar + HEADS UP only | After 3 completed projects | Click "Compact" or press `C` |
| **Hidden** | Collapsed to a 60px icon rail with a "?" button | Never default — user opt-in only | Click "Hidden" or press `H` |

The mode preference persists per user in localStorage. NEVER default to Hidden — even experts occasionally need orientation.

### 2.3 Content Keys

Every guide entry is keyed by a `(phase, step)` tuple:

```
Guide content key format: {phase}.{step}

Examples:
  interview.S1_VISION
  interview.T3_DATA_MODEL
  probe.RISK_IDENTIFICATION
  bootstrap.GIT_INIT
  iteration.PRODUCE
  council.SCORING
  retrospective.EVIDENCE_GATHERING
  swim_lanes.DAG_DECOMPOSITION
  quality.GATE_G2_UNIT
```

### 2.4 Real-Time Updates

The Guide Panel updates automatically when:
- The user navigates to a different screen
- The user advances to the next step within a workflow
- The AI detects a new preemptive warning
- The user submits an answer that changes the downstream context
- A swim lane advances to its next phase

NEVER require the user to manually refresh the Guide Panel. It is a live, reactive component.

---

## §3 Preemptive Problem Detection

At each lifecycle phase, the AI scans for common failure patterns and surfaces warnings BEFORE the user hits the problem.

### 3.1 Detection Points

| Phase | What the AI Scans | Example Warning |
|-------|-------------------|-----------------|
| **Interview (Strategic)** | Vague answers, compound goals, missing anti-goals, scope signals | "Your vision statement has two goals — this usually leads to scope creep. Can we narrow to one?" |
| **Interview (Tactical)** | Missing integration points, underspecified auth, no deployment target | "You mentioned an external API but didn't specify rate limits — this is the #1 probe failure cause." |
| **Brief Review** | Conflicting answers, probe target not derived from highest risk | "Your probe target tests the UI, but your highest-risk integration point is the payment API." |
| **Probe** | Rate limits, API restrictions, auth complexity, environment issues | "This API has a 100 req/min rate limit — your core flow will hit that at scale." |
| **Research** | Missing prior art, outdated dependencies, license conflicts | "This library hasn't been updated in 14 months — consider alternatives." |
| **Bootstrap** | Missing .gitignore entries, no test harness, CLAUDE.md gaps | "No .gitignore for .env files detected — secrets could leak." |
| **Swim Lane Planning** | Circular dependencies, single-lane bottleneck, missing sync points | "Lane 3 depends on Lane 1 AND Lane 2, but there's no sync point defined — this will cause merge conflicts." |
| **Iteration** | Repeated symptoms, compound objectives, identity drift, circle forming | "You've attempted 2 fixes for the same symptom — this is a Type 2 circle forming." |
| **Council** | Insufficient options, missing dissent, single-model bias, groupthink | "All 5 seats converged instantly — this may indicate groupthink. Consider a Devil's Advocate pass." |
| **Quality Gates** | Skipped gates, silent failures, degrading trend log | "G2 has failed 3 times this session — the test suite may have a systemic issue, not individual failures." |
| **Retrospective** | Missing evidence, incomplete circle analysis | "3 circles were logged but only 1 was analyzed — the other 2 may contain framework improvements." |

### 3.2 Warning Severity

| Severity | Visual | Behavior |
|----------|--------|----------|
| **Info** | Blue border | Displayed in Guide Panel, does not block progress |
| **Caution** | Yellow border | Displayed prominently, optional acknowledgment |
| **Critical** | Red border | Displayed as a banner, requires acknowledgment before proceeding |

### 3.3 Warning Format

```
PREEMPTIVE WARNING

Severity: INFO | CAUTION | CRITICAL
Phase: {current phase}
Trigger: {what the AI detected}
Warning: {plain-language explanation of the potential problem}
Suggestion: {what the user can do about it}
Framework Reference: {link to relevant protocol}
```

### 3.4 AI Implementation

Preemptive detection runs as a background AI call (TALK tier — cheap and fast) after every significant user action. The AI receives:
1. The current phase and step
2. All previous answers and context
3. The detection rules for this phase (from §3.1)
4. The project's circle log (if any)
5. The current swim lane state (if applicable)

The AI returns zero or more warnings, each with severity and suggestion.

NEVER block the user's workflow to run detection. Detection is asynchronous — the user can continue working while the AI scans. (Parallel principle: preemptive scan runs alongside user's work.)

---

## §4 Contextual Explanations (3-Layer System)

Every framework concept has three layers of explanation, each progressively deeper.

### 4.1 Layer Definitions

| Layer | Name | Length | When Shown | Example: "60-Second Probe" |
|-------|------|--------|-----------|---------------------------|
| **Layer 0** | Tooltip | 1 sentence | Hover/tap on a framework term | "A probe tests your riskiest assumption in under 60 seconds." |
| **Layer 1** | Guide Panel | 1 paragraph | Visible in Guide Panel's "WHY THIS MATTERS" | "The 60-Second Probe is a single-file test that validates the ONE thing that would kill your project if it fails. You write the simplest possible test — no frameworks, no architecture — and run it. If it passes, you've proven the concept is viable. If it fails, you've saved yourself hours of wasted work." |
| **Layer 2** | Deep Dive | Full section | Clicking "Tell me more" | The complete GENESIS.md §1 section with probe templates, examples, and rules. |

### 4.2 Term Registry

Every framework term is registered with all three layers:

```
TERM REGISTRY ENTRY

Term: {display name}
Aliases: {alternative names}
Layer 0: {1-sentence tooltip}
Layer 1: {1-paragraph explanation}
Layer 2 Source: {file.md §section}
Real-World Analogy: {familiar comparison}
Example From Project: {from a real project}
```

### 4.3 Depth Adaptation

| User Level | Criteria | Default Layer | Guide Panel Mode |
|-----------|----------|---------------|-----------------|
| **Newcomer** | 0 completed projects | Layer 1 | Expanded |
| **Intermediate** | 1-2 completed projects | Layer 0, Layer 1 on click | Compact |
| **Expert** | 3+ completed projects | Layer 0 tooltips only | Compact (user may choose Hidden) |

NEVER strip out explanations entirely. Even experts encounter unfamiliar concepts when the framework evolves.

---

## §5 Conversational Guidance

The Requirements Interview is a conversation, not a form.

### 5.1 One Question at a Time

The AI asks ONE question per message. After the user answers, the AI either:
1. **Confirms** — answer is clear and sufficient → moves to next question
2. **Clarifies** — answer is vague → asks a follow-up
3. **Redirects** — misunderstanding revealed → re-explains and re-asks

NEVER present multiple questions in a single message. NEVER advance past a vague answer without attempting clarification.

### 5.2 Question Anatomy

Every interview question message includes four components:

```
[QUESTION]: The actual question text
[WHY]: Why this question matters (1-2 sentences)
[EXAMPLE]: An example of a good answer
[DOWNSTREAM]: What happens with this answer (where it feeds)
```

### 5.3 The "I Don't Know" Protocol

When a user says "I don't know" or gives an equivalent signal:

1. **Acknowledge** — "That's completely fine. Let's think through it together."
2. **Reframe** — Ask the same question from a different angle or break into smaller parts
3. **Offer frameworks** — Provide 2-3 concrete options to choose from
4. **Allow deferral** — Mark the question as "needs revisit" and continue, but ALWAYS come back

NEVER just skip a question. NEVER make the user feel bad for not knowing.

### 5.4 Follow-Up Intelligence

The AI analyzes each answer for:
- **Compound answers** — two goals → "Which one is the primary?"
- **Vague language** — "make it better" → "What does 'better' mean in this context?"
- **Contradictions** — conflicts with previous answer → "In S2 you said X, but now Y. Which takes priority?"
- **Scope signals** — "and also", "plus" → "Should this be a separate project or a later phase?"

### 5.5 Conversation Tone

The AI acts as a **mentor**, not an interrogator:
- Warm and encouraging: "Great answer. That gives us a clear picture."
- Connected: "Now that we know your user, let's talk about what they need."
- Honest: "This is a hard question, but it's the most important one."
- Never condescending: Avoid "As I mentioned before" or "Obviously."

---

## §6 Visual Progress & Journey Map

A persistent progress indicator showing ALL lifecycle phases.

### 6.1 Journey Map Structure

```
INTERVIEW -> BRIEF -> PROBE -> RESEARCH -> BOOTSTRAP -> COUNCIL -> SWIM LANES -> ITERATION -> DONE -> RETROSPECTIVE
    *          o        o         o            o           o           o             o          o          o
  30%
```

- **Filled (*)** — Current phase
- **Check (v)** — Completed phase
- **Empty (o)** — Upcoming phase

### 6.2 Time Estimates

| Phase | Weekend Hack | Month-Long Build |
|-------|-------------|-----------------|
| Interview | 5-10 min | 15-30 min |
| Brief Review | 2-5 min | 5-10 min |
| Probe | 1-5 min | 5-15 min |
| Research | 5-10 min | 15-30 min |
| Bootstrap | 10-20 min | 30-60 min |
| Council | 5-15 min | 15-30 min |
| Swim Lanes | 5-10 min | 15-30 min |
| Iteration | Ongoing | Ongoing |

---

## §7 Recovery & Forgiveness

Every action is undoable. Every mistake is recoverable.

### 7.1 Undo Protocol

| Action | Undo Mechanism | Time Limit |
|--------|---------------|-----------|
| Interview answer | Edit previous answer | No limit |
| Brief field edit | Revert to AI-generated value | No limit |
| Phase advancement | "Go Back" button | No limit |
| Pass outcome | Change outcome on any past pass | No limit |
| Circle resolution | Re-open a resolved circle | No limit |
| Swim lane reorganization | Revert to previous DAG | No limit |
| Project deletion | Soft delete with 30-day recovery | 30 days |

### 7.2 Downstream Adjustment

When a user changes an earlier answer, the system identifies affected downstream artifacts and offers to update them:

```
"You changed your target user from 'developers' to 'designers.'
This affects:
  - Probe target (may need to test design tool integration instead)
  - Council agenda item #2 (UI framework choice)
  - Team composition (Visual QA becomes more important)
  - Swim lane DAG (may need a dedicated Design lane)

Would you like me to update these?"
```

### 7.3 Session Persistence

If the user leaves mid-process:
- All progress is auto-saved
- On return, the system resumes from the exact point
- A welcome-back message explains what happened

NEVER lose user progress. NEVER require re-entering information.

---

## §8 Anti-Abandonment Protocol

Projects fail when users get stuck, lose momentum, or forget. The system actively prevents abandonment.

### 8.1 Stale Project Detection

| Trigger | Threshold | Action |
|---------|----------|--------|
| Project untouched | 3 days | Nudge: "Your project {name} is waiting. Ready to continue?" |
| Same step too long | 10+ minutes | Offer: "Looks like you might be stuck on {step}. Want some help?" |
| Multiple failed passes | 3+ consecutive | Circle detection + guide: "You might be in a Type 2 circle." |
| Interview abandoned | Left during interview | On return: "You started {name}. Want to continue from {question}?" |
| Swim lane stalled | One lane blocked 2+ sessions | Alert: "Lane {N} has been blocked since {date}. The blocker is {dependency}." |

### 8.2 Nudge Tone

Nudges are NEVER guilt-inducing:
- Warm: "Your project misses you"
- Helpful: "I've been thinking about your project and have some ideas"
- Low-pressure: "No rush — just wanted to let you know where you left off"

### 8.3 Stuck Detection

When a user appears stuck (same step, no progress, repeated actions):
1. Offer a simpler explanation of the current step
2. Show a worked example from a similar project
3. Offer to break the step into smaller sub-steps
4. Suggest skipping and coming back later (with a reminder)
5. Offer free-form conversation about what's blocking them

NEVER assume the user is confused. Only intervene after threshold (10 minutes of no meaningful action).

---

## §9 Glossary & Framework Dictionary

Every framework term has a structured definition accessible via hover/click.

### 9.1 Core Terms

| Term | Plain English | Analogy |
|------|-------------|---------|
| **Kaizen (改善)** | Continuous small improvements that compound | Cleaning your desk a little each day vs. one massive spring cleaning |
| **PDSA Cycle** | Plan, build, check, decide | A scientist's experiment: hypothesis -> test -> analyze -> conclude |
| **Pass** | One focused attempt at one specific goal | One rep at the gym — do it, check form, adjust, repeat |
| **Circle** | A pattern of wasted effort | Walking in circles in a forest — you think you're moving forward |
| **Type 1 Circle** | Re-discussing a decided question | Debating where to eat after you already ordered food |
| **Type 2 Circle** | Trying the same fix repeatedly | Turning the key harder when the lock is broken |
| **Type 3 Circle** | Adding and removing the same feature | Packing and unpacking the same suitcase item |
| **Probe** | Quick test of the riskiest assumption | Tasting a dish before serving it to guests |
| **Requirements Brief** | Structured summary of what and why | A project's birth certificate |
| **Council** | Multiple AI models debating a decision | A board of directors with different expertise |
| **Identity Block** | Design elements that must NOT change | The walls of your house — repaint, but don't move them |
| **Swim Lane** | An independent workstream that runs in parallel | Lanes in a swimming pool — each swimmer goes at their own pace |
| **Sync Point** | Where parallel lanes must converge | A relay race handoff — runners must meet at the same spot |
| **Design Gate** | An aesthetic quality bar for UI work | A restaurant health inspection — you pass or you don't open |
| **Completion Loop** | Automated verify-fix-verify cycle | A spell checker that keeps running until no errors remain |
| **Three-Tier AI** | Talk (cheap), Think (deep), Build (code) | Intern, director, and senior engineer on the same team |
| **MAP** | Module contract: what I provide, what I need | A power outlet standard — any plug that fits works |
| **Retrospective** | Structured review of what worked and didn't | Sports team watching game film after the season |
| **ADR** | Recorded architectural decision with context | A legal contract — documents what was agreed |
| **Anti-Goal** | Something the project explicitly will NOT do | A restaurant's "no takeout" policy |
| **Vertical Slice** | One complete feature end-to-end | Baking one perfect cupcake before making a batch |
| **Session Handoff** | Note explaining where you stopped | A nurse's shift change report |
| **Rollback Drill** | Testing your undo plan before you need it | A fire drill — practice before the real emergency |
| **Health Matrix** | Test modules alone AND together | Testing each instrument AND the whole orchestra |

### 9.2 UI Integration

Framework terms appear throughout the UI in **bold with a dotted underline**. Hovering shows the Layer 0 tooltip. Clicking opens a popover with the full glossary entry.

NEVER use a framework term without making it hoverable/clickable. If a term appears in the UI, it MUST be in the glossary.

---

## Related Directives

- → See GENESIS.md §Interview — the interview that conversational guidance (§5) wraps
- → See ITERATION.md §Circle Detection — circles that preemptive detection (§3) monitors for
- → See ITERATION.md §Swim Lane Model — swim lane state that the Guide Panel tracks
- → See ITERATION.md §Pass Loop — the pass loop that the Guide Panel tracks
- → See QUALITY.md §Verification Gates — gates that preemptive detection scans
- → See DESIGN.md — visual design system for Guide Panel styling and tooltip patterns
- → See TEAM.md §Council Protocol — council process that §4 explains to newcomers
- → See PHILOSOPHY.md — the five-lens test that underpins all framework concepts

---

## Framework Navigation

> **You Are Here:** `HANDHOLDING.md` — Newcomer companion: preemptive help, guide panel, glossary
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
| HANDHOLDING.md | ★ You are here |
| OPERATIONS.md | Dev environment, dashboard, MVP tracker, reporting |
| CHARACTER-TRACKING.md | Team performance, calibration, persona metrics |

> **If lost:** Start at CLAUDE.md. If a concept is unclear, check HANDHOLDING.md §9 Glossary.
> **If stuck:** ITERATION.md §7 Failure Gates (1-fail retry, 2-fail pivot, 3-fail Council).
> **If quality uncertain:** QUALITY.md §1 Gate Runner. If design: DESIGN.md §5 Design Gates.
