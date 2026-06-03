# DB90 Companion — Layer Guidance

This rule is layer-aware. When working on any document, detect the layer from the file path and apply the guidance below.

## Layer Detection

| Path pattern | Layer |
|---|---|
| `layers/layer-0-business/` | Layer 0 — Business |
| `layers/layer-1-product/` | Layer 1 — Product |
| `layers/layer-2-design/` | Layer 2 — Design |
| `layers/layer-3-architecture/` | Layer 3 — Architecture |
| `layers/layer-4-implementation/` | Layer 4 — Implementation |

## Layer-Aware Guidance

- Before drafting or reviewing a Layer N document, load the Layer N-1 `final/` documents via `relates_to` links
- Surface key decisions and constraints from upstream before proceeding
- Enforce sequencing: do not finalize Layer N before Layer N-1 final reaches `consensus`
- Detect which layer you are in and tailor suggestions accordingly

## Session State

- At session start the `SessionStart` hook runs `scan-project-state.sh`, writing `.claude/session-state.md`
- Read that file and surface docs with `status: needs_review`, `needs_update`, or `in_progress`
- Propose a concrete focused scope for the session based on what is unfinished

## Skill Suggestions

When working on a document, check `~/.claude/skills/` for a skill matching the document type:

- `draft-feature-spec` — for Layer 1 feature spec drafts
- `draft-design-spec` — for Layer 2 design spec drafts
- `draft-technical-spec` — for Layer 3 architecture spec drafts
- `scan-project-state` — project health snapshot
- `session-handoff` — end-of-session resume packet

If a matching skill exists, load and follow it. Otherwise use the template structure in the document as a guide.

## Handoff

When ending a session or switching context, run the `session-handoff` skill. It writes `.claude/session-handoff.md` capturing decisions, blockers, and next steps.

## Providing Guidance

- Always reference the specific layer and frontmatter `status` of the current document
- Tailor tone and focus to the role in `.companion.yaml` (`pm`, `designer`, `tech-lead`, `developer`, `engagement-lead`)
- If no `.companion.yaml` exists, offer to create one
