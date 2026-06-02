# Tools — Layer 4: Implementation & Operations

AI skills and process guides that accelerate producing the artifacts in this layer. These are defined here as a backlog — each will be built out as a separate effort.

---

## AI Skills


| Skill | Type | Status |
| ----- | ---- | ------ |
| Development Guide Drafting Skill | AI skill: reads the Layer 3 Architecture Overview, Tech Stack Rationale, ADRs, and the codebase (linting config, CI config, PR templates, test setup) and produces a first-draft Development Guide. Extracts actual conventions from linting rules and CI configuration rather than inventing them. Flags sections where team input is needed (branching strategy, review expectations, coverage thresholds). | Not started |
| Deployment Guide Drafting Skill | AI skill: reads the CI/CD pipeline configuration (GitHub Actions, CircleCI, etc.), infrastructure configuration (Terraform, Pulumi, cloud console exports), and Layer 3 Architecture Overview, then produces a first-draft Deployment Guide grounded in the actual pipeline and environment setup. | Not started |
| Monitoring Coverage Review Skill | AI skill: reads the Monitoring & Observability document and compares it against the Layer 3 Non-functional Requirements and Architecture Overview, then flags gaps — NFR targets with no corresponding alert, services in the architecture with no monitoring coverage, or alerting thresholds inconsistent with NFR targets. | Not started |


---

## Process Guides


| Guide | Type | Status |
| ----- | ---- | ------ |
| Layer 4 Kickoff Checklist | Process guide: step-by-step checklist for starting Layer 4 on a new project. Covers the recommended order: Development Guide → Deployment Guide (when process is defined) → Monitoring & Observability (when tooling is in place). Includes prompts for gathering raw inputs and engaging the right contributors. | Not started |
