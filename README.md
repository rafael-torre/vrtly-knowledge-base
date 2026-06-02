# Layered Documentation Framework

A structured approach to documenting software products across the full development lifecycle. Designed for consulting teams that work across multiple clients and tech stacks, where knowledge needs to survive team rotations, client handoffs, and the pressure of delivery.

---

## Why This Exists

Most documentation fails in one of two ways: it never gets written, or it gets written once and rots. Both failures have the same root cause — there is no structure that makes documentation ownable, maintainable, and useful enough to justify the effort.

This framework exists to solve three problems that compound across projects:

**Tribal knowledge doesn't scale.** In a consulting company, teams rotate between clients, new people join mid-project, and projects get handed off. When the only source of truth is "ask the person who was there," every transition is slow and error-prone. Documentation should make any team member productive without requiring someone else's time.

**Documentation rot is a system problem, not a discipline problem.** Telling people to "keep docs updated" doesn't work because there is no clear ownership of what needs updating and no feedback loop. The framework builds these mechanisms in — structured cascade tracking, clear per-document ownership, and metadata that makes staleness visible.

**AI tools are only as good as the context they receive.** Structured, layered documentation serves a dual purpose: it aligns human teams AND feeds AI tools with accurate context for better output. A well-documented project gives AI coding assistants, code review tools, and generation workflows the structured knowledge they need to produce useful results. Good documentation is the foundation of an effective AI strategy.

---

## How It Works

### The Core Idea

Documentation is organized into **five layers**, each owned by a specific role and serving a distinct purpose. Each layer inherits from the layers above it — business context informs product decisions, product decisions inform design, design and product inform architecture, and architecture informs implementation.

Every layer follows the same **refinement pipeline**: raw inputs (gathered, not authored) are synthesized into intermediate artifacts (working documents), which are refined into final documents (the source of truth). Contradictions and ambiguity in raw inputs get resolved during synthesis — the final document reflects the resolved state.

**Final documents are the source of truth.** Raw inputs like meeting transcripts, client emails, and interview notes inform the process but are never canonical. When two raw inputs contradict each other, the resolution is what gets documented in the final document. This means the PM owns resolving ambiguity at the product level, the Tech Lead owns it at the architecture level, and so on — decision-making authority follows layer ownership.

### The Layers

```
Layer 0: Business ──→ Layer 1: Product ──→ Layer 2: Design ──→ Layer 3: Architecture ──→ Layer 4: Implementation
   (PM)                  (PM)              (Designer)           (Tech Lead)                (Dev Team)
```


| Layer                  | Purpose                                                                 | Owner                | Key Outputs                                                                                  | Scope                                              |
| ---------------------- | ----------------------------------------------------------------------- | -------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| **0 — Business**       | Understand the client, their market, goals, and constraints             | PM / Engagement Lead | Business Overview, Strategic Goals, Stakeholder Map, Competitive Landscape                   | Per client — created once, updated rarely          |
| **1 — Product**        | Define the problem space, users, and what we're building                | PM                   | Product Brief, Feature Specs, User Personas, User Journeys, Success Metrics, Domain Glossary | Per project — created during product definition    |
| **2 — Design**         | Define the user experience — screens, behavior, feel                    | Designer             | Design System Reference, Feature Design Specs                                                | Per project — N/A for API-only or backend projects |
| **3 — Architecture**   | Define structural decisions, system boundaries, and technical reasoning | Tech Lead            | Architecture Overview, ADRs, Feature Technical Specs, NFRs, Tech Stack Rationale             | Per project — created after product scope is clear |
| **4 — Implementation** | Enable engineers to contribute and keep the system running              | Dev Team + Tech Lead | Development Guide (mandatory), Deployment Guide, Monitoring & Observability                  | Per project — created once implementation begins   |


Each layer has its own folder under `layers/` with templates, examples, and guidance. See the layer README for details:

- [Layer 0: Business](layers/layer-0-business/)
- [Layer 1: Product](layers/layer-1-product/)
- [Layer 2: Design](layers/layer-2-design/)
- [Layer 3: Architecture](layers/layer-3-architecture/)
- [Layer 4: Implementation & Operations](layers/layer-4-implementation/)

### Cross-Layer Inheritance

The final documents of Layer N are explicit inputs to Layer N+1. This is not implicit — each layer's templates name the upstream documents they depend on, and each document's YAML frontmatter lists its relationships via `relates_to`. This creates a traceable chain from business context to running code.

When an upstream document changes, the owner is responsible for notifying downstream owners so they can review their own documents. The `relates_to` metadata makes these dependencies visible — without it, drift is invisible.

### Layer Independence

Not every project needs every layer. A project may have mature product docs but no operations docs yet. Each layer carries its own status independently. The framework does not require all layers to exist simultaneously — you build the layers you need, in order, as the project matures.

When a layer does not apply (e.g., Design for an API-only project), mark it N/A. The downstream layer takes its inputs directly from the layers above the skipped one.

Layer 0 (Business) is scoped per client engagement and can feed multiple projects. When Layer 0 changes affect multiple projects, the PM notifies each project's Tech Lead.

---

## Document Metadata

Every final document carries YAML frontmatter. This metadata makes ownership, dependencies, and freshness visible across the project.

```yaml
---
title: Architecture Overview
layer: architecture
owner: "@techlead-handle"
last_updated: 2026-04-01
relates_to:
  - docs/product/prd.md
  - docs/product/domain-glossary.md
status: established
---
```


| Field          | Description                                                                                                                                 |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `title`        | Human-readable document title                                                                                                               |
| `layer`        | One of: `business`, `product`, `design`, `architecture`, `implementation`                                                                   |
| `owner`        | GitHub handle of the person accountable for this document                                                                                   |
| `last_updated` | Date of last substantive content update — not formatting or typo fixes. Auto-updated by a pre-commit hook when a final document is modified |
| `relates_to`   | Paths to related **final documents only** — not raw inputs or intermediate artifacts                                                        |
| `status`       | One of: `established`, `in_progress`, `needs_update`                                                                                        |


---

## How Documentation Stays Current

Documentation drifts in two directions. The framework addresses both through ownership and metadata — the `relates_to` field makes dependencies explicit, and the `last_updated` field makes freshness visible.

### Top-Down Drift

A business or product decision changes, and downstream layers don't reflect it. The person making the change knows it happened — the process is human-driven.

**What to do:** When you update a final document, check which documents list yours in their `relates_to`. Notify those owners that something changed. If the change is significant, open a GitHub issue tagging downstream owners. The downstream owner reviews their document and either updates it, confirms no change is needed (updating `last_updated` to re-validate), or marks it `needs_update` if they can't address it immediately.

### Bottom-Up Drift

Code changes make technical documentation outdated. A developer refactors an auth flow, adds environment variables, or changes the deployment pipeline. The developer may not realize documentation is affected.

**What to do:** When making code changes that affect system behavior, architecture, or operational procedures, check whether related documentation needs updating. The `relates_to` fields in your project's documentation show which documents are connected. Update affected docs in the same PR when the change is small, or open a follow-up issue when it's bigger.

---

## Working With the Framework

### Starting a New Project

Follow the layers in order. Not every layer needs to be complete before the next one starts, but the upstream layer should be established enough to inform downstream work.

1. **Layer 0 — Business.** During client onboarding, gather raw inputs and produce the four final documents. This only happens once per client engagement — if the client already has a Layer 0 from a previous project, reuse it.
2. **Layer 1 — Product.** During product definition, use Layer 0 finals as inputs. Start with the Product Brief, then build feature specs as the product takes shape.
3. **Layer 2 — Design.** After feature specs are established and design work begins. Skip this layer for API-only or backend-only projects.
4. **Layer 3 — Architecture.** After product scope is clear. Start with the Architecture Overview, then add feature technical specs as features move into architecture.
5. **Layer 4 — Implementation.** Once the team has begun building and conventions are clear enough to document. Start with the Development Guide (mandatory). Add Deployment and Monitoring docs as the project matures.

### Joining an Existing Project

Check the project's documentation folder to understand what exists and what state it's in. Each layer carries its own status:


| State            | Meaning                                                              |
| ---------------- | -------------------------------------------------------------------- |
| **N/A**          | This layer does not apply to this project                            |
| **Not started**  | Layer applies but no documentation exists yet                        |
| **In progress**  | Raw inputs gathered, synthesis underway, final docs not yet complete |
| **Established**  | Final documents exist and are current                                |
| **Needs update** | Final documents exist but are known to be outdated                   |


Read the established layers top-down to build context: business first, then product, then design (when applicable), then architecture. This gives you the same understanding a team member who was there from the start would have — without needing their time.

### Day-to-Day

**When you update a final document:**

1. Update the content, set `status` to `established`, and update `last_updated` to today's date.
2. Check if any other document lists yours in its `relates_to`. If so, notify that owner.
3. If the change was driven by an upstream change, reference it in the commit message.

**When you change code that affects documented behavior:**

1. Check whether related documentation needs updating — the `relates_to` fields across docs show what's connected.
2. Update affected docs in the same PR when the change is small, or open a follow-up issue.

**When you're notified that an upstream document changed:**

1. Review your document against the upstream change.
2. Update it if needed, re-validate it (update `last_updated` to confirm it's still current), or mark it `needs_update` if you can't address it now.

---

## By Role

Every layer has an **owner** — the person accountable for the layer's documents being created, accurate, and current. Ownership is about accountability, not exclusivity. Anyone can contribute to any layer. A Tech Lead might draft business context during discovery. A developer might write a feature technical spec. A Designer might contribute to product definition. The owner doesn't do all the work — they make sure it gets done and stays current.

### PM / Engagement Lead

**Owns:** Layers 0 and 1.

Layer 0 is created once per client during onboarding — it captures who the client is and what drives their business. Layer 1 is where you define what we're building and why. Your final documents (especially feature specs, the product brief, and the domain glossary) are the primary input for every downstream layer.

Your key responsibility in the cascade: when product decisions change, you assess downstream impact and notify the Tech Lead and Designer (if applicable).

**Common contributions from others:** Tech Leads and Designers often contribute to Layer 0 during discovery (competitive analysis, stakeholder interviews). Engineers may draft or refine feature specs in Layer 1 when they have domain expertise.

Start with: [Layer 0 README](layers/layer-0-business/) → [Layer 1 README](layers/layer-1-product/)

### Designer

**Owns:** Layer 2.

Your inputs come from Layer 1 final documents — feature specs, user personas, and user journeys define what you're designing for. Your outputs (feature design specs and the design system reference) feed into architecture and implementation.

This layer is N/A for API-only, data pipeline, or backend-only projects. When it applies, your documents are a thin complement to Figma — they capture what can't be inferred from the design file itself (states, behavior, responsive rules, accessibility requirements).

**Common contributions from others:** PMs validate scope and acceptance criteria against design specs. Engineers flag feasibility constraints. QA validates accessibility requirements.

Start with: [Layer 2 README](layers/layer-2-design/)

### Tech Lead

**Owns:** Layer 3.

Your inputs come from Layers 0, 1, and 2 (when applicable). You translate product and design intent into a technical blueprint — architecture overview, ADRs, feature technical specs, non-functional requirements, and tech stack rationale.

You also own the cascade health for technical documentation. When upstream documents change (product scope, design specs), you are responsible for reviewing and updating the architecture docs that depend on them.

**Common contributions from others:** Senior engineers draft feature technical specs and ADRs. DevOps contributes to infrastructure decisions and non-functional requirements. Developers surface architectural insights from implementation that refine the architecture docs.

Start with: [Layer 3 README](layers/layer-3-architecture/)

### Engineer

**Contributes to:** Layers 3 and 4.

In Layer 4, the Development Guide is the one mandatory document — it captures how the team actually works: coding conventions, testing strategy, branch workflow, key implementation patterns, and project-specific tooling. This document should make any engineer productive on the project without needing to ask a teammate.

When your code changes affect documented behavior (architecture, deployment process, conventions), update the related docs in the same PR or open a follow-up issue.

Layer 4 is the terminal layer — there is nothing downstream. The Development Guide, Deployment Guide, and Monitoring & Observability document are the final artifacts of the framework.

**Common contributions to other layers:** Engineers frequently draft feature technical specs (Layer 3), write ADRs for decisions they drove, and contribute domain knowledge to feature specs (Layer 1) when they understand the problem space deeply.

Start with: [Layer 4 README](layers/layer-4-implementation/)

### QA

**Contributes to:** every layer, owns none.

Your accountability is ensuring quality gates exist at each layer:


| Layer          | Your Contribution                                                      |
| -------------- | ---------------------------------------------------------------------- |
| Product        | Acceptance criteria on feature specs                                   |
| Design         | Accessibility validation, usability heuristics                         |
| Architecture   | Test strategy, quality attributes in NFRs                              |
| Implementation | Test cases, automation, coverage standards, smoke tests, health checks |


---

## Decision Tracking

Decisions happen at every layer. The format differs but the mechanism is the same: record what was decided, why, what alternatives were considered, and when.


| Layer          | Format                                                       |
| -------------- | ------------------------------------------------------------ |
| Business       | Stakeholder alignment records, engagement-level decisions    |
| Product        | Decision log tied to gap resolution and client conversations |
| Design         | Design rationale (why this pattern over alternatives)        |
| Architecture   | ADRs — formal, numbered, versioned                           |
| Implementation | PR descriptions, code review resolutions, post-mortems       |


Architecture Decision Records (ADRs) are the most structured form and are used for significant technical decisions. See [ADR guidance](layers/layer-3-architecture/final/adrs/) for when and how to write them.

---

## Quick Reference

### Layer Summary

```
Business (L0) → Product (L1) → Design (L2) → Architecture (L3) → Implementation (L4)
  PM              PM            Designer       Tech Lead           Dev Team
  per client      per project   optional       per project         per project
```

### Refinement Pipeline

Every layer: **Raw inputs** (gathered) → **Intermediate artifacts** (synthesized) → **Final documents** (source of truth).

### Cascade Rules

1. When you update a final document, check `relates_to` references and notify downstream owners.
2. When you change code that affects documented behavior, check and update related docs.
3. When notified of an upstream change, review your documents — update, re-validate, or mark `needs_update`.

### Document Statuses


| Status         | Meaning                      |
| -------------- | ---------------------------- |
| `established`  | Current and reviewed         |
| `in_progress`  | Being written or synthesized |
| `needs_update` | Known to be outdated         |


### Frontmatter Template

```yaml
---
title: Document Title
layer: business | product | design | architecture | implementation
owner: "@github-handle"
last_updated: YYYY-MM-DD
relates_to:
  - path/to/related/document.md
status: established | in_progress | needs_update
---
```

