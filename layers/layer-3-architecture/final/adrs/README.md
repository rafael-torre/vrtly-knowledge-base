# Architectural Decision Records (ADRs)

The canonical record of significant architectural decisions made for this project. Each ADR captures what was decided, the context that drove the decision, the consequences, and the alternatives that were considered and rejected.

ADRs are the authoritative record for architectural decisions. They do not replace the Architecture Overview or Tech Stack Rationale — those documents summarize the current state. ADRs explain the reasoning and history behind that state.

---

## When to Write an ADR

Write an ADR when a decision meets one or more of these criteria:

- It affects system boundaries, data architecture, infrastructure, or the tech stack
- It involves meaningful trade-offs that future engineers or tech leads need to understand
- It is likely to be revisited or challenged — the rationale needs to survive the people who made it
- It has compliance, security, or operational implications
- It overrides or departs from an established pattern in the codebase or in this framework

For smaller decisions that don't meet these criteria, use the [Decision Log](../../intermediate/_example-decision-log.md) in `intermediate/`.

---

## Conventions

### Numbering

ADRs are numbered sequentially with zero-padded four-digit numbers: `0001`, `0002`, `0003`. Numbers are never reused. If an ADR is superseded, the old one is kept and marked as superseded — a new ADR is created with the next number.

### Naming

File names follow the pattern: `NNNN-short-description.md`

Examples:
- `0001-use-postgres-as-primary-database.md`
- `0002-adopt-nextjs-for-frontend.md`
- `0003-use-event-driven-architecture-for-notifications.md`

The description should be readable without opening the file. Use kebab-case. Aim for 4-7 words.

### Frontmatter

Every ADR carries full YAML frontmatter:

```yaml
---
title: ""
layer: architecture
owner: ""
last_updated: ""
relates_to: []
status: established
adr_status: proposed | accepted | deprecated | superseded
superseded_by: ""
---
```

- `status` — the document status in the cascade framework (use `established` for accepted ADRs)
- `adr_status` — the decision lifecycle status:
  - `proposed` — under discussion, not yet accepted
  - `accepted` — in effect, guiding current work
  - `deprecated` — no longer applicable (context changed, feature removed) but not replaced
  - `superseded` — replaced by a newer ADR; `superseded_by` must be filled in

### Lifecycle

ADRs are **immutable** once accepted. They are never edited to change the decision — only to correct factual errors. If a decision changes, write a new ADR that supersedes the old one. This preserves the history of why things changed.

The only field that changes after acceptance is `adr_status` (when deprecated or superseded) and `superseded_by` (when superseded).

---

## ADR Catalog


| ADR | Title | Status | Owner | Date |
| --- | ----- | ------ | ----- | ---- |
| | | proposed / accepted / deprecated / superseded | | |


---

## Template

See [_example-adr.md](_example-adr.md) for the ADR template.
