---

## title: ""
layer: product
owner: ""
last_updated: ""
relates_to: []
status: in_progress

# Feature: [Feature Name]

A product-level specification of a single feature. This document defines what the feature does, who it's for, what business rules govern it, and what's out of scope — all described as product behavior, not technical implementation.

This spec is written for humans first: PMs, designers, clients, and engineers should all be able to read and validate it. It also serves as a structured input for AI-assisted technical documentation at Layer 3 (Architecture), where the business rules and acceptance criteria defined here are translated into technical constraints, API contracts, and implementation approaches.

---

## Problem and Context

> **Guiding questions:**
>
> - What problem does this feature solve?
> - Why does it need to exist? What happens if we don't build it?
> - How does this problem connect to the business context from Layer 0?
> - Is this a new capability or an improvement to something that exists?
>
> **Recommended length:** 1-2 paragraphs.

---

## Users

> **Guiding questions:**
>
> - Who uses this feature? Is it a subset of the product's target users?
> - What is their context when they encounter this feature — what are they trying to do?
> - Are there different user types with different needs from this feature (e.g., end user vs. administrator)?
>
> **Recommended length:** 1 paragraph. Reference personas from intermediate artifacts if they exist.

---

## Feature Description

> **Guiding questions:**
>
> - What does the feature do, described as behavior the user experiences?
> - Walk through what the user can do and what happens when they do it.
> - What is the expected flow from the user's perspective?
> - Do not describe screens or UI layout (that's Layer 2). Do not describe endpoints or data models (that's Layer 3).
>
> **Recommended length:** 2-3 paragraphs.

---

## Business Rules

The logic that governs this feature. Each rule should be stated clearly with a confidence level indicating how settled it is.

- **Confirmed** = hard constraint, non-negotiable. Downstream layers must respect this rule as-is. Typically sourced from regulations, client decisions, or validated business requirements.
- **Provisional** = current intent, may change. Downstream layers should design for flexibility around this rule. Typically sourced from assumptions, early discussions, or decisions that haven't been validated with stakeholders.


| Rule | Description | Confidence              | Source |
| ---- | ----------- | ----------------------- | ------ |
|      |             | Confirmed / Provisional |        |


> **Guiding questions:**
>
> - What rules constrain how this feature behaves?
> - Are there legal or regulatory requirements (age restrictions, data handling, accessibility)?
> - Are there business policy rules (pricing logic, refund windows, usage limits)?
> - Are there rules inherited from other features or from Layer 0 constraints?
> - For each rule: is this confirmed and non-negotiable, or is it a current assumption that could change?

---

## Acceptance Criteria

Behavioral, verifiable statements describing what "done" looks like from a product perspective. Each criterion should be testable by a human using the product — no technical assertions (no status codes, no API formats, no database states).

- *Criterion 1*
- *Criterion 2*
- *Criterion 3*

> **Guiding questions:**
>
> - If you handed this feature to someone who had never seen it, what would you check to confirm it works?
> - What must be true for each business rule to be considered implemented?
> - What must the user be able to do that they couldn't do before?

---

## Edge Cases

Non-obvious situations described from the user's perspective. These are the scenarios that get missed if not explicitly documented — and the scenarios most likely to cause bugs or product confusion downstream.


| Scenario | Expected Behavior | Notes |
| -------- | ----------------- | ----- |
|          |                   |       |


> **Guiding questions:**
>
> - What happens when there is no data (empty states)?
> - What happens when the user makes an error or provides invalid input?
> - What happens at boundary conditions (maximum values, minimum values, zero)?
> - What happens when multiple users interact with this feature simultaneously?
> - What happens when a dependent system is unavailable?

---

## Out of Scope

What this feature explicitly does NOT cover. This section is critical for preventing scope creep during design and implementation, and for giving AI tools clear boundaries when generating technical documentation or code.

- *Exclusion 1 — rationale*
- *Exclusion 2 — rationale*

> **Guiding questions:**
>
> - What might someone assume is included in this feature but is not?
> - Are there related capabilities being handled by a different feature spec?
> - Are there capabilities deferred to a later phase?

---

## Dependencies

Other features, external systems, or business processes that interact with this feature at the business level.


| Dependency | Type                                         | Notes |
| ---------- | -------------------------------------------- | ----- |
|            | Depends on / Depended on by / Interacts with |       |


> **Guiding questions:**
>
> - Does this feature require another feature to exist first?
> - Do other features depend on this one?
> - Are there external systems or business processes that this feature interacts with (payment processors, email providers, third-party APIs)?
> - Are there cross-domain relationships — does this feature touch a domain it doesn't belong to?

---

## Open Questions

Unresolved items that need answers before this spec is considered complete. This section should be empty when the feature spec reaches `status: established`.


| Question | Context | Owner | Target Date | Status          | Resolution |
| -------- | ------- | ----- | ----------- | --------------- | ---------- |
|          |         |       |             | Open / Resolved |            |
