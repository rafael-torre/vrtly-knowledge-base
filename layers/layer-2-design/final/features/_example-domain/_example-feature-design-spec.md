---
title: ""
layer: design
owner: ""
last_updated: ""
relates_to:
  - layers/layer-1-product/final/features/_example-domain/_example-feature-spec.md
  - layers/layer-2-design/final/design-system-reference.md
status: in_progress
---

# Feature Design: [Feature Name]

A complement to the [Layer 1 feature spec](../../../../layer-1-product/final/features/_example-domain/_example-feature-spec.md). Read that document first — it defines what this feature does, who it's for, the business rules, and the acceptance criteria.

This document covers only what the feature spec and Figma cannot convey on their own: design assets, non-obvious states and behavior, interactions and motion, responsive behavior, content specifications, and feature-specific accessibility requirements.

---

## Design Assets

Stable links to the canonical Figma designs for this feature. Use deep links to specific pages or frames, not the file root. Mark readiness so engineers know what is approved for implementation.

> **Guiding questions:**
>
> - Where in Figma are the final designs for this feature? Link to specific frames or sections, not just the file.
> - Is there a prototype that shows the flow and transitions?
> - Are all screens in a "Ready for Dev" state, or are some still in progress?
> - If designs are split across multiple pages or files, list all of them.


| Screen / Flow | Figma Link | Status |
| ------------- | ---------- | ------ |
| | | Draft / Ready for Dev / Final |


---

## States and Behavior

What each screen or component looks like in every state that matters for implementation. Figma typically shows the default (happy path) state — this section documents the rest.

> **Guiding questions:**
>
> - What does the feature look like before there is any data (empty state)?
> - What does the user see while data is loading?
> - What does an error look like — where does it appear, what does it say, does it auto-dismiss?
> - Are there disabled states? What triggers them?
> - Are there permission-based states — things a user sees differently based on their role?
> - Are there success confirmation states (after a form submit, after a destructive action)?
> - For each non-obvious state: is it shown in Figma, or does this document need to describe it?


| State | Description | Behavior | Figma Link |
| ----- | ----------- | -------- | ---------- |
| Default | | | |
| Loading | | | |
| Empty | | | |
| Error | | | |
| Success | | | |
| Disabled | | | |


---

## Interactions and Motion

Transitions, animations, and feedback timing. Document intent and behavior — not implementation details. If a standard pattern from the Design System Reference applies, reference it instead of repeating it here.

> **Guiding questions:**
>
> - Are there transitions when this feature enters or exits — drawers, modals, panels?
> - Does anything animate within the feature — list item additions/removals, counters, progress indicators?
> - What is the timing intent — is motion meant to provide feedback, orient the user, or add delight?
> - Does anything snap to its final state immediately (no animation)?
> - Are there hover or focus states with transitions beyond what the design system defines?
>
> **Skip this section** if all interactions follow standard patterns from the Design System Reference and nothing is feature-specific.

---

## Responsive Behavior

How this feature's layout and behavior changes across breakpoints. Document what reflows, what hides, and what changes in behavior — not just what scales.

> **Guiding questions:**
>
> - Are there Figma frames for multiple breakpoints, or only one?
> - What layout changes happen at each breakpoint — does anything stack, collapse, or move?
> - Are there elements that are hidden at certain screen sizes? Is this purely visual or does it also affect functionality?
> - Does the interaction model change on mobile (e.g., a hover menu becomes a tap-to-expand)?
> - Do any content elements truncate differently at smaller sizes?
>
> **Skip this section** if the feature has no responsive variation (desktop-only internal tool, mobile-only app with a single layout, etc.).


| Breakpoint | Layout Changes | Behavior Changes | Figma Link |
| ---------- | -------------- | ---------------- | ---------- |
| Mobile (< 768px) | | | |
| Tablet (768–1024px) | | | |
| Desktop (> 1024px) | | | |


---

## Content Specifications

Final copy and content rules for this feature, where those decisions belong to design rather than product. Do not duplicate content that comes directly from business rules in the feature spec.

> **Guiding questions:**
>
> - Are there UI labels, button text, or headings that have been finalized and should not vary?
> - Are there character limits or truncation rules for dynamic content (usernames, titles, descriptions)?
> - What placeholder text is used in empty inputs?
> - Are there tooltip or helper text strings that are part of the designed experience?
> - Are there microcopy decisions — confirmation dialog text, empty state messaging, error messages — that are design-owned?
>
> **Skip this section** if all content is either self-evident in Figma or defined in the feature spec's acceptance criteria.

---

## Accessibility

Feature-specific accessibility requirements that go beyond the project-wide standards in the [Design System Reference](../../design-system-reference.md).

> **Guiding questions:**
>
> - What is the intended focus order when a user tabs through this feature? Does it follow the visual order, or does it deviate?
> - Are there keyboard shortcuts or interactions specific to this feature?
> - What should a screen reader announce when a state changes (e.g., after a form submit, after an error appears)?
> - Are there ARIA roles or labels needed for non-standard components in this feature?
> - Are there any color contrast concerns specific to this feature that differ from the project baseline?
>
> **Skip this section** if this feature introduces no accessibility requirements beyond the project-wide standards.

---

## Open Questions

Unresolved design items. This section should be empty when the spec reaches `status: established`.


| Question | Context | Owner | Target Date | Status | Resolution |
| -------- | ------- | ----- | ----------- | ------ | ---------- |
| | | | | Open / Resolved | |
