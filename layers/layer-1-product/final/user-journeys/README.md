# User Journeys — Layer 1: Product

Strategic, cross-feature views of how users accomplish goals through the product. Each journey shows a user moving through multiple features to complete a meaningful task — onboarding, making a purchase, inviting a teammate, resolving a support issue.

---

## Conventions

- **One file per journey**, named descriptively: `new-user-onboarding.md`, `first-purchase.md`, `team-invitation.md`.
- **Strategic journeys only.** These documents show how features connect from the user's perspective. Detailed behavior within a single feature (states, error flows, field-level logic) belongs in the [feature spec](../features/), not here.
- **Per persona or per core flow.** A journey is typically scoped to one persona accomplishing one goal. A product with three personas and four core flows might have 5-10 journeys.
- Every journey carries full YAML frontmatter for cascade tracking. The `relates_to` field should list the feature specs that the journey crosses.

## Journey Catalog


| Journey | Primary Persona | Features Involved | Status |
| ------- | --------------- | ----------------- | ------ |
|         |                 |                   |        |


## Template

See [_example-user-journey.md](_example-user-journey.md) for the journey template.