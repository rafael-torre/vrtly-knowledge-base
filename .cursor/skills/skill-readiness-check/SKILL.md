---
name: skill-readiness-check
description: 'Validate that product spec, UX, and Architecture are complete and aligned before implementation. Use when the user says "check implementation readiness".'
---

# Readiness Check

## Purpose
Validate that all prerequisite layer documents are in consensus and aligned before moving to Layer 4 implementation. Produces a readiness report listing gaps and blockers.

## Inputs
- layers/layer-1-product/final/** (product specs)
- layers/layer-2-design/final/** (UX specs, if applicable)
- layers/layer-3-architecture/final/** (architecture, ADRs, feature technical specs)

## Outputs
- Readiness report in layers/layer-3-architecture/intermediate/readiness-report.md

## Steps (TODO)
1. Scan Layer 1 final/ for feature specs — check status: consensus
2. Scan Layer 2 final/ for UX specs — check status: consensus (skip if N/A)
3. Scan Layer 3 final/ for architecture and ADRs — check status: consensus
4. Check cross-layer alignment: each Layer 3 technical spec maps to a Layer 1 feature spec
5. List gaps and blockers
6. Write readiness report to layers/layer-3-architecture/intermediate/readiness-report.md
