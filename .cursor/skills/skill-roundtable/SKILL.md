---
name: skill-roundtable
description: 'Orchestrates group discussions between DB90 agent personas. Use when the user requests a roundtable or multi-agent discussion.'
---

# Roundtable

## Purpose
Facilitate a multi-agent group discussion where each DB90 persona contributes their perspective independently — enabling natural cross-functional dialogue about a project topic.

## Inputs
- .agents/config/config.toml (agent roster)
- Topic or question from user
- Optional: specific agents to include

## Outputs
- Discussion transcript in conversation (no file output)

## Steps (TODO)
1. Read agent roster from .agents/config/config.toml
2. Confirm which agents to include (default: all DB90 personas)
3. Present topic to each agent in turn — each responds from their layer perspective
4. Facilitate cross-agent exchanges on disagreements or open questions
5. Synthesize discussion into key decisions and open questions
6. Offer to write a summary to appropriate intermediate/ folder
