---
name: skill-create-architecture
description: 'Guided workflow to document technical decisions and architecture. Use when the user wants to create architecture documentation.'
---

# Create Architecture

## Purpose
Document the system architecture for a project or feature. Covers structural decisions, system boundaries, technology choices, and ADRs. Prereq: Layer 1 and Layer 2 in consensus.

## Inputs
- Layer 1 and Layer 2 final documents in consensus
- User input on technical goals and constraints

## Outputs
- Architecture overview in layers/layer-3-architecture/intermediate/architecture-overview.md
- ADRs in layers/layer-3-architecture/intermediate/decisions/

## Steps (TODO)
1. Check prereq: Layer 1 and Layer 2 (if applicable) in consensus
2. Load upstream context
3. Elicit system boundaries, key components, and technology constraints
4. Document structural decisions and trade-offs
5. Write ADRs for each significant decision
6. Write architecture overview
7. Prompt to promote via skill-promote-to-final when ready
