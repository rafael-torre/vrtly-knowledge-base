---
name: skill-feature-spec
description: 'Create, update, or validate a feature spec (product or technical PRD). Use when the user wants to produce, edit, or validate a feature spec.'
---

# Feature Spec

## Purpose
Create or update feature specifications at either Layer 1 (product) or Layer 3 (technical). Product specs capture user stories, acceptance criteria, and functional requirements. Technical specs add implementation constraints, data models, and API contracts.

## Inputs
- For product spec: Layer 1 product brief in consensus
- For technical spec: Layer 1 product feature spec in consensus; Layer 2 UX spec if applicable
- Feature or domain name from user

## Outputs
- Product spec: layers/layer-1-product/intermediate/features/<domain>/<feature-name>.md
- Technical spec: layers/layer-3-architecture/intermediate/features/<domain>/<feature-name>-technical.md

## Steps (TODO)
1. Determine intent: product spec vs technical spec
2. Check prereq: upstream layer docs in consensus
3. Load upstream context
4. Elicit or update requirements (functional, non-functional, constraints)
5. Draft spec sections: overview, user stories, acceptance criteria, data model (technical), API contracts (technical)
6. Review with user; iterate
7. Write to appropriate intermediate/ path
8. Prompt to promote via skill-promote-to-final when ready
