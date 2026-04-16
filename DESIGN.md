# DESIGN.md -- Visual Identity Framework & Design Gate System

> **Kaizen** -- Refine endlessly toward the ideal; every pass improves visual fidelity.
> **Unix** -- Max 3 rule (restraint as design); each color has ONE meaning; each component does one thing.
> **Deming** -- Design gates as quality bars; measure comprehension speed, not just aesthetics.
> **AI-Native** -- Identity Block prevents AI drift; design philosophy formula is machine-readable.
> **Parallel** -- Design review runs parallel with implementation; gate checks don't serialize lanes.
> Every pixel earns its place. Measure, refine, measure.

> **Persona Ownership:** The Aesthete (P1, Amanda Askell) leads design gate reviews. Marcus implements components. Pixel provides visual diff data. → See CHARACTER-TRACKING.md

---

## 1. Design Philosophy Formula

ALWAYS write the philosophy statement before writing a single line of CSS. If you cannot articulate it in one paragraph, you do not yet understand what you are building.

```
[Aesthetic] + [Principle] + [Constraint] = [Identity]
```

| Project | Aesthetic | Principle | Constraint | Identity |
|---------|-----------|-----------|------------|----------|
| JackWriter | Japanese night palette | Calm focus | No bright colors during writing | The midnight study |
| PredictoCoin | Financial precision | Data density without clutter | No decorative elements near numbers | The confident dashboard |
| PodBot | Beverly Hills Superflat | Warm, playful, Murakami-inspired | Dark/bright as equal moods | The podcast companion |
| Simpod | Clean-minimal | "It just works" + aesthetic restraint | Fewest taps, no decorative waste | The invisible player |

WHEN starting a new project with UI, THEN define the Design Philosophy Formula at Council Session #1 and record it in CLAUDE.md. The formula IS the design's PDSA hypothesis.

---

## 2. Identity System

### 2.1 What to Lock (Identity Block)

Some things MUST NOT change across iterations. Lock them down explicitly.

| Category | Examples | Why |
|----------|----------|-----|
| Core layout | Header height, sidebar width, main content grid | Prevents layout drift |
| Color palette | Primary, secondary, background, text (CSS custom properties) | Prevents AI from "improving" colors |
| Typography | Font family, base size, scale ratio | Type changes cascade through every element |
| Brand elements | Logo, icon set, illustration style | Defines recognition |
| API contracts | Endpoint paths, request/response schemas | Breaking changes cascade to all clients |
| Data models | Table names, column types | Changing these requires migrations |

### 2.2 Identity Block Template

Document at the top of every iteration session:

```markdown
## Identity Block (LOCKED)

DO NOT MODIFY these elements. Carry them unchanged across all passes.

### Layout
- Header: {height} fixed, full width
- Sidebar: {width}, collapsible to {collapsed_width}
- Main content: flex-grow, {padding}

### Colors (CSS custom properties)
- --color-bg: {hex}
- --color-surface: {hex}
- --color-primary: {hex}
- --color-text: {hex}

### Typography
- Display: {font}, {weight}
- Body: {font}, {weight}
- Scale: {scale_steps}

### API Contract (if applicable)
- {method} {path} -> {response_shape}
```

### 2.3 Preventing Identity Drift

Identity drift = small, unrequested changes that accumulate until the artifact is unrecognizable.

```
Pass P01: "Fix the card shadow"
  -> AI also changes border-radius from 8px to 12px (NOT REQUESTED)

Pass P02: "Add loading spinner"
  -> AI changes primary color from pink to indigo (NOT REQUESTED)

After 10 passes: "Why does the app look completely different?"
```

The Identity Block prevents this by making locked properties explicit. ALWAYS check the Identity Block after each pass. If any locked property changed without a dedicated unlock pass, REVERT immediately.

### 2.4 When to Unlock

An identity element MUST only be unlocked when:
1. A deliberate design decision is made (not a side effect)
2. The change is its own dedicated pass with the identity change as the sole objective
3. Impact is assessed across the entire system before the change
4. The old value and new value are documented
5. The Identity Block document is updated

---

## 3. Color System Framework

### 3.1 Color Meaning Map

EVERY project must define a color meaning map. Each color has ONE primary semantic. NEVER deviate.

```
TEMPLATE — fill per project:
- {Color 1} = {primary semantic} (e.g., Pink = primary action / generation)
- {Color 2} = {primary semantic} (e.g., Blue = composition / structure)
- {Color 3} = {primary semantic} (e.g., Green = success / tracking)
- {Color 4} = {primary semantic} (e.g., Yellow = warning / caution)
- {Color 5} = {primary semantic} (e.g., Red = error / danger ONLY)
```

NEVER reuse a color for two semantic purposes. If `--color-accent` means "interactive element," it MUST NOT also mean "decorative border."

### 3.2 Dark and Bright Mode Tokens

ALWAYS define both modes as equal citizens — not "light + dark variant."

```
DARK MODE TOKENS                          BRIGHT MODE TOKENS
--bg:         {deep background}           --bg:         {light background}
--surface:    {card/panel surface}        --surface:    {card/panel surface}
--card:       {input/card bg}             --card:       {input/card bg}
--text:       {primary text}              --text:       {primary text}
--muted:      {secondary text}            --muted:      {secondary text}
--border:     {subtle border}             --border:     {subtle border}
--shadow-sm:  {card shadow}               --shadow-sm:  {card shadow}
--shadow-md:  {elevated shadow}           --shadow-md:  {elevated shadow}
```

### 3.3 The Max-3 Rule

NEVER exceed 3 of any design element category:
- Max 3 accent colors (beyond bg/surface/text)
- Max 3 font weights
- Max 3 border radii
- Max 3 shadow depths
- Max 3 spacing scale jumps between adjacent elements

WHEN you need a 4th, THEN one of the existing 3 is wrong — replace, don't add.

---

## 4. Component System

### 4.1 Component Anatomy

Every UI component follows this structure:

```
COMPONENT: {name}
PURPOSE:   {one sentence — unix test}
STATES:    default, hover, active, disabled, loading, error, empty
VARIANTS:  {list variants — each variant is one prop change}
SLOTS:     {composable insertion points}
LOCKED:    {which properties are in the Identity Block}
```

### 4.2 Component Rules

1. **One purpose** — a component that does two things is two components
2. **Composable** — slots over hard-coded children
3. **State-complete** — every component handles all 7 states (default, hover, active, disabled, loading, error, empty)
4. **Accessible** — keyboard navigable, ARIA labels, contrast ratios
5. **Responsive** — works at 320px, 768px, and 1440px minimum

---

## 5. Design Gate Protocol

Design gates are quality bars for UI work. Derived from PodBot's "Steve" aesthetic review system, generalized for any project.

### 5.1 Gate Criteria

Five criteria for every UI phase:

| # | Criterion | Question | Measure |
|---|-----------|----------|---------|
| 1 | **GLANCEABLE** | Can the user understand the screen in <2 seconds? | Comprehension speed |
| 2 | **PHYSICAL** | Does the interaction have momentum, snap, weight? | Tactile feel |
| 3 | **DELIGHTFUL** | Is there a moment of "oh that's nice"? | Emotional response |
| 4 | **MINIMAL** | Does every element earn its place? (kaizen: no waste) | Element necessity |
| 5 | **UNIX** | Does this component do one thing and compose with others? | Single responsibility |

### 5.2 Gate Outcomes

| Outcome | Meaning | Action |
|---------|---------|--------|
| `pass` | Meets all criteria | Advance to next phase |
| `warn` | Meets most, concern on 1-2 | Proceed with noted concern, revisit if it compounds |
| `fail` | Fails 2+ criteria | Stop, revise, rebuild before advancing |
| `preempt` | Critical issue found | Fix before ANY further work |

### 5.3 When to Run Design Gates

- End of every UI phase in the swim lane
- Before any UI merge to main
- After any design system change
- After any Identity Block unlock

### 5.4 Design Gate Persona (Optional)

Projects with significant UI may define a design gate persona — a named reviewer with calibrated taste.

```markdown
## {PersonaName} — Design Gate Reviewer

### Criteria Weights (project-specific)
1. Glanceable: {weight 1-3}
2. Physical: {weight 1-3}
3. Delightful: {weight 1-3}
4. Minimal: {weight 1-3}
5. Unix: {weight 1-3}

### Voice
- {tone — e.g., "Direct, opinionated, allergic to clutter"}

### Known Biases (calibrate against)
- {e.g., "Tends to prefer minimal over delightful — ensure delight isn't sacrificed"}
```

Store persona documents as `{PersonaName}.md` in the project root. Reference in CLAUDE.md under `## AI Personas`.

### 5.5 Simpod Design Gate Reviewers

Simpod uses two review lenses for all UI/UX changes. Both must pass before implementation proceeds.

**Steve Jobs Lens** — Minimalism, "it just works", fewer taps
- Would Steve ship this? If the user needs instructions, it's wrong.
- Every tap must earn its place. If a two-tap flow can be one tap, it must be one tap.
- Complexity is the enemy. Remove until it breaks, then add one thing back.

**Murakami Lens** — Aesthetic restraint, emotional clarity
- Does the visual language evoke the right emotion without clutter?
- Is there warmth and personality without sacrificing function?
- Dark and light modes are equal citizens — neither is an afterthought.

**Process:** Before implementing any UI change, describe the change and evaluate it against both lenses. If either lens rejects, revise the design before writing code. Log the review verdict in the pass record.

---

## 6. Beverly Hills Superflat (Project Template)

This is the DEFAULT aesthetic template for Michael's projects. Use it unless Council #1 decides otherwise.

**Philosophy**: Flat, bold, chromatic. Warm and playful. Inspired by Takashi Murakami's art, LV x Murakami collections, and kawaii culture. Dark and bright modes are equal citizens.

### Accent Palette

| Name | Hex | ONE Meaning |
|------|-----|-------------|
| Pink | `#FF6B8A` | Primary action, generation |
| Blue | `#5BB5F5` | Composition, structure |
| Green | `#6BCB77` | Success, logging, tracking |
| Yellow | `#FFD93D` | Warning, caution |
| Purple | `#B97CF5` | Research, discovery |
| Orange | `#FF8C42` | Help, reference |
| Red | `#E53935` | Error, danger ONLY |
| Teal | `#4ECDC4` | Secondary, decorative |

### Dark Mode

| Token | Value | Use |
|-------|-------|-----|
| `--bg` | `#121016` | Page background (deep warm) |
| `--surface` | `#1A171F` | Panel / card surface |
| `--card` | `#221F28` | Input / card bg |
| `--text` | `#F0ECE8` | Primary text (warm light) |
| `--muted` | `#8A8494` | Secondary / hint text |
| `--border` | `rgba(255,255,255,0.08)` | Subtle borders |

### Bright Mode

| Token | Value | Use |
|-------|-------|-----|
| `--bg` | `#F5F0FF` | Page background (whisper lavender) |
| `--surface` | `#FFF0F5` | Panel / card surface (whisper pink) |
| `--card` | `#FFFFFF` | Input / card bg |
| `--text` | `#2A2035` | Primary text (warm dark) |
| `--muted` | `#7A7286` | Secondary / hint text |
| `--border` | `rgba(42,32,53,0.10)` | Subtle borders |

### Typography

| Role | Font | Weight | Use |
|------|------|--------|-----|
| Display | Quicksand | 600 | Headings, titles |
| Body | Nunito | 400 | Body text, descriptions |
| Mono | JetBrains Mono | 400 | Code, IDs, timestamps |

---

## 7. Anti-Patterns

| Anti-Pattern | Symptom | Fix |
|--------------|---------|-----|
| Rainbow explosion | >3 accent colors on one screen | Apply max-3 rule; pick primary + secondary + highlight |
| Drift by accumulation | Every pass changes one "small thing" | Identity Block; revert unrequested changes |
| Decoration over function | Elements that look nice but confuse | Every element must answer "what can the user DO with this?" |
| Inconsistent spacing | 8px here, 12px there, 16px elsewhere | Define 3-step spacing scale; apply globally |
| Missing states | Component works in default but breaks on empty/error | State-complete rule: all 7 states for every component |
| Dark mode afterthought | Light mode designed first, dark "inverted" | Design both simultaneously; they are equal citizens |

---

## Related Directives

- → See ITERATION.md §Identity Blocks — how identity is enforced across passes
- → See QUALITY.md §Design Gates — integration of design gates into the verification pipeline
- → See GENESIS.md §Council Session #1 — where the Design Philosophy Formula is decided
- → See TEAM.md §Design Gate Persona — optional persona selection for UI projects

---

## Framework Navigation

> **You Are Here:** `DESIGN.md` — Visual identity framework, design gates, component system
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
| DESIGN.md | ★ You are here |
| HANDHOLDING.md | Newcomer guidance, glossary, preemptive help |
| OPERATIONS.md | Dev environment, dashboard, MVP tracker, reporting |
| CHARACTER-TRACKING.md | Team performance, calibration, persona metrics |

> **If lost:** Start at CLAUDE.md. If a concept is unclear, check HANDHOLDING.md §9 Glossary.
> **If stuck:** ITERATION.md §7 Failure Gates (1-fail retry, 2-fail pivot, 3-fail Council).
> **If quality uncertain:** QUALITY.md §1 Gate Runner. If design: DESIGN.md §5 Design Gates.
- → See PHILOSOPHY.md — the max-3 rule is Unix's restraint principle applied to design
