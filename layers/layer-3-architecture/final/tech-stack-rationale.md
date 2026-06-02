---
title: Tech Stack Rationale
layer: architecture
owner: ""
last_updated: ""
relates_to:
  - layers/layer-3-architecture/final/architecture-overview.md
  - layers/layer-3-architecture/final/nonfunctional-requirements.md
status: in_progress
---

# Tech Stack Rationale

What we chose and why. This document records the technology decisions for this project — not as a catalog of tools, but as a record of reasoning. Future engineers, tech leads, and AI tools reading this should understand not just what the stack is, but why it is what it is and what constraints led to each choice.

For decisions with significant trade-offs or long-term implications, an ADR is linked from the relevant section. ADRs are the authoritative record for those decisions — this document provides the summary view.

---

## Core Stack

The primary languages, frameworks, and runtimes that form the foundation of the system.

> **Guiding questions:**
>
> - What language(s) does the backend use? Why this language over alternatives?
> - What framework(s) does the backend use? Why this framework?
> - What language and framework does the frontend use? Why?
> - Were there client mandates, team familiarity, or ecosystem constraints that drove any of these choices?
> - What alternatives were seriously considered and ruled out?


| Layer | Technology | Version | Rationale | ADR |
| ----- | ---------- | ------- | --------- | --- |
| Backend language | | | | — |
| Backend framework | | | | — |
| Frontend language | | | | — |
| Frontend framework | | | | — |
| Runtime / platform | | | | — |


---

## Data Storage

The databases, caches, search indexes, and other storage systems used by the project.

> **Guiding questions:**
>
> - What is the primary database? Why this database — relational vs. document vs. time-series?
> - Are there secondary databases or specialized stores (search index, cache, object storage)?
> - What drove the choice of each storage system — data model fit, operational maturity, cost, team familiarity?
> - What ORM or query layer is used? Why?
> - Were there performance, scaling, or consistency trade-offs that informed the choices?


| Storage System | Technology | Version | Purpose | Rationale | ADR |
| -------------- | ---------- | ------- | ------- | --------- | --- |
| Primary database | | | | | — |
| Cache | | | | | — |
| Search | | | | | — |
| Object storage | | | | | — |


---

## Infrastructure

Hosting, cloud provider, containerization, and CI/CD tooling.

> **Guiding questions:**
>
> - What cloud provider is used? Is this a client requirement or a team choice?
> - How is the application deployed — containers (Docker, Kubernetes), serverless, PaaS (Heroku, Railway, Fly.io), VMs?
> - How is infrastructure defined and provisioned — Terraform, Pulumi, CDK, or cloud console?
> - What CI/CD platform is used? What does the pipeline do?
> - Are there cost or vendor lock-in considerations that shaped infrastructure choices?


| Concern | Technology | Rationale | ADR |
| ------- | ---------- | --------- | --- |
| Cloud provider | | | — |
| Containerization | | | — |
| Orchestration | | | — |
| Infrastructure as code | | | — |
| CI/CD platform | | | — |
| Secrets management | | | — |


---

## Third-party Services

External services integrated into the product — payment processors, email providers, analytics, feature flags, and others.

> **Guiding questions:**
>
> - What third-party services does the product use?
> - For each service: why this provider over alternatives? Was there a formal evaluation?
> - Are there vendor lock-in risks for any of these choices? How are they mitigated?
> - Are there cost implications at scale?
> - Are there data residency or compliance constraints that affected any of these choices?


| Service | Provider | Purpose | Evaluation Summary | ADR |
| ------- | -------- | ------- | ------------------ | --- |
| Payment processing | | | | — |
| Transactional email | | | | — |
| Analytics | | | | — |
| Error tracking | | | | — |
| Feature flags | | | | — |


---

## Development Tooling

Tools that support the development process — testing frameworks, linting, type checking, local development.

> **Guiding questions:**
>
> - What testing frameworks are used — unit, integration, end-to-end?
> - What linting and formatting tools are used? Are they enforced in CI?
> - Is there type checking (TypeScript, mypy, etc.)?
> - How do engineers run the project locally — Docker Compose, local services, cloud dev environments?
> - Are there code quality or coverage gates in the CI pipeline?


| Concern | Technology | Notes |
| ------- | ---------- | ----- |
| Unit testing | | |
| Integration testing | | |
| End-to-end testing | | |
| Linting / formatting | | |
| Type checking | | |
| Local development | | |


---

## Open Questions

Unresolved stack decisions. This section should be empty when the document reaches `status: established`.


| Question | Context | Owner | Target Date | Status | Resolution |
| -------- | ------- | ----- | ----------- | ------ | ---------- |
| | | | | Open / Resolved | |
