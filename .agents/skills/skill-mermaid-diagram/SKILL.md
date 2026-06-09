---
name: skill-mermaid-diagram
description: >
  Creates readable Mermaid architecture diagrams for any software system. The number of
  diagrams is determined by the system's complexity — not prescribed upfront. Use when:
  (1) someone asks to build, create, or update an architecture or system overview diagram;
  (2) a Mermaid diagram exists but is described as hard to read or too complex;
  (3) skill-create-architecture needs a diagram section; (4) someone says "diagram this
  system", "draw the architecture", "create a system map", or similar. Works for any
  system type: web apps, APIs, microservices, mobile apps, IoT, data pipelines, SaaS, etc.
---

# Mermaid Architecture Diagram Skill

## Overview

Produce the minimum number of focused, human-readable Mermaid diagrams needed to make a
system legible. The goal is readability — not hitting a view count. A small system may
need 2 views; a large distributed system may need 5 or 6. Always start with a System
Context view, then split the remainder by natural seams until every view fits within the
readability limits. See `references/best-practices.md` for the full rules and anti-patterns.

---

## Workflow

### Step 1 — Gather system information

Before drawing anything, collect:

- **Services / apps** (frontends, backend APIs, workers, mobile/native apps, data pipelines)
- **Infrastructure** (databases, caches, queues, storage, CDN, schedulers)
- **External integrations** (third-party APIs, SaaS tools, billing, notifications)
- **Actors / users** (who interacts with the system and how)
- **Gap services** — components that exist in production but whose internals are unknown (mark ⚠️)

If working from existing documentation (e.g., a tech spike or system map), read those files
first to extract this inventory rather than asking the user to repeat it.

### Step 2 — Assess complexity and decide on views

Count the total components. Use this as a starting point:

| Total components | Starting approach |
|---|---|
| ≤ 12 | 2 views: System Context + one internal view |
| 13–25 | 3 views: System Context + 2 focused internal views |
| 26–40 | 4–5 views: System Context + split by major concern areas |
| > 40 | 5+ views: System Context + one view per bounded subsystem |

These are starting points — adjust based on relationship density. A view with 10 nodes but
20 relationships between them still needs splitting. A view with 14 nodes and 4 clean
relationships is fine as-is.

**Hard readability limits (non-negotiable):**
- Max **15 nodes** per diagram
- Max **8 labelled relationships** per diagram

If drafting a view and it exceeds either limit, split it before proceeding.

### Step 3 — Find the natural seams

Always include a **System Context** view. For the remaining views, look for natural seams:

- Frontend boundary vs. backend boundary
- User-facing API vs. internal/async processing
- One API domain vs. another (microservices)
- Device/native layer vs. server layer
- Data ingestion vs. data serving
- Admin/ops tooling vs. product surface
- Sync (request/response) flows vs. async (queue/event) flows

Name each view after what it actually shows — use the system's own language, not generic labels.

**Examples by system type:**

| System type | Possible view names |
|---|---|
| Web app + API | Context · Frontend + API · Infra + DB |
| SaaS platform | Context · Admin Portal + CMS API · End-user App + Delivery API · Async + Integrations |
| Mobile + backend | Context · Mobile App + Gateway · Core Services + DB · Async + Notifications |
| Microservices | Context · API Gateway + Auth · Domain Services · Data + Messaging |
| IoT platform | Context · Device + Edge API · Cloud Backend + DB · Processing Pipeline |
| Data platform | Context · Ingestion Layer · Processing + Storage · Serving + Consumers |

### Step 4 — Draft each diagram

Apply the rules in `references/best-practices.md`. The non-negotiables:

- Use `flowchart TD` — not `C4Container`, not `graph LR`
- Max **15 nodes** per diagram
- Max **8 labelled relationships** per diagram
- Use `subgraph id["Label"]` to group related nodes visually
- Mark every gap/unknown service with ⚠️ in its label
- Every arrow must carry a short label (protocol, method, or purpose)

### Step 5 — Output format

Place all diagrams in a single markdown file. In a DB90 project, this goes under
`layers/layer-3-architecture/intermediate/system-overview-diagram.md`.

```
# System Overview Diagram: <Product Name>

<one-line description of what these diagrams cover>

---

## View 1 — System Context
<one sentence: what this view shows>
[mermaid diagram]

---

## View 2 — <Your chosen name>
<one sentence>
[mermaid diagram]

---

## View N — <Your chosen name>
<one sentence>
[mermaid diagram]

---

## Gap Services — Needs Follow-up Spike        ← omit if no gaps
[table: Service | Evidence | Priority]

## Notable Architectural Risks                 ← omit if none surfaced
[bulleted list]
```

### Step 6 — Self-check before delivering

Run through `references/best-practices.md` → "Self-check checklist" for every diagram.
If any diagram exceeds 15 nodes or 8 relationships, split it and re-check.

---

## References

- **`references/best-practices.md`** — Full rules, node/relationship limits, anti-patterns,
  labelling conventions, and self-check checklist. Read this before drafting.
