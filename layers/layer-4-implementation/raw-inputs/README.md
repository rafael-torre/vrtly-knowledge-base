# Raw Inputs — Layer 4: Implementation & Operations

Materials gathered, not authored. Work through this checklist at the start of Layer 4 to capture the context needed for synthesis. Not every item will be available for every project — gather what exists and note what is missing.

---

## Upstream Layer Documents

The final documents from Layer 3 (Architecture) are the primary inputs to this layer. They provide the technical decisions and constraints that implementation and operations docs are written against.

### Layer 3: Architecture

| Input | Description | Source |
| ----- | ----------- | ------ |
| Architecture Overview | System boundaries, container view, data architecture, security model, infrastructure overview | Layer 3 final |
| ADRs | Architectural decisions with rationale — informs which patterns and approaches are locked in vs. open | Layer 3 final |
| Feature Technical Specs | Full-stack technical specifications per feature — the primary reference for implementation work | Layer 3 final |
| Non-functional Requirements | Performance, scalability, availability, security targets — informs testing strategy and monitoring thresholds | Layer 3 final |
| Tech Stack Rationale | Technology choices and reasoning — ensures the Development Guide reflects the actual stack | Layer 3 final |

### Layer 2: Design

Include when the project has a UI component. Skip and note as N/A when Layer 2 does not apply.

| Input | Description | Source |
| ----- | ----------- | ------ |
| Feature Design Specs | Interaction patterns, states, component behavior — informs frontend implementation conventions | Layer 2 final |
| Design System Reference | Component library, naming conventions — informs how frontend tooling and patterns are documented | Layer 2 final |

---

## Project Inputs

Materials from the project itself that reflect how the team actually works. These are gathered by talking to engineers, reading existing docs, reviewing PRs, and looking at the codebase.

| Input | Description | Who Provides |
| ----- | ----------- | ------------ |
| Codebase | The living system — the primary source of truth for what conventions and patterns are actually in use | Engineering Team |
| PR discussions | Review comments, merge decisions, and technical debates that reveal implicit team standards | Engineering Team |
| Code review threads | Recurring feedback patterns that indicate unenforced or undocumented conventions | Tech Lead / Engineers |
| Retro notes | Team feedback on process friction — reveals what is missing or broken in workflows | Engineering Team |
| Existing team conventions | Any informal or documented standards the team already follows — linting configs, PR templates, contributing guides | Engineering Team |
| CI/CD configuration | Pipeline definitions (GitHub Actions, CircleCI, etc.) — source of truth for deployment and automation behavior | DevOps / Engineers |
| Infrastructure configuration | Terraform, Pulumi, or cloud console configuration — source of truth for environment and infrastructure state | DevOps |
| Monitoring tool configuration | Dashboard definitions, alert rules, log queries — source of truth for what is currently being monitored | DevOps / Engineers |
