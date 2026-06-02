# Intermediate Artifacts — Layer 3: Architecture

Working documents that bridge raw inputs to final documents. These are iterative, living, and potentially messy — they exist to support synthesis, not to be polished deliverables.

This folder is an **open collection**. Teams create whatever artifacts they need during the architecture process. The examples provided here show common patterns, but the list is not exhaustive and no specific artifact is required.

---

## Conventions

Every intermediate artifact should include lightweight YAML frontmatter for history tracking:

```yaml
---
title: ""
last_updated: ""
---
```

No other metadata is required. These files are not tracked by the cascade mechanism — they exist for the team's benefit during the synthesis process.

---

## Examples

The following example templates show common patterns for intermediate artifacts. They are prefixed with `_example-` to distinguish them from actual project artifacts.


| Example | Pattern | When to Use |
| ------- | ------- | ----------- |
| [Tech Spike](_example-tech-spike.md) | Structured results from a time-boxed technical investigation | When validating a technical approach, evaluating feasibility, or answering a specific technical question before committing to a direction |
| [Integration Evaluation](_example-integration-evaluation.md) | Structured comparison of vendor or service options | When choosing between third-party services, libraries, or integration approaches that have meaningful trade-offs |
| [Decision Log](_example-decision-log.md) | Running list of technical decisions made during architecture work | Throughout the architecture process — captures decisions before they are formalized as ADRs, so the reasoning is not lost |
