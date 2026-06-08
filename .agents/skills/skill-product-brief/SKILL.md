---
name: skill-product-brief
description: 'Create, update, or validate a product brief. Use when the user wants help producing, editing, or validating a brief.'
---

# Product Brief

## Purpose
Create or update the Layer 1 product brief — the primary document that captures what is being built, for whom, and why. Prerequisite: at least one Layer 0 document in consensus.

## Inputs
- Layer 0 final documents (business context, competitive landscape)
- User input on product concept

## Outputs
- Product brief in layers/layer-1-product/intermediate/product-brief.md

## Steps (TODO)
1. Check prereq: Layer 0 has at least one consensus final doc
2. Load Layer 0 context (market, domain, business goals)
3. Elicit product concept, target users, and key problems
4. Draft brief using brief-template (problem, solution, users, value prop, constraints)
5. Review with user; iterate
6. Write to layers/layer-1-product/intermediate/product-brief.md
7. Prompt to promote via skill-promote-to-final when consensus reached
