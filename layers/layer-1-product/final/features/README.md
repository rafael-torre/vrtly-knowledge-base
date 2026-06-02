# Feature Catalog — Layer 1: Product

The central index of all product features. Each feature has a single spec file that defines its product behavior — what it does, who it's for, what rules govern it, and what's out of scope. Feature specs are the primary input for downstream technical documentation at Layer 3 (Architecture).

---

## Conventions

### Organization

Features are organized into **domain subdirectories**. A domain is a cohesive area of the product — authentication, billing, notifications, reporting. Every feature belongs to a domain.

```
features/
├── README.md           (this file)
├── auth/
│   ├── user-registration.md
│   └── password-reset.md
├── commerce/
│   ├── checkout.md
│   └── order-history.md
└── notifications/
    └── email-alerts.md
```

### Defining Domains

A domain groups features that share a common product area. When choosing domains:

- Name domains after the product area they represent, not the team that builds them.
- If a domain grows too large (10+ features), consider splitting it into sub-domains.
- If a feature doesn't fit cleanly into one domain, place it in the domain it most strongly belongs to and note the cross-domain relationship in the feature spec's Dependencies section.

### Feature Granularity

A feature should be a **bounded, describable unit of product behavior**. It is something a user or stakeholder can understand as a single capability.

- **Aim for ~2 pages** per feature spec. If a spec is pushing past 2 pages, ask whether it describes one bounded behavior or multiple behaviors bundled together.
- **Past 3 pages**, the feature almost certainly needs to be decomposed into sub-features, each with its own spec.
- "Payments" is not a feature — "checkout flow," "refund processing," "subscription billing," and "payment method management" are features.

### Naming

Feature spec files use descriptive kebab-case names: `user-registration.md`, `password-reset.md`, `checkout.md`. The name should make the feature identifiable without opening the file.

### Frontmatter

Every feature spec carries full YAML frontmatter for cascade tracking. The `relates_to` field should list the Product Brief and any dependent feature specs or relevant Layer 0 documents.

## Feature Catalog


| Feature | Domain | Owner | Priority | Status | Dependencies |
| ------- | ------ | ----- | -------- | ------ | ------------ |
|         |        |       |          |        |              |


## Template

See [_example-domain/_example-feature-spec.md](_example-domain/_example-feature-spec.md) for the feature spec template.