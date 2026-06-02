---
title: Design System Reference
layer: design
owner: ""
last_updated: ""
relates_to:
  - layers/layer-1-product/final/product-brief.md
status: in_progress
---

# Design System Reference

The translation layer between design and code for this project. This document does not replace the Figma component library — it captures what the library cannot convey on its own: where things live, what the variables are, how components are named in code, and what patterns apply consistently across all features.

Engineers read this alongside Figma. Designers use it to align with what has been established. New team members on either side read it to understand the visual language and conventions of the product.

---

## Figma Library

> **Guiding questions:**
>
> - Where is the canonical Figma file for this project's design system?
> - Is there a shared organization-level library, or is the component library project-specific?
> - Is there a separate file for the design system versus the product mockups?
>
> **What to include:** A stable link to the Figma file (not a specific frame — the file root or a dedicated library page). Note the page name within the file if the components are on a specific page.


| Resource | Figma Link | Notes |
| -------- | ---------- | ----- |
| Component library | | |
| Prototypes / flows | | |


---

## Design Variables

The visual variables that define this product's look and feel. These are defined in Figma — this section documents what categories exist and where to find them, giving engineers and designers a shared vocabulary.

> **Guiding questions:**
>
> - What color variables are defined? Are there semantic aliases (e.g., `color-action-primary`) on top of raw palette values?
> - What is the spacing scale? Is it a fixed set of values (4, 8, 12, 16, 24...) or free-form?
> - What type styles are defined? How are they named?
> - Are there elevation or shadow levels? Motion/timing values?
> - Where in Figma are these defined — a variables panel, a dedicated page, a style guide frame?


| Category | Description | Where in Figma |
| -------- | ----------- | -------------- |
| Color | Palette and semantic color aliases | |
| Typography | Type styles — sizes, weights, line heights | |
| Spacing | Scale of spacing values used for padding, margins, gaps | |
| Elevation | Shadow and depth levels | |
| Motion | Duration and easing values for transitions and animations | |


---

## Naming Conventions

How design artifacts are named in relation to how they are named in code. Mismatches here cause friction during handoff — engineering implements a component with one name, design refers to it with another.

> **Guiding questions:**
>
> - Do Figma component names match the code component names? If not, where do they differ?
> - How are component variants and props named in Figma versus code? (e.g., Figma uses `Type=Primary` but code uses `variant="primary"`)
> - Are there naming conventions for pages, frames, or sections in Figma that teams should follow?

*Document mappings where Figma and code names diverge. If they are fully aligned, note that explicitly.*


| Figma Name | Code Name | Notes |
| ---------- | --------- | ----- |
| | | |


---

## Component Usage Rules

Implementation-affecting rules that are not visible from the component itself. These prevent the most common handoff mistakes — using the wrong variant, composing components in ways that break, or deviating from established patterns.

> **Guiding questions:**
>
> - Are there variants that should only be used in specific contexts?
> - Are there composition constraints — components that should never appear together, or that must always appear with certain children?
> - Are there components that look similar but have different semantic meanings and should not be used interchangeably?
> - Are there deprecated components still in the library that should not be used for new work?

*Use prose or a list. Keep each rule specific and actionable.*

---

## Pattern Decisions

Project-wide UX patterns applied consistently across all features. These are decisions that have been made once — engineers and designers should follow them without re-evaluating per feature.

> **Guiding questions:**
>
> - How does the product handle form validation — inline as the user types, on field blur, or on submit?
> - What is the standard pattern for empty states across the product?
> - How are errors communicated — toast notifications, inline messages, error pages?
> - What is the standard loading pattern — skeleton screens, spinners, shimmer?
> - How does the product handle destructive actions — confirmation dialogs, inline confirmation, undo?
> - What navigation patterns are used — tabs, sidebars, breadcrumbs, modals?

*Each pattern should be stated as a decision, not a question. Example: "Validation runs on field blur, not on keystroke. Submit-time validation is used only when server-side validation is required."*

---

## Accessibility Standards

The baseline accessibility requirements for this project, applicable to all features. Feature-specific accessibility details (focus order, ARIA patterns for complex interactions) live in the individual feature design specs.

> **Guiding questions:**
>
> - What WCAG level is the target? (AA is the baseline for most products; AAA for specific contexts)
> - Are there platform-specific requirements (iOS, Android, specific assistive technology support)?
> - What is the approach to keyboard navigation — what must be keyboard-accessible?
> - How is color contrast validated? Is there a process for checking new components?
> - Who is responsible for accessibility review before handoff?


| Standard | Requirement | Notes |
| -------- | ----------- | ----- |
| WCAG level | AA / AAA | |
| Keyboard navigation | | |
| Color contrast | | |
| Screen reader support | | |
| Testing approach | | |
