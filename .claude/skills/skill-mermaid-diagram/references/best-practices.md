# Mermaid Architecture Diagram — Best Practices

## Table of Contents
1. [Core rules](#core-rules)
2. [Node rules](#node-rules)
3. [Relationship rules](#relationship-rules)
4. [Subgraph rules](#subgraph-rules)
5. [Anti-patterns](#anti-patterns)
6. [Node label templates](#node-label-templates)
7. [Self-check checklist](#self-check-checklist)

---

## Core rules

| Rule | Rationale |
|---|---|
| Use `flowchart TD` | C4Container is experimental in Mermaid — layout breaks on complex graphs. `flowchart TD` is stable and gives better control. |
| One diagram per concern area | A single diagram with 30+ nodes and 40+ edges is unreadable. Splitting by concern keeps each view purposeful. |
| Max 15 nodes per diagram | Beyond 15, Mermaid auto-layout starts crossing arrows and compressing labels. |
| Max 8 labelled edges per diagram | More than 8 arrows creates "spaghetti". If you need more, split the diagram. |
| Always label arrows | Unlabelled arrows force the reader to guess the relationship. One short label (e.g., `REST /api/v1/*`) is enough. |
| Mark gaps with ⚠️ | Services whose internals are unknown get a ⚠️ in their node label so readers know what needs investigation. |

---

## Node rules

- Use `["..."]` for rectangular nodes (services, apps, infra)
- Use `[("...")]` for database/storage nodes — renders as cylinder in most Mermaid renderers
- Keep label text to 2–3 lines max:
  - Line 1: service name + ⚠️ if gap
  - Line 2: key responsibilities (comma-separated, max 3)
  - Line 3 (optional): deployment / URL / version note

**Good node label:**
```
ClientApp["Mobile App\nAuth · order tracking · notifications\nReact Native / iOS + Android"]
```

**Bad node label:**
```
ClientApp["Mobile App - React Native, TypeScript, Redux - handles authentication, order tracking, push notifications, profile management, payment flow, and settings"]
```

---

## Relationship rules

- Label every arrow with protocol and/or purpose: `-->|"REST /orders/* · JWT auth"|`
- Use `-->` (solid) for synchronous calls
- Use `-.->` (dashed) for async / fire-and-forget
- Direction: put the caller above the callee in TD diagrams — arrows flow downward naturally
- Aggregate parallel relationships: if A calls B via 3 REST endpoints, use one arrow labelled `REST /api/*` not three separate arrows

**Good:**
```
ClientApp -->|"REST /api/v1/* · JWT"| APIGateway
ClientApp -->|"WSS · real-time updates"| APIGateway
```

**Bad (too noisy):**
```
ClientApp -->|"POST /api/v1/orders"| APIGateway
ClientApp -->|"GET /api/v1/orders/{id}"| APIGateway
ClientApp -->|"PUT /api/v1/orders/{id}/cancel"| APIGateway
ClientApp -->|"WS upgrade"| APIGateway
ClientApp -->|"WS order status push"| APIGateway
```

---

## Subgraph rules

- One subgraph per deployment boundary or system boundary
- Label format: `subgraph id["Human-Readable Name · Deployment Note"]`
  - Example: `subgraph OrderSvc["Order Service · Node.js / Kubernetes"]`
- Keep actors (users, devices) outside subgraphs — they are personas, not containers
- External third-party services outside subgraphs — they have their own boundaries

---

## Anti-patterns

| Anti-pattern | Why it's bad | Fix |
|---|---|---|
| C4Container for complex systems | Layout is unreliable beyond ~10 nodes in Mermaid | Use `flowchart TD` |
| One diagram for the whole system | >15 nodes creates unreadable output | Split into focused views |
| Unlabelled arrows | Reader can't tell if it's REST, WS, gRPC, queue, etc. | Always label |
| Node labels with full paragraph text | Labels get clipped or overlap | Max 3 short lines |
| All relationships same style | Sync and async calls look identical | Use `-->` vs `-.->` |
| Showing internal DB table names | Adds noise at this level of abstraction | Show DB name + type only |
| Actors inside subgraphs | Actors are outside the system boundary | Place actors above the first subgraph |

---

## Node label templates

**Service / API:**
```
ServiceId["Service Name\nResponsibility 1 · Responsibility 2\nStack or deployment note ⚠️ if gap"]
```

**Database / cache:**
```
MainDB[("Primary DB\nCore domain data\nPostgreSQL / managed")]
```

**Queue / broker:**
```
EventBus["Message Broker\nAsync event bus\nDomain event topics"]
```

**External system:**
```
PaymentGw["Payment Gateway\nBilling + subscription mgmt"]
```

**Actor / user:**
```
EndUser["👤 End User\nBuys and tracks orders"]
```

---

## Self-check checklist

Before delivering diagrams, verify each one:

- [ ] Uses `flowchart TD` (not C4Container, not graph LR)
- [ ] 15 nodes or fewer
- [ ] 8 labelled relationships or fewer
- [ ] Every arrow has a label
- [ ] Every gap/unknown service has ⚠️ in its label
- [ ] Actors are outside subgraphs
- [ ] External third-party services are outside subgraphs
- [ ] No node label exceeds 3 lines
- [ ] Async relationships use dashed arrows `-.->`
- [ ] View 1 (Context) shows no internal detail — system areas only
