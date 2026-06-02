# Raw Inputs — Layer 3: Architecture

Materials gathered, not authored. Work through this checklist at the start of architecture work to capture the context needed for synthesis. Not every item will be available for every project — gather what exists and note what's missing.

---

## Upstream Layer Documents

The final documents from Layer 1 (Product) are the primary inputs to this layer. Layer 2 (Design) documents are included when the project has a UI component. These are not optional — they provide the product and design context that shapes every architectural decision.

### Layer 1: Product

| Input | Description | Source |
| ----- | ----------- | ------ |
| Product Brief | Problem space, target users, product vision, scope, key assumptions | Layer 1 final |
| Feature Specs | Feature behavior, business rules, acceptance criteria, edge cases, dependencies | Layer 1 final |
| Success Metrics | Product KPIs and quality targets that architecture must support | Layer 1 final |
| Domain Glossary | Shared vocabulary — ensures architectural naming aligns with product and business language | Layer 1 final |
| User Journeys | Cross-feature flows — informs sequencing and integration requirements | Layer 1 final |

### Layer 2: Design

Include when the project has a UI component. Skip and note as N/A when Layer 2 does not apply.

| Input | Description | Source |
| ----- | ----------- | ------ |
| Feature Design Specs | States, interactions, responsive behavior, accessibility requirements — informs frontend architecture | Layer 2 final |
| Design System Reference | Component library, design variables, naming conventions — informs frontend tech decisions | Layer 2 final |

### Layer 0: Business

Referenced directly when architectural decisions have business-level implications (compliance, vendor lock-in, cost constraints, regulatory requirements).

| Input | Description | Source |
| ----- | ----------- | ------ |
| Strategic Goals and Constraints | Budget, timeline, and operational constraints that limit architectural choices | Layer 0 final |
| Business Overview | Existing systems and integrations the client already has — shapes integration architecture | Layer 0 final |

---

## Technical Discovery

Outputs from technical investigations and experiments. These are gathered before or during architecture work — they inform decisions but are not final documents themselves.

| Input | Description | Who Provides |
| ----- | ----------- | ------------ |
| Tech spike results | Structured findings from time-boxed technical investigations | Tech Lead / Engineers |
| Proof-of-concept outcomes | Working prototypes or experiments validating technical feasibility | Engineers |
| Performance benchmarks | Load tests, latency measurements, throughput baselines from existing or proposed approaches | Engineers / QA |
| Security audits | Findings from security reviews of existing or proposed systems | Security / Tech Lead |

---

## Vendor and Integration

Materials that inform decisions about third-party services, APIs, and external systems.

| Input | Description | Who Provides |
| ----- | ----------- | ------------ |
| Vendor evaluations | Comparison of service options — features, pricing, reliability, support | Tech Lead / PM |
| Third-party API documentation | Official API docs for services the system will integrate with | Vendor |
| Integration partner materials | Technical specifications, SLAs, or onboarding docs from partners | Partner / PM |
| Service SLAs | Uptime and support commitments from vendors that affect NFR targets | Vendor |

---

## Existing Systems

Context about the current technical state — essential for brownfield projects, relevant for greenfield projects with legacy integrations.

| Input | Description | Who Provides |
| ----- | ----------- | ------------ |
| Existing system audits | Current architecture, known issues, technical debt inventory | Tech Lead / Engineers |
| Codebase | The living system — referenced during feature technical spec enrichment to ground specs in actual file paths, schemas, and component structures | Engineering Team |
| Legacy system documentation | Architecture diagrams, API specs, or runbooks from systems being replaced or integrated | Client / Tech Lead |
| Migration assessments | Analysis of what needs to change, what can be reused, what must be rebuilt | Tech Lead |
| Infrastructure documentation | Current hosting, environments, CI/CD setup, deployment processes | DevOps |

---

## Client-Provided Technical

Technical materials provided directly by the client that constrain or inform architectural decisions.

| Input | Description | Who Provides |
| ----- | ----------- | ------------ |
| Existing architecture diagrams | Client's view of their current system — may be outdated, always verify | Client |
| Client technical standards | Required languages, frameworks, cloud providers, or internal tooling mandates | Client / PM |
| Compliance and regulatory documentation | Industry-specific requirements (HIPAA, PCI-DSS, GDPR, SOC 2) that shape security and data architecture | Client / Legal |
| Access credentials and environments | Staging, sandbox, or development environment access needed for technical investigation | Client / DevOps |
| Existing API contracts | APIs the new system must integrate with or conform to | Client |
