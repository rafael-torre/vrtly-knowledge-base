---
title: ""
last_updated: ""
---

# Tech Spike: [Question Being Investigated]

A structured record of a time-boxed technical investigation. Use this when you need to validate a technical approach, test feasibility, or answer a specific question before committing to an architectural direction.

Tech spikes are meant to be quick — written in an hour, not a day. The goal is to capture enough to inform a decision, not to be comprehensive. If the findings are significant enough to shape an architectural decision, they feed into an ADR or the Architecture Overview.

---

## Question

*What specific technical question is this spike trying to answer? Be precise — a well-framed question produces a useful answer. Vague questions produce vague results.*

> Examples:
> - Can we achieve sub-200ms p95 latency for the search endpoint under 1,000 concurrent users with our current stack?
> - Is Postgres full-text search sufficient for our use case, or do we need a dedicated search service?
> - Can the third-party payment provider's webhook system handle our expected event volume reliably?

---

## Approach

*How did you investigate? What did you build, measure, or read? Keep this brief — just enough context to understand the findings.*

- Time boxed to: ___ hours
- Method: *(prototype / benchmark / API exploration / documentation review / other)*

---

## Findings

*What did you learn? Be specific. Include numbers, error messages, or concrete observations where they matter.*

---

## Recommendation

*Given the findings, what do you recommend? This should be a clear, opinionated answer to the question above.*

**Proceed with / Do not proceed with / Needs further investigation:** [choice]

*Rationale in 1-2 sentences.*

---

## Open Questions

*What remains unknown after this spike? What would need to be true for the recommendation to change?*

---

## References

*Links to documentation, benchmarks, code, or other materials consulted during the spike.*
