---
name: session-handoff
description: "Writes a resume packet when a session is ending or drifting. Captures decisions, blockers, and next steps for seamless continuity."
---

# Session Handoff Skill

Use this skill when ending a session, switching context to unrelated work, or handing off to a teammate.

## What It Does

Produces a structured handoff document (`.claude/session-handoff.md`) that captures:

- **What was accomplished** — docs edited, decisions made, consensus reached
- **What's in progress** — open questions, pending review, work stalled
- **Blockers** — dependencies, missing information, unresolved design conflicts
- **Next steps** — concrete action items and suggested priorities
- **Context for the next session** — relevant upstream docs, frontmatter status, role-specific notes

The handoff packet is gitignored but persistent across sessions, so the next session can link it immediately.

## Output

A `.claude/session-handoff.md` file with:
- Timestamp of when handoff was written
- Brief summary of session work
- List of docs edited and their new status
- Blockers and unresolved questions
- Recommended priorities for next session
- Links to relevant context

## When to Use

- **End of day**: Capture progress before stopping work
- **Context switch**: Need to work on something unrelated for a while
- **Before vacation or time off**: Leave a clear trail for whoever picks up the work
- **Handing off to a teammate**: Ensure they have all the context without needing to ask
- **Long session**: If working for hours and losing focus, handoff to "reset" with fresh eyes

## How to Use the Output

At the start of the next session, reference the handoff:

```
Continue from .claude/session-handoff.md
```

Or copy the key items directly into a new query to re-establish context.

## Tips

- Use frequently (even mid-day if switching tasks) to maintain a clear paper trail
- The handoff is a signal: "Here's where we left off, and here's what needs to happen next"
- Link related docs in the handoff so the next session doesn't have to hunt for context
- If consensus docs keep getting marked `needs_review`, note that as a blocker — it likely indicates a design conflict needing resolution
