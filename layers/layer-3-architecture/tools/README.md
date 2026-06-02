# Tools — Layer 3: Architecture

AI skills and process guides that accelerate producing the artifacts in this layer. These are defined here as a backlog — each will be built out as a separate effort.

---

## AI Skills


| Skill | Type | Status |
| ----- | ---- | ------ |
| Feature Technical Spec Drafting Skill | AI skill: reads Layer 1 Feature Spec + Layer 2 Feature Design Spec + Architecture Overview and produces a first-draft Feature Technical Spec (`status: in_progress`). Fills in technical approach, data model intent, API contracts, frontend architecture decisions, key flows, and a rough work breakdown. Codebase-specific details (actual file paths, current schema fields, component names) are left as guiding prompts for Phase 2. No codebase access needed — works entirely from documentation context. | Not started |
| Codebase Enrichment Skill | AI skill: reads an in-progress Feature Technical Spec and one or more code repositories, then updates the same spec file with actual code references — current schema fields and tables, real component file paths, existing API routes, live service endpoints. Designed to run per-repo for multi-repo setups: run once against the backend repo (enriches Data Model, API Contracts, Integration Points), once against the frontend repo (enriches Frontend Architecture). Supports both initial enrichment and change-driven re-grounding (re-run when an upstream doc changes and the spec needs to reflect the updated context). | Not started |
| Ticket Creation Skill | AI skill: reads a completed Feature Technical Spec and creates tickets in the project management tool from the Work Breakdown section. Tool-agnostic — configurable for Linear, GitHub Issues, Jira, or other systems. After creating tickets, updates the Reference column in the Work Breakdown table with links to the created tickets. Tickets reference the Feature Technical Spec as the source of truth rather than duplicating its content. | Not started |
| Architecture Review Skill | AI skill: reviews a set of Feature Technical Specs against the Architecture Overview and Non-functional Requirements, then flags inconsistencies — pattern deviations, missing integration points, NFR violations, or specs that are out of sync with the system-wide documents. Produces a summary report for the tech lead. | Not started |
| Change Impact Analysis Skill | AI skill (future): when an upstream Layer 1 or Layer 2 document changes, reads the diff between the old and new version, compares it against the affected Feature Technical Specs, and produces a summary of what sections are affected and which Work Breakdown tasks and tickets need updating. Build this when teams report that the manual change process (see [features/README.md](../final/features/README.md)) is too burdensome at scale. | Not started |


---

## Process Guides


| Guide | Type | Status |
| ----- | ---- | ------ |
| Layer 3 Kickoff Checklist | Process guide: step-by-step checklist for starting Layer 3 on a new project. Covers the recommended order: Architecture Overview → Non-functional Requirements → Tech Stack Rationale → ADRs for significant stack decisions → Feature Technical Specs as features move into architecture. Includes prompts for gathering raw inputs and engaging the right contributors (DevOps, QA, PM). | Not started |
| ADR Lifecycle Guide | Process guide: practical guidance for the ADR workflow — when to write an ADR vs. a Decision Log entry, how to structure the decision statement and alternatives clearly, how to deprecate an ADR whose context has changed, how to supersede an ADR when a decision reverses, and how to run an ADR review. | Not started |
