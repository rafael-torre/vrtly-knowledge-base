# Feature Design Catalog — Layer 2: Design

The index of all feature design specs. Each feature has a single design spec file that documents what Figma and the Layer 1 feature spec cannot convey on their own: design assets, states and behavior, interactions, responsive behavior, content, and accessibility.

---

## Conventions

### Alignment with Layer 1

Feature design specs mirror the Layer 1 feature structure exactly — same domain directories, same filenames. This makes the relationship between a feature spec and its design spec unambiguous without a mapping document.

```
Layer 1 features/           Layer 2 features/
├── auth/                   ├── auth/
│   ├── user-registration.md│   ├── user-registration.md  ← same name
│   └── password-reset.md   │   └── password-reset.md
├── commerce/               ├── commerce/
│   └── checkout.md         │   └── checkout.md
```

If a Layer 1 feature spec exists but no design spec exists yet, the feature has not reached design. If a feature is intentionally not designed (a backend-only feature, for example), note it in the catalog table below with a brief explanation.

### Organization

Features are organized into **domain subdirectories** that match Layer 1. Do not introduce new domains in Layer 2 — if a feature needs a domain, add it to Layer 1 first.

### When a Feature Design Spec Is Not Needed

Not every Layer 1 feature requires a Layer 2 design spec. Skip it when:

- The feature has no user-facing UI (backend logic, data processing, API endpoints)
- The feature's visual behavior is entirely standard — no non-obvious states, no custom interactions, and the Figma file is self-evident
- The project has been marked Layer 2: N/A

### Frontmatter

Every feature design spec carries full YAML frontmatter. The `relates_to` field **must** include the path to the corresponding Layer 1 feature spec. This is what enables cascade tracking — when a feature spec changes, the design spec is flagged for review.

```yaml
relates_to:
  - layers/layer-1-product/final/features/[domain]/[feature].md
  - layers/layer-2-design/final/design-system-reference.md
```

---

## Feature Design Catalog


| Feature | Domain | Designer | Status | Layer 1 Feature Spec |
| ------- | ------ | -------- | ------ | -------------------- |
| | | | | |


---

## Template

See [_example-domain/_example-feature-design-spec.md](_example-domain/_example-feature-design-spec.md) for the feature design spec template.
