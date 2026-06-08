# Skills & Agents Guide

How to use the skills and agent personas available in this knowledge base. Works in both Claude Code and Cursor.

**Invoking a skill:** Type `/skill-name` in your AI session, or describe what you want to do and the companion will suggest the right skill automatically.

---

## How the system works

The knowledge base has two types of tools:

- **Agent personas** — role-specific companions you activate for a working session. Each persona embodies a way of thinking (PM, Analyst, Architect, etc.) and presents a menu of skills it can run.
- **Skills** — focused workflows for a specific task (research, create a spec, review a doc, promote to final, etc.).

**Layer-triggered activation:** When you open a document in a layer, the companion suggests the right persona for that layer. You don't need to remember who to invoke — it surfaces the right one.

**The output rule:** All generative skills write to `intermediate/`. Nothing goes to `final/` directly. Use `skill-promote-to-final` as the single gate.

---

## Agent Personas

Activate a persona for a focused working session. The persona holds context, challenges your thinking in character, and presents its capabilities as a menu.

### Mary — Business Analyst (`/agent-analyst`)
**Activates on:** Layer 0 documents  
**Use when:** Researching the market, competitive landscape, domain context, or early product ideation.  
**Menu:** brainstorm, market research, domain research, technical research, product brief, PRFAQ, document project  
**Thinking style:** Porter's strategic rigor + Minto Pyramid structure. Evidence-grounded, stakeholder-aware.

### John — Product Manager (`/agent-pm`)
**Activates on:** Layer 1 documents  
**Use when:** Writing or refining the product brief, feature specs, or validating product decisions.  
**Menu:** feature spec (product), readiness check, correct course  
**Thinking style:** Jobs-to-be-done over template filling. Short questions, relentless "why?"

### Sally — UX Designer (`/agent-designer`)
**Activates on:** Layer 2 documents  
**Use when:** Planning UX patterns, interaction flows, and design specifications.  
**Menu:** UX spec  
**Thinking style:** Human-centered. Paints user stories before writing specs.

### Winston — System Architect (`/agent-architect`)
**Activates on:** Layer 3 documents  
**Use when:** Making technical architecture decisions, ADRs, reviewing system boundaries.  
**Menu:** create architecture, feature spec (technical), readiness check  
**Thinking style:** Trade-offs, not verdicts. Boring tech for stability. Ties every decision to business value.

### Amelia — Developer (`/agent-developer`)
**Activates on:** Layer 3 feature technical specs + Layer 4 documents  
**Use when:** Writing technical feature specs (stress-testing implementability), Layer 4 implementation guides.  
**Menu:** feature spec (technical review), edge-case review, adversarial review, generate tickets  
**Thinking style:** Test-first discipline. Exact file paths and acceptance criteria. Catches what architects miss.

> Note: Amelia is intentionally active in Layer 3 — she challenges technical PRDs for implementability before architecture is locked. Winston shapes design; Amelia stress-tests it.

### Paige — Technical Writer (`/agent-writer`)
**Activates on:** Any layer (quality gate role)  
**Use when:** Polishing prose, validating document structure, explaining a concept clearly, creating diagrams.  
**Menu:** document project, write document, Mermaid diagram, validate document, explain concept, review prose, review structure  
**Thinking style:** Write for the reader's task. A diagram beats a thousand-word paragraph.

---

## Workflow: Layer by Layer

### Starting a session
```
/scan-project-state
```
Scans all `final/` docs, surfaces anything with `status: needs_review`, `needs_update`, or `in_progress`. Tells you where you are and what's unfinished. Run this at the start of every session.

---

### Layer 0 — Business context

| Goal | Skill |
|---|---|
| Research competitors and market | `/skill-research-market` → output lands in `layer-0-business/intermediate/` |
| Deep-dive a domain or industry | `/skill-research-domain` → same |
| Ideate freely before committing | `/skill-brainstorm` |
| Write the product brief | `/skill-product-brief` → output in `layer-1-product/intermediate/` |
| Challenge a product concept from first principles | `/skill-prfaq` (Working Backwards) |

**Prerequisite to leave Layer 0:** `business-overview.md` and at least one of `competitive-landscape.md` or `strategic-goals-and-constraints.md` should reach `status: consensus` before starting Layer 1 in earnest.

---

### Layer 1 — Product

| Goal | Skill |
|---|---|
| Create or update a product feature spec | `/skill-feature-spec` → output in `layer-1-product/intermediate/features/<domain>/` |
| Define user personas, journeys, success metrics | Use the relevant final doc template + `/skill-review-prose` when ready |
| Challenge assumptions before committing | `/skill-elicitation` (push the AI to reconsider recent output) |
| Check if Layer 1 is complete enough to start Layer 2 | `/skill-readiness-check` |

---

### Layer 2 — Design

| Goal | Skill |
|---|---|
| Plan UX patterns and interaction flows | `/skill-ux-spec` → output in `layer-2-design/intermediate/features/<domain>/` |
| Research technical approach before designing | `/skill-research-technical` |

**Prerequisite:** `product-brief.md` should be `status: consensus` before running `skill-ux-spec`.

---

### Layer 3 — Architecture

| Goal | Skill |
|---|---|
| Create architecture overview / ADR | `/skill-create-architecture` → output in `layer-3-architecture/intermediate/` |
| Write a technical feature spec | `/skill-feature-spec` (technical mode) → output in `layer-3-architecture/intermediate/features/<domain>/` |
| Validate a technical spec for implementability | Activate `/agent-developer` (Amelia), then run `/skill-review-edge-cases` and `/skill-review-adversarial` on the spec |
| Validate all layers are aligned before implementation | `/skill-readiness-check` |
| Generate tickets from a finalized technical spec | `/skill-generate-tickets` (requires board setup in `.companion.yaml`) |

---

### Layer 4 — Implementation

| Goal | Skill |
|---|---|
| Write deployment guide, development guide, monitoring doc | Activate `/agent-developer`, use write-document capability |
| Generate project context for AI consumption | `/skill-generate-context` → creates `project-context.md` (loaded by all agents as persistent context) |

---

## Promoting to Final

When an intermediate document is ready to become a `final/` document:

```
/skill-promote-to-final
```

The skill checks:
1. Upstream layer has at least one `final/` doc at `status: consensus`
2. Editorial review has been run (or runs it for you)
3. Adversarial review has been run (or runs it for you)

Then writes to `final/` with `status: needs_review` and cascades `needs_review` to related docs via `update-metadata.sh`.

**The status lifecycle:**  
`draft` → `needs_review` → `in_progress` → `consensus` → `needs_update` (when a related doc changes)

---

## Quality Gate Skills

Run these on any document before promoting to `final/`. Can be run standalone or invoked automatically by `skill-promote-to-final`.

| Skill | What it does |
|---|---|
| `/skill-review-prose` | Clinical copy-edit — fixes unclear communication, passive voice, ambiguous statements |
| `/skill-review-structure` | Structural edit — cuts, reorganizes, simplifies while preserving comprehension |
| `/skill-review-adversarial` | Cynical adversarial review — treats the document as a target and finds everything wrong with it |
| `/skill-review-edge-cases` | Exhaustive boundary analysis — walks every branching path and reports unhandled cases |
| `/skill-elicitation` | Pushes the AI to reconsider and deepen its most recent output (Socratic, first-principles, pre-mortem, red team) |

Recommended gate for any `final/` doc: **prose review → adversarial review → promote**.  
For technical specs specifically: **edge-case review → adversarial review → promote**.

---

## Ticket Generation

Once a Layer 3 feature technical spec is at `status: consensus`:

```
/skill-generate-tickets
```

The skill reads the technical spec, extracts functional and non-functional requirements, generates tickets with dependencies and separation of concerns, and creates them directly on the configured board. Ticket references are written back into the technical PRD.

**Setup required** — add to `.companion.yaml`:
```yaml
board:
  type: linear   # linear | jira | github | other
  project_id: ""
```

> Board API integration is a TODO — see migration plan.

---

## Utility Skills (available anytime)

| Skill | Use case |
|---|---|
| `/skill-brainstorm` | Structured ideation using creative techniques — good before starting any new document |
| `/skill-roundtable` | Multi-agent discussion — spawn multiple personas to debate a topic and surface diverse perspectives |
| `/skill-spec` | Distill any input (brief, transcript, brain dump) into a precise SPEC contract — locks the WHAT before the HOW |
| `/skill-investigate` | Forensic analysis — trace what a document or system does, build a mental model, surface what's missing |
| `/skill-correct-course` | When a significant pivot happens mid-work — determines what needs to change across layers |
| `/skill-shard-doc` | Split large documents (>500 lines) into organized smaller files |
| `/skill-index-docs` | Generate or update an `index.md` for any folder |
| `/skill-document-project` | Analyze a brownfield project and produce structured documentation |
| `/skill-generate-context` | Scan the project and generate a lean `project-context.md` for AI context loading |
| `/skill-prfaq` | Working Backwards PRFAQ challenge — forge and stress-test a product concept |
| `/skill-customize` | Author or update customization overrides for any skill (TOML override system) |

---

## Collaboration: Roundtable Mode

When you need multiple perspectives on a decision:

```
/skill-roundtable
```

Spawns selected personas as independent subagents — each thinks for itself. A genuine discussion where agents actually disagree. Good for:
- Documents stuck at `needs_review` — get Mary, John, and Winston to argue it out
- Architecture decisions where you want PM, Architect, and Dev perspectives simultaneously
- Any moment where a single perspective feels insufficient

Use `--solo` flag if you want the personas roleplayed in a single response rather than parallel subagents.

---

## Ending a session

```
/session-handoff
```

Writes `.claude/session-handoff.md` capturing: what was decided, what's blocked, and what the next session should start with. Essential when switching context or handing off to another person.

---

## Navigator: What should I do next?

```
/skill-navigator
```

Reads the current state of all layer finals (frontmatter status), understands the workflow graph, and tells you the recommended next step. Use when you're not sure where to pick up.

---

## Cheat Sheet

```
Session start    → /scan-project-state
Ideate           → /skill-brainstorm or /skill-prfaq
Research         → /skill-research-market, /skill-research-domain, /skill-research-technical
Write specs      → /skill-product-brief, /skill-feature-spec, /skill-ux-spec, /skill-create-architecture
Review           → /skill-review-prose → /skill-review-adversarial (→ /skill-review-edge-cases for tech docs)
Promote          → /skill-promote-to-final
Tickets          → /skill-generate-tickets
Debate           → /skill-roundtable
Pivot            → /skill-correct-course
Session end      → /session-handoff
Lost             → /skill-navigator
```
