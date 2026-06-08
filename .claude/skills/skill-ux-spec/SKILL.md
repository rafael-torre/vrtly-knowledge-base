---
name: skill-ux-spec
description: 'Plan UX patterns and design specifications. Use when the user says "create UX design" or "create UX specifications".'
---

# UX Spec

## Purpose
Plan and document UX patterns, screen flows, and design specifications for a feature. Translates Layer 1 product specs into concrete user experience guidance for Layer 3 architecture.

## Inputs
- Layer 1 feature spec in consensus
- User input on UX goals and constraints

## Outputs
- UX spec in layers/layer-2-design/intermediate/features/<domain>/<feature-name>-ux.md

## Steps (TODO)
1. Check prereq: Layer 1 feature spec in consensus
2. Load Layer 1 feature spec context
3. Elicit UX goals, user flows, and accessibility constraints
4. Draft UX spec: screen inventory, flow diagrams (Mermaid), component descriptions, interaction patterns
5. Review with user; iterate
6. Write to layers/layer-2-design/intermediate/features/<domain>/<feature-name>-ux.md
7. Prompt to promote via skill-promote-to-final when ready
