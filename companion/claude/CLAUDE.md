# DB90 Companion

You are working inside a layered documentation repository that follows the DB90 framework. This guidance is always active.

## Framework Overview

This repository uses a five-layer documentation model:

- **Layer 0 (Business)**: Client, market, goals, constraints — scope per engagement, informs all projects
- **Layer 1 (Product)**: Problem space, users, what we're building — owned by PM
- **Layer 2 (Design)**: User experience, screens, behavior, feel — owned by Designer (N/A for API-only projects)
- **Layer 3 (Architecture)**: Structural decisions, system boundaries, technical reasoning — owned by Tech Lead
- **Layer 4 (Implementation)**: Engineering guidance, development, deployment, operations — owned by Dev Team + Tech Lead

Each layer has a `draft/` folder (early thinking) and a `final/` folder (consensus). Documents flow downstream: Layer 0 → Layer 1 → Layer 2 → Layer 3 → Layer 4. Each layer can be independent; not every project needs every layer.

## Session Modes

### Resume Mode (on session start)

At the start of every session:
1. Run `companion/hooks/scan-project-state.sh` from the repo root and read its output
2. Surface docs with `status: needs_review`, `status: needs_update`, or `status: in_progress`
3. Propose a concrete focused scope for this session
4. Read `.companion.yaml` if present to tailor suggestions by role

### Guided Mode (during active work)

As the user works on a document:
- Detect which layer from the file path (e.g., `layers/layer-2-design/draft/...` → Layer 2)
- Load the upstream Layer N-1 final documents via `relates_to` links for reference
- Suggest the appropriate skill for the current task (draft, review, refine)
- Enforce layer sequencing: do not finalize Layer N before the Layer N-1 final reaches `consensus`

### Handoff Mode (when ending or drifting)

When the session is ending or context is drifting, run the `session-handoff` skill. It produces a `.claude/session-handoff.md` file capturing decisions, blockers, and next steps for seamless continuity.

## Hooks

Since Claude does not have a native hook runner, invoke these scripts manually at the appropriate times:

| Script | When to run | Purpose |
|---|---|---|
| `companion/hooks/scan-project-state.sh` | Session start | Scans all `final/` docs and writes a state summary |
| `companion/hooks/update-metadata.sh <file> <repo_root>` | After editing any `final/` doc | Updates `last_updated` and cascades `needs_review` to related docs |

Run the session-start hook at the beginning of each session:
```bash
bash companion/hooks/scan-project-state.sh .
```

After editing a `final/` doc, run:
```bash
bash companion/hooks/update-metadata.sh <path-to-edited-file> .
```

## Scope Enforcement

If the current task does not fit the layers or documentation framework:
- Surface the mismatch explicitly
- Suggest creating a new session with focused scope
- Help the user refocus if drifting between unrelated topics

## Skill Index

### Companion-Level Skills (always available)

- **scan-project-state**: On-demand project health scan. Shows what needs review, what's stale, what's in progress across all layers.
- **session-handoff**: Writes a resume packet (`.claude/session-handoff.md`) when a session is ending or the user needs to context-switch.

### Layer and Document-Specific Skills

Skills are dynamically loaded based on the file being created or edited. When a draft or final document is opened:

1. Detect the layer and document type from the file path
2. Check for available skills in `.claude/skills/` that match that layer and document type
3. If a skill exists: load and follow it — the skill guides through creating that specific document type
4. If no skill exists: use the document template structure as a guide — each final document includes built-in sections and examples

## Layer-Aware Context Loading

Before any Layer N drafting or review:
1. Load the Layer N-1 final document(s) via `relates_to` links
2. Surface key decisions and constraints from upstream
3. Ensure the context needed for sound decisions is present before proceeding

## Configuration

Read `.companion.yaml` from the repo root when it exists:

```yaml
name: "Your Name"
role: tech-lead  # pm | designer | tech-lead | developer | engagement-lead
```

Role-based guidance:
- **pm**: Focuses on user problems, market fit, tradeoffs
- **designer**: Focuses on user experience, accessibility, flow
- **tech-lead**: Focuses on architecture, technical risks, maintainability
- **developer**: Focuses on implementation details, testing, debugging
- **engagement-lead**: Focuses on communication, stakeholder alignment, dependencies

If no `.companion.yaml` exists, offer to create one on first use.

## Frontmatter Conventions

All `final/` docs should have:

```yaml
---
title: "Document Title"
owner: "Name or Team"
status: draft | needs_review | in_progress | consensus | needs_update
last_updated: YYYY-MM-DD
relates_to:
  - path/to/related/doc.md
  - another/related/doc.md
---
```

The `status` field drives the cascade:
- When a `final/` doc is edited, run `update-metadata.sh` to auto-update `last_updated` to today
- The script also cascades `status: needs_review` to each doc listed in `relates_to`

## Quick Start

1. **First session?** Run:
   ```bash
   companion/init.sh
   ```
   This wires the companion system and creates your `.companion.yaml`.

2. **Check project health:**
   Use the `scan-project-state` skill or run `companion/hooks/scan-project-state.sh .`

3. **Start a task:**
   Open a draft or final doc in your target layer. Load upstream context, suggest the right skill, enforce sequencing.

4. **Long or drifting session?**
   Run `session-handoff` to capture decisions and context for the next person or session.
