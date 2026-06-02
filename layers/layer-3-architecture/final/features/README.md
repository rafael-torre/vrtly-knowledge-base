# Feature Technical Spec Catalog — Layer 3: Architecture

The index of all Feature Technical Specs. Each feature has a single file that covers the full-stack technical specification — backend, frontend, and integration — so that engineers across all surfaces have everything they need in one place, and so that work breakdown and ticket creation consider the complete implementation scope.

---

## Conventions

### Alignment with Layer 1 and Layer 2

Feature Technical Specs mirror the Layer 1 feature structure exactly — same domain directories, same filenames. This makes the cross-layer relationship unambiguous without a mapping document.

```
Layer 1 features/           Layer 2 features/           Layer 3 features/
├── auth/                   ├── auth/                   ├── auth/
│   ├── user-registration.md│   ├── user-registration.md│   ├── user-registration.md
│   └── password-reset.md   │   └── password-reset.md   │   └── password-reset.md
├── commerce/               ├── commerce/               ├── commerce/
│   └── checkout.md         │   └── checkout.md         │   └── checkout.md
```

Do not introduce new domains in Layer 3 — if a feature needs a domain, add it to Layer 1 first.

### Frontmatter

Every Feature Technical Spec carries full YAML frontmatter. The `relates_to` field **must** include the path to the corresponding Layer 1 feature spec. Include the Layer 2 feature design spec when it exists. Include the Architecture Overview — every spec is written against it.

```yaml
relates_to:
  - layers/layer-1-product/final/features/[domain]/[feature].md
  - layers/layer-2-design/final/features/[domain]/[feature].md  # when applicable
  - layers/layer-3-architecture/final/architecture-overview.md
```

This is what enables cascade tracking — when a Layer 1 feature spec or Layer 2 design spec changes, the Feature Technical Spec is flagged for review.

### When a Feature Technical Spec Is Not Needed

Not every Layer 1 feature requires a Feature Technical Spec. Skip it when:

- The feature is pure UI — no new components, no state management changes, no API changes, and the implementation is entirely guided by the design system and the Layer 2 design spec
- The feature has no architectural complexity and the implementation is straightforward from the Layer 1 spec alone

When a feature is skipped, note it in the catalog table below with a brief explanation.

### Skippable Sections

The template has sections that do not apply to every feature. Each section carries a "Skip this section if..." note. Common skip patterns:

- **Data Model** — skip for features with no data persistence changes
- **API Contracts** — skip for features that introduce no new or modified APIs
- **Frontend Architecture** — skip for backend-only features (background jobs, data pipelines, API-only endpoints)
- **Integration Points** — skip for features with no external or internal service dependencies

---

## How to Create a Feature Technical Spec

Feature Technical Specs are created in two phases, each supported by an AI skill (see [tools/README.md](../../tools/README.md)):

### Phase 1 — Draft

**Input:** Layer 1 Feature Spec + Layer 2 Feature Design Spec (when applicable) + Architecture Overview

**Output:** Feature Technical Spec with `status: in_progress` in `final/features/[domain]/[feature].md`

Run the **Feature Technical Spec Drafting Skill** or write manually. This phase works entirely from documentation — no codebase access is needed. The draft captures the technical approach, design decisions, data model intent, API contracts, frontend architecture decisions, key flows, and a rough work breakdown. Codebase-specific details (actual file paths, current schema fields, existing component names) are left as guiding prompts.

**Tech lead reviews** the draft for directional correctness before proceeding to Phase 2.

### Phase 2 — Enrich

**Input:** In-progress Feature Technical Spec + one or more code repositories

**Output:** Same file updated with actual code references, current state, concrete schemas, real component paths, and a finalized work breakdown

Run the **Codebase Enrichment Skill** against each relevant repository. For multi-repo setups (separate frontend and backend repos, microservices), run the skill once per repo scoped to the sections it owns — the backend repo enriches Data Model, API Contracts, and Integration Points; the frontend repo enriches Frontend Architecture. All passes update the same spec file.

This skill also handles **change-driven enrichment** — if an upstream doc changes and the spec needs re-grounding, re-run the skill against the updated context.

Tech lead reviews the enriched spec and marks `status: established` when complete.

### Phase 3 — Ticket

**Input:** Established Feature Technical Spec

**Output:** Tickets created in the project management tool; Work Breakdown Reference column updated with links

Run the **Ticket Creation Skill**. It reads the Work Breakdown section, creates tickets in the configured project management tool (Linear, GitHub Issues, Jira, or other), and updates the Reference column in the spec with the resulting ticket links.

---

## Handling Changes

When the cascade mechanism flags a Feature Technical Spec because an upstream Layer 1 or Layer 2 document has changed:

1. Open the flagged spec and review what changed upstream.
2. Re-run the Codebase Enrichment Skill (or update manually) to adjust affected sections.
3. Scan the Work Breakdown table for tasks impacted by the change — update or add tasks as needed.
4. Update or create new tickets in the project management tool for any new or changed tasks.
5. Update `last_updated` in the frontmatter.

For larger upstream changes (feature scope change, major business rule revision), treat it as a new draft cycle — update the Technical Approach first, then re-enrich, then update tickets.

---

## Feature Technical Spec Catalog


| Feature | Domain | Tech Lead | Status | Layer 1 Spec | Layer 2 Spec |
| ------- | ------ | --------- | ------ | ------------ | ------------ |
| | | | | | |


---

## Template

See [_example-domain/_example-feature-technical-spec.md](_example-domain/_example-feature-technical-spec.md) for the Feature Technical Spec template.
