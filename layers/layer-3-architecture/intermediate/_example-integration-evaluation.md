---
title: ""
last_updated: ""
---

# Integration Evaluation: [Capability or Use Case]

A structured comparison of options for a third-party service, library, or integration approach. Use this when the choice between options has meaningful trade-offs that affect architecture, cost, or long-term maintainability.

The output of this evaluation feeds directly into the [Tech Stack Rationale](../final/tech-stack-rationale.md) and, if the decision is architecturally significant, into an [ADR](../final/adrs/).

---

## Use Case

*What capability or problem are we evaluating solutions for? Who needs it and why does it matter for the product?*

> Examples:
> - Background job processing for sending transactional emails and running scheduled data exports
> - Full-text search across product catalog with faceted filtering
> - Real-time event streaming between microservices

---

## Evaluation Criteria

*What matters most for this decision? Define criteria before evaluating options — this prevents post-hoc rationalization.*


| Criterion | Weight | Notes |
| --------- | ------ | ----- |
| | High / Medium / Low | |


> Common criteria: integration complexity, operational overhead, cost at scale, vendor maturity/support, alignment with existing stack, data residency requirements, open-source vs. proprietary, lock-in risk.

---

## Options Evaluated


| Option | Description | Pricing | Pros | Cons | Fit |
| ------ | ----------- | ------- | ---- | ---- | --- |
| Option A | | | | | High / Medium / Low |
| Option B | | | | | High / Medium / Low |
| Option C | | | | | High / Medium / Low |


---

## Recommendation

**Recommended:** [Option name]

*Why this option over the alternatives — address the key criteria directly. If the decision is close, name what would change it.*

---

## Risks

*What could go wrong with the recommended option? What would need to be monitored or mitigated?*


| Risk | Likelihood | Impact | Mitigation |
| ---- | ---------- | ------ | ---------- |
| | High / Medium / Low | High / Medium / Low | |


---

## References

*Documentation, pricing pages, benchmarks, and any other sources consulted.*
