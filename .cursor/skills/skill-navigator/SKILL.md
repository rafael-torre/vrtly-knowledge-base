---
name: skill-navigator
description: 'Analyzes current project state and recommends the next skill(s) to use in the DB90 flow. Use when the user asks for help or what to do next.'
---

# Navigator

## Purpose
Read the DB90 project state (layer finals frontmatter status) and the navigator.csv skill graph to answer "what should I do next?" — recommending the most appropriate skill based on current layer completion and prerequisites.

## Inputs
- .agents/config/_index/navigator.csv (skill graph with phases, prereqs, outputs)
- All layer final/ documents (reads status frontmatter fields)
- User query (optional — defaults to "what is next?")

## Outputs
- Navigation recommendation in conversation (no file output)

## Steps (TODO)
1. Read navigator.csv to build skill graph (skill -> phase, preceded-by, required)
2. Scan all layers/layer-*/final/ docs — read status frontmatter for each
3. Determine current phase based on which layers have consensus docs
4. Identify the next required skill(s) with satisfied prerequisites
5. Present recommendation with context: why this skill, what it produces, what comes after
6. Offer to invoke the recommended skill immediately
