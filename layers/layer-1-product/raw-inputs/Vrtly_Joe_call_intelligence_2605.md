# Vrtly — Joe Call Intelligence
**Meeting date:** May 26, 2026
**Source:** Transcript-meeting2605.md
**Participants (Vrtly):** Joe (CTO / Lead Engineer), David (Product Designer)
**Purpose of this document:** Distill everything Joe and David said that is directly relevant to the audit. To be used as a reference going into access, discovery, and week 1–2 work.

---

## What Joe confirmed about the current telemetry state

This is the most audit-critical section. Joe clarified the exact technical state of telemetry, which validates the approach presented in the deck and surfaces key gaps to investigate.

**Architecture confirmed:**
- Telemetry flows through a **real-time WebSocket** that opens on each device and streams events directly to an **Elasticsearch index** (called the telemetry index)
- Visualization is done in **Kibana** — the team builds ad-hoc dashboards on top of the events coming through
- There is **no Grafana, no Prometheus, no structured alerting layer** on top of this data today

**The core problem Joe named explicitly:**
- When the WebSocket closes, visibility ends. The team cannot see anything that led up to that closure.
- They know *what content was playing* at the moment of disconnect, but they do not know *why* it closed — network issue, app crash, content fetch failure, or something else
- Joe's words: *"we don't know what we don't know"* — even a blank-screen event as a detectable signal does not exist client-side today

**What telemetry coverage looks like today:**
- Joe estimated approximately **50 standard failure mechanisms** for a smart TV app
- Vrtly currently covers roughly **4% of those mechanisms**
- This means ~48 of 50 known failure types are invisible in production today
- The 80% telemetry target in their mitigation plan is **not** about 80% of all devices — it is about implementing the standard QoE signals that cover those failure mechanisms, scoped to the 50% of the fleet that stays (html5core, Roku, Android)

**Joe's strategy and the Netflix reference:**
- Joe wrote a technical doc modeled directly on **Netflix's Quality of Experience research blog** — he pulled the standard QoE event taxonomy from there and is using it as the basis for what Vrtly should instrument
- His stated plan: implement the standard signals → get true positive blank-screen events in the lab → release to production → use telemetry fingerprints to confirm those patterns in the wild
- He explicitly said this is the correct sequencing: telemetry first, then QA validation, then proactive production monitoring

**Sentry came up:**
- When Sentry was mentioned in the call, Joe responded positively — specifically because Sentry can **cache events and handle callbacks** even when the WebSocket drops, which solves the core gap in the current architecture
- This is a signal worth pursuing: Sentry (or equivalent) as a resilient event layer on top of or replacing the WebSocket-only approach

---

## What Joe confirmed about the existing infrastructure

Joe pushed back on the assumption that infrastructure is broken. This is an important nuance for the audit.

**What does exist and works:**
- **Canary deploy capability exists** — they can modulate which server an app pulls from at runtime, enabling server-side and client-side changes to be rolled out selectively
- **Feature flags by org ID exist** — new experiences can be scoped to specific practice organizations before broader rollout
- The telemetry service itself (Elasticsearch + WebSocket) is described as *"good"* as infrastructure — the problem is not the pipeline, it's the lack of clarity about *what data to put in it*
- **Device classification**: Joe wrote a script that scrapes the user agent, runs it through Claude Haiku as a classifier, and enriches unknown devices via a nightly Google search. Currently **96–98% accurate** for identifying hardware type, OS, and device specs

**The actual problem Joe named:**
> *"It's just the team doesn't know what data to put in there yet, and the infrastructure is good and robust... It's just the technical strategy of what should be in here."*

And separately on the engineering team's behavior:
> *"The engineering team is really, really bad at monitoring system health. When they launch something, they say it's done — but there's no data that shows this is a healthy system."*

This reframes the audit: the technical infrastructure is more capable than it looks from the outside. The deficit is in **observability strategy, QA discipline, and engineering operating norms** — not purely in missing tools.

---

## What Joe confirmed about adaptive streaming

Joe confirmed they have **HLS.js with adaptive bitrate streaming (ABR)** in place — this is standard out of the box. However:
- He does not know if the ABR implementation is healthy
- He does not know what specifically triggers level switches down
- His stated concern: the team ships something, calls it done, and he has never seen data that shows it's actually functioning as intended

This is a concrete investigation target for the audit: inspect how ABR is configured, what triggers it, and whether the implementation is actually doing what it's supposed to do.

---

## What David (Product Designer) revealed about QA and the activation problem

**QA state:**
- One QA person on the team — "not senior, but pretty good"
- QA is nominally involved early in planning, but test cases don't actually get written until development is nearly complete
- Testing rarely finishes before shipping
- When bugs are found post-release, root cause is sometimes unknown and often cannot be reproduced
- The current response to an unreproducible black screen: wait for the next customer report
- No reliable staging environment that replicates production conditions for triggering blank screens

**Why this matters to the business (David's framing):**
- The activation funnel is already hard — customers have to acquire a screen, set it up, and activate it
- When a screen goes blank after activation, users lose trust immediately
- Most do not reach out to support — they simply stop using the product (especially on the free tier)
- David's words: *"we just need to know how big of an impact this is"* — even quantifying churn caused by blank screens is currently impossible

**David's testing suggestion for the audit:**
- Look at which active screens are used most
- Focus initial blank-screen detection work on the **two most-used platform types** rather than all six runtimes simultaneously

---

## Fleet scope clarification — what stays vs. what goes

Joe was not fully explicit about the exact breakdown, but based on the deck alignment and what was confirmed:

| Platform | Status |
|---|---|
| html5core (FireTV, Samsung Tizen, LG WebOS) | **Stays** — in scope for Phase 1 |
| Roku | **Stays** — in scope for Phase 1 |
| Android (Google TV + external HDMI device) | **Stays** — in scope for Phase 1 |
| iOS (iPads, iPhones) | **Phasing out / lower priority** — legacy |

The 80% telemetry target, Phase 1 work, and audit scope should all be limited to the three workstreams above. Joe was explicit that there are approximately **600 different device types** across the fleet — the 80% target is not about covering all 600, it's about implementing the standard signals that will surface the dominant failure patterns across the supported platforms.

---

## Active firefight context (VT-5083 or equivalent)

Joe confirmed there is an **active firefight running across most backend services** at the time of this call. The deck framed this as VT-5083. Key consideration for the audit:
- We need to assess whether this needs to resolve before Phase 1 can start cleanly, or whether they can run in parallel
- Joe did not indicate a clear timeline for resolution
- This should be one of the first questions asked when Slack access is set up

---

## China SOW — separate but parallel

Joe raised a second workstream during the call: a China deployment.
- **Plan**: take Docker images from AWS, migrate them to **Alibaba Cloud**, deploy on an **open Android box** running the APK in **kiosk mode**, operating in mainland China over the Great Firewall
- This is not directly related to the telemetry/reliability audit but is a potential early project to get an engineer up to speed on the Vrtly infrastructure
- Joe indicated it's mostly a Docker-to-Alibaba-Cloud migration — whoever does it needs strong container experience
- Ryan agreed to set up a SOW for this in parallel

---

## Key unknowns going into access

These are things Joe did not clarify or that were left open in the call — to be resolved during the demo and week 1 access:

1. **Exact state of VT-5083** — what services are affected and what the resolution timeline looks like
2. **What specific events are currently being sent to Elasticsearch** — the full event schema and coverage map
3. **Whether Kibana dashboards exist for current monitoring**, or if it's purely ad-hoc queries
4. **HLS.js ABR configuration** — what thresholds are set and whether they've ever been validated
5. **Which repo is responsible for the WebSocket telemetry client** — player-side vs. shared infrastructure
6. **What Joe's Netflix-based technical doc contains** — he offered to share it; we should request it
7. **Whether there is any alerting on top of Elasticsearch today** — even basic alerts on WebSocket drops or error rate spikes
8. **The exact release process per platform** — Joe confirmed canary capability exists, but how it's actually used in practice is unclear

---

## What was agreed as next steps from the call

| Action | Owner | Notes |
|---|---|---|
| Set up Slack group channel | Ryan | For the full cross-team group, with individual pairing as needed |
| Provide repo access to Rafa | Vrtly / Ryan | On Rafa's personal account, not just the DualBoot corporate account |
| Schedule product demo | Joe | Joe offered — "you guys can see the product and why people are excited" |
| Set up audit SOW | Ryan / Joe | Target: this week |
| Set up China SOW | Ryan / Joe | Parallel to main audit SOW |
| Work starts ahead of SOW | DualBoot | Ryan confirmed: CFO approved a couple weeks of runtime pre-SOW |

---

## Signals for framing the audit output

Based on what Joe said directly, the audit report should reflect:

- **Infrastructure is not the problem** — avoid framing recommendations as "you need to rebuild your stack." The stack is capable. The problem is observability strategy, signal design, and engineering operating discipline.
- **Telemetry coverage is the unlock** — without 50-mechanism coverage, everything downstream (QA validation, production monitoring, root cause analysis) is guesswork. This is correctly sequenced as Phase 1.
- **Sentry (or equivalent resilient event layer)** is a natural recommendation — Joe already validated the concept when it was raised. The WebSocket drop-on-failure problem is real and acknowledged.
- **Grafana** was raised as a strong recommendation by our team and Joe did not push back. Currently absent from their stack. Recommending it as the visualization layer over the existing Elasticsearch data is well-grounded.
- **ABR implementation health** is a concrete, auditable item — Joe himself flagged uncertainty about it.
- **QA process** is broken not because QA doesn't exist, but because there is no structured planning or ownership of what to test, and no reproducible failure environment.
- **Team behavior** is a factor Joe will want us to name clearly — he is frustrated that the engineering team does not proactively monitor, does not validate launches, and does not surface problems until customers do. Our assessment should address this directly.
