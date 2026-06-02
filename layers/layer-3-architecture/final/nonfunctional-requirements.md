---
title: Non-functional Requirements
layer: architecture
owner: ""
last_updated: ""
relates_to:
  - layers/layer-1-product/final/success-metrics.md
  - layers/layer-1-product/final/product-brief.md
  - layers/layer-3-architecture/final/architecture-overview.md
status: in_progress
---

# Non-functional Requirements

The quality attributes this system must meet — how it must perform, scale, protect, and recover, independent of what features it provides. These requirements constrain every Feature Technical Spec and inform every architectural decision.

Requirements here should be **specific and measurable**. "The system should be fast" is not an NFR. "API responses must meet p95 latency ≤ 300ms under 500 concurrent users" is an NFR.

Each section uses a table as the primary format. Prose is used only to provide context that the table cannot convey.

---

## Performance

Latency and throughput targets. Set based on user experience expectations from Layer 1 and technical constraints from the architecture.

> **Guiding questions:**
>
> - What are the latency targets for user-facing operations? Distinguish between p50, p95, and p99 where relevant.
> - What are the throughput targets — requests per second, transactions per minute, events per hour?
> - Are there different tiers of performance requirements — for example, read operations vs. write operations, or interactive flows vs. background processing?
> - What does "acceptable degraded performance" look like — what can slow down before it becomes a product problem?


| Requirement | Target | Measurement Method | Priority |
| ----------- | ------ | ------------------ | -------- |
| API response latency (p95) | ≤ ___ ms | Load test at ___ concurrent users | Must / Should / Nice to have |
| Page load time (LCP) | ≤ ___ s | Lighthouse / Real User Monitoring | Must / Should / Nice to have |
| Background job throughput | ___ jobs/min | Queue depth monitoring | Must / Should / Nice to have |


---

## Scalability

How the system must grow to handle increased load — users, data volume, or event throughput.

> **Guiding questions:**
>
> - What is the expected user load at launch? What is the growth projection (6 months, 1 year, 3 years)?
> - What is the peak load scenario — what event or time of day creates the highest traffic?
> - What are the data volume expectations — how much data will be stored, and how does it grow?
> - Which components must scale horizontally? Which can scale vertically?
> - Is there a cost constraint on scaling — a maximum infrastructure spend per month?


| Requirement | Target | Notes |
| ----------- | ------ | ----- |
| Concurrent users at launch | | |
| Peak concurrent users (projected) | | |
| Data volume at launch | | |
| Data volume (12-month projection) | | |
| Scaling model | Horizontal / Vertical / Auto-scaling | |


---

## Availability and Reliability

Uptime targets, failure handling, and recovery expectations.

> **Guiding questions:**
>
> - What uptime is required? Is there a formal SLA with the client?
> - What are the planned maintenance windows, if any?
> - What is the maximum acceptable downtime per month (translate the uptime % into minutes)?
> - What happens when a dependency (database, third-party API) is unavailable — does the system degrade gracefully or fail hard?
> - What are the Recovery Time Objective (RTO) and Recovery Point Objective (RPO) for data loss scenarios?
> - Are there any components where higher availability is critical (payment processing, authentication)?


| Requirement | Target | Notes |
| ----------- | ------ | ----- |
| Target uptime | ___% (≤ ___ min/month downtime) | |
| RTO (recovery time objective) | ≤ ___ hours | Time to restore service after failure |
| RPO (recovery point objective) | ≤ ___ hours | Maximum acceptable data loss window |
| Graceful degradation | Required / Not required | Which features degrade, which fail hard |


---

## Security

Security requirements that apply across the system. Feature-specific security details belong in Feature Technical Specs. This section captures the system-wide baseline.

> **Guiding questions:**
>
> - What compliance standards apply? (GDPR, HIPAA, PCI-DSS, SOC 2, ISO 27001)
> - What data classification tiers exist — what is considered sensitive, confidential, or public?
> - Are there penetration testing or vulnerability scanning requirements?
> - What are the authentication strength requirements — MFA, session timeout, password policy?
> - Are there network security requirements — VPC isolation, IP allowlisting, WAF?
> - How must audit logs be maintained — what events must be recorded, for how long?


| Requirement | Standard / Target | Notes |
| ----------- | ----------------- | ----- |
| Compliance | | |
| Data encryption at rest | Required / Not required | Algorithm or standard if specified |
| Data encryption in transit | TLS ___ | |
| Authentication | | |
| Audit logging retention | ___ months | |
| Vulnerability scanning | Frequency | |


---

## Observability

What must be visible about the system's health and behavior so that issues can be detected and diagnosed.

> **Guiding questions:**
>
> - What must be logged — what events, errors, and state changes are required in logs?
> - What metrics must be collected — latency, error rates, queue depth, resource utilization?
> - What tracing is required — distributed tracing across services for request flows?
> - What alerting must exist — what conditions require immediate notification, and who is notified?
> - Is there a specific observability platform or tooling requirement (Datadog, Grafana, CloudWatch)?


| Requirement | Target | Notes |
| ----------- | ------ | ----- |
| Log retention | ___ days | |
| Error rate alerting threshold | ___% over ___ minutes | |
| Latency alerting threshold | p95 ≥ ___ ms over ___ minutes | |
| Tracing | Required / Not required | |
| Observability platform | | |


---

## Compliance

Regulatory, contractual, or client-mandated requirements that the system must meet. Reference the Layer 0 Strategic Goals and Constraints for the business context behind these requirements.

> **Guiding questions:**
>
> - Are there data residency requirements — must data be stored in a specific country or region?
> - Are there right-to-erasure (GDPR Article 17) requirements — how must user data be deleted on request?
> - Are there data retention mandates — how long must data be kept before it can be deleted?
> - Are there accessibility compliance requirements (WCAG AA/AAA)?
> - Are there export control or contractual restrictions on data sharing?


| Requirement | Standard / Mandate | Owner | Notes |
| ----------- | ------------------ | ----- | ----- |
| | | | |


---

## Open Questions

Unresolved NFR items. This section should be empty when the document reaches `status: established`.


| Question | Context | Owner | Target Date | Status | Resolution |
| -------- | ------- | ----- | ----------- | ------ | ---------- |
| | | | | Open / Resolved | |
