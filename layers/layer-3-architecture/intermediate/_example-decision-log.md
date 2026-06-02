---

## title: ""
last_updated: ""

# Decision Log

A running record of technical decisions made during architecture work. Lower ceremony than ADRs — captures the decision, date, and brief rationale as decisions happen, so the reasoning is not lost in Slack threads or meeting notes.

**When to use this vs. an ADR:** Use the decision log for any decision you want to record. Promote a decision to a formal [ADR](../final/adrs/) when it meets one or more of these criteria:

- It affects system boundaries, data architecture, or the tech stack
- It involves trade-offs that future engineers or tech leads need to understand
- It is likely to be revisited or challenged
- It has compliance, security, or operational implications

Decisions that stay in this log are still valid and traceable — they just don't warrant the full ADR format.

---

## Decisions


| #   | Date | Decision | Rationale | Owner | Promoted to ADR                |
| --- | ---- | -------- | --------- | ----- | ------------------------------ |
| 1   |      |          |           |       | — / [ADR-XXXX](../final/adrs/) |
| 2   |      |          |           |       | — / [ADR-XXXX](../final/adrs/) |


---

## How to Use

Add a row for each decision as it is made. Keep rationale brief — one or two sentences is enough. If a decision is later superseded or reversed, update the row rather than deleting it and note the date and reason for the change. This preserves the decision history even when directions change.

When a decision gets promoted to an ADR, link to the ADR in the "Promoted to ADR" column. The ADR becomes the authoritative record — this log entry becomes a historical reference.