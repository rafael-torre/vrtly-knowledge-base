---
name: scan-project-state
description: "Produces a project health summary on demand. Shows docs needing review, updates, or attention; detects stale docs and cross-layer gaps."
---

# Scan Project State Skill

Use this skill to get an on-demand snapshot of the entire documentation project's health.

## What It Does

Scans all `final/` documents across all layers, extracts frontmatter (`status`, `last_updated`, `relates_to`), and produces a compact summary showing:

- **Docs needing review** (`status: needs_review`)
- **Docs needing update** (`status: needs_update`)
- **Docs in progress** (`status: in_progress`)
- **Stale docs** (last_updated more than 30 days ago)
- **Missing cross-layer links** (Layer N doc with no relates_to upstream)

## Output

A markdown table and summary in the chat, ready to copy into session notes or share with teammates.

## When to Use

- **Session start**: Before starting work, get the big picture of what's unfinished
- **Sprint planning**: See what's blocked or stale across all layers
- **Before handoff**: Ensure downstream owners are aware of upcoming changes
- **Periodic health check**: Weekly or after large edits, verify the cascade is working

## How It Works

Run the hook script for a fast, accurate scan:

```bash
bash companion/hooks/scan-project-state.sh .
```

This writes both `.cursor/session-state.md` and `.claude/session-state.md`. Read `.claude/session-state.md` and summarize the findings in chat.

Alternatively, scan manually:
1. Recursively scan `layers/*/final/**/*.md`
2. Parse YAML frontmatter from each document
3. Categorize by `status` and check `last_updated` dates
4. Cross-reference `relates_to` links to detect missing upstream docs
5. Produce a summary table and key findings

## Key Metrics

- **Consensus rate**: % of final/ docs with `status: consensus`
- **Staleness**: Docs older than 30 days
- **Cascade health**: Orphaned downstream docs (no `relates_to` upstream)
- **Active work**: Docs currently being drafted or reviewed

## Tips

- Run this weekly to catch stale docs before they become problems
- If you see a high "needs_review" count, re-edit the blocking upstream doc to trigger the cascade repair
- Use the output to prioritize which layer or feature to work on next
