---
title: "html5core Telemetry — 80% Coverage Evaluation"
owner: "Tech Lead"
status: in_progress
last_updated: 2026-06-15
relates_to:
  - layers/layer-3-architecture/intermediate/html5core-telemetry-analysis.md
  - layers/layer-3-architecture/intermediate/html5core-telemetry-feasibility-assessment.md
  - layers/layer-3-architecture/intermediate/html5core-playlist-playback-flow.md
  - layers/layer-3-architecture/intermediate/html5core-playlist-update-flow.md
  - layers/layer-3-architecture/intermediate/blank-screen-scenarios.md
---

# html5core Telemetry — 80% Coverage Evaluation

**Audit question:** Map what specifically needs to be built to get to 80% telemetry coverage, and whether that is realistic given where things stand today.

**Scope:** html5core fleet — full system stack (html5core player, fmcom-player-api, fmcom-api, RNF, State Service). Two flows analyzed: the player lifecycle (boot to steady-state playback) and the content-update delivery path (admin change through device reload). Roku and Android out of scope.

**Two coverage metrics — tracked separately:**

- **Blank-screen coverage (80% target):** the blank moment is logged and the data is sufficient to diagnose the incident without physical device inspection. Denominator: scenarios where the device actually goes blank (~21 of 25).
- **Content delivery coverage (complementary metric):** the backend registers that it did not receive confirmation the device applied a content update. Denominator: the 4 stale-content scenarios (S-7, S-17, S-23, S-24) where the device never goes blank as a direct result of the failure, but stale content can become unplayable and cause a blank screen later whose causal origin is no longer traceable without this signal.

---

## Where Things Stand Today

| Signal | Today |
|---|---|
| Blank moment logged | **0 / 21 blank-screen scenarios (0%)** |
| Recovery logged (at least partial) | 9 / 25 (36%) |
| Causal context preserved (at least partial) | 8 / 25 (32%) |
| Content delivery confirmation (stale-content scenarios) | **0 / 4 (0%)** — no backend signal when a device fails to receive a content update |

The baseline for both metrics is zero. The telemetry pipeline exists; the events are not being emitted, and the delivery confirmation infrastructure does not exist.

---

## What Specifically Needs to Be Built

The analysis produced 27 findings: **kill zones** (code tries to log but the signal doesn't survive) and **instrumentation gaps** (code never attempts to log the failure path).

| Category | Count | Fixable without architectural changes? |
|---|---|---|
| Instrumentation gaps | 12 | Yes — all 12 |
| Kill zones | 11 | 7 yes, 4 no |
| Structural / architectural | 4 | No |
| **Total** | **27** | **19 fixable, 4 not** |

### html5core Player — 12 findings

Two releases required. Cannot be combined.

**Bucket A — Low effort, high impact (6 findings, ~3–4 days development):**

| Change | What it enables |
|---|---|
| Remove unconditional `return` on line 38 of `serverLogger.ts` | Re-enables the proactive error-reporting path silently dead in production. Gate: validate downstream pipeline in staging before any other change ships. |
| Emit `PlaylistCleared` event at `setPlaylist([])` call site with trigger context | Logs the blank moment for every content reload (CONTENT_CHANGED, watchdog, initial-load). Covers S-20, S-22, and boot blank window. |
| Emit error event in `apiRequest()` when response is `{}` | Logs the fetch failure that leaves the screen blank and is currently invisible (S-21, boot CC path). |
| Add retry counter telemetry in `checkActivation.ts` | Logs stuck activation cycles (S-5, S-12). Currently only success is recorded. |
| Emit telemetry at `isConsults` guard-return in `reloadCurrentPlaylist()` | Logs every CONTENT_CHANGED silently dropped during consultation mode (S-22). |
| Add `consecutiveCount` field to PlaybackWatchdog event | Distinguishes a single healthy watchdog recovery from a sustained reload loop (S-3). |

**Bucket B — Moderate effort (6 findings, ~2–2.5 weeks development):**

| Change | What it enables |
|---|---|
| localStorage buffer cap + FIFO eviction (~200 events max) | Prevents OOM-driven event loss when device OOMs before 5-min flush timer fires. |
| HTTP fallback transport for telemetry | Closes the kill zone where a WS batch is lost mid-send. Also required for the finding below. |
| Emit `ConnectionState` failure event via HTTP when WS handshake fails | Closes the gap where WS establishment failure produces no device-side signal. Blocked on HTTP fallback. |
| Log dropped concurrent reload + optionally re-fetch | Closes silent drop when a second CONTENT_CHANGED arrives during an active playlist load. |
| Add `trigger` field to `PlaybackState.None` transitions | Distinguishes "blank before fetch" (failure) from "blank at end of item" (normal). |
| Add `currentContentId` to watchdog telemetry payload | Identifies which content item caused a playback failure. |

### Backend — 11 findings

Deploy independently of html5core. Can be parallelized with player development.

| Priority | Change | Enables |
|---|---|---|
| **Gate** (before any html5core ships) | Fix TelemetryController exception swallow in `TelemetryEventAnalyzerService` | Hard deployment gate — new client-side events will fail silently without this. |
| Week 1 | fmcom-player-api broker client eviction alert | Surfaces when player-api silently misses messages from the State Service broker. |
| Week 1 | DLQ on all `PLAYER_*` Amazon MQ destinations + redelivery policy | Closes the kill zone where transient MQ failures silently drop `PLAYER_CONTENT_TRANSCODED`. |
| Week 2 | CONTENT_CHANGED delivery confirmation + correlation ID (transcode → device reload) | End-to-end visibility for content delivery coverage. Single owner must be assigned week 1 — spans fmcom-api, RNF, player-api, and html5core. |
| Week 2 | Per-screen "last successfully generated" timestamp + staleness alert (>25h) | Detects screens silently stuck on stale playlists (S-8, S-15, S-10). |
| Week 2 | RNF generation timeout metric + alert | Closes the gap where `waitForCompletion` returns null silently with no metric (S-8). |
| Week 2 | UnsentNotice expiry counter metric | Makes visible how often CONTENT_CHANGED notices are discarded by the 30-second TTL. |
| Week 3 | RNF `System.exit(-1)` dedicated metric | Distinguishes RNF crash via State Service ping from other crash causes (S-1). |
| Week 3 | FAILED transcode alert threshold | Surfaces transcode failures leaving screens with no playable content (S-4, S-9). |
| Week 3 | Subscription tier suppression metric (FREE/LOCKED) | Surfaces when FREE/LOCKED screens are playing stale content beyond expected refresh window (S-25). |
| Infra | ALB sticky sessions | Eliminates cross-node WebSocket delivery failure (S-23) with one day of infrastructure work. |

### What Cannot Be Fixed Without Architectural Redesign — 4 findings

| Issue | Scenario | What it would take |
|---|---|---|
| State Service in-process broker loses messages on OOM-kill (SIGKILL) | S-17 | Migrate `PLAYER_*` to Amazon MQ (durable, at-least-once delivery) |
| fmcom-api JMS publish deferred post-commit — JVM crash in gap drops the message | S-7 | Transactional outbox pattern in fmcom-api |
| Cross-node WS delivery — device's WS on node B, CONTENT_CHANGED on node A | S-23 | ALB sticky sessions closes it without full redesign (~1 day infra) |
| fmcom-player-api broker client offset eviction after 5-min inactivity | S-24 (partial) | Increase heartbeat frequency below 5-min eviction threshold |

---

## Is It Realistic

### Blank-screen coverage (target: 17 / 21 scenarios — 80%)

**One month: No.**
The html5core release cycle requires a device regression pass (FireTV, webOS, Tizen) with 1 QA engineer — 5–8 days per release. Two releases are needed. This alone prevents full implementation in one calendar month.

End of month 1: Bucket A html5core + all backend findings deployed. Blank moment logged in approximately **8–10 of 21 blank-screen scenarios**.

**Two months: Yes.**
All 19 reparable findings deployed by end of month 2. Blank moment logged in approximately **14–17 of 21 blank-screen scenarios** — 67–81%. The upper end of that range reaches the 80% target; the lower end is one scenario short. The difference depends on how consistently S-1 and S-5/S-6 are covered by the combination of player + backend signals deployed.

### Content delivery coverage (target: 4 / 4 stale-content scenarios)

The 4 stale-content scenarios (S-7, S-17, S-23, S-24) are covered by backend findings already included in the 19 reparable items: delivery confirmation metric, UnsentNotice expiry counter, and absence alerts. These deploy independently of html5core.

**Two months: Yes, for 3 of 4.** S-7 (JMS post-commit gap) and S-17 (State Service OOM-kill) cannot be fully closed without architectural changes — the fix prevents the failure from occurring, not just detecting it after the fact. The backend delivery confirmation signals will surface that content failed to arrive, but cannot guarantee delivery without the structural fix. S-23 (cross-node WS) is closable with ALB sticky sessions. S-24 (UnsentNotice TTL) gets an expiry metric that surfaces the drop, though the TTL itself is an architectural constraint.

### Team required

| Role | Month 1 | Month 2 |
|---|---|---|
| Backend developer (mid-senior) | Full-time | Full-time |
| Frontend developer (mid-senior, html5core familiarity) | Full-time | Full-time |
| QA engineer | ~Full-time weeks 2–4 | Full-time weeks 5–8 |
| DevOps / Infra | ~0.25 FTE | ~0.25 FTE |

If architectural items (State Service broker migration) are scoped, add one senior backend engineer.

---

## Critical Path — Non-Negotiable Sequencing

1. **`serverLogger.ts` fix first.** One line removal. Validate the downstream pipeline in staging end-to-end before any other html5core change ships. `sendIssue()` has been dead code in production; its pipeline has never been exercised at scale.

2. **TelemetryController gate.** Must be deployed before any html5core instrumentation release. New client-side events will fail silently otherwise.

3. **Bucket A before Bucket B.** Two separate html5core releases.

4. **Correlation ID owner assigned in week 1.** The delivery confirmation metric spans fmcom-api, RNF, player-api, and html5core. Without a single owner from the start, design alignment stalls and this finding misses month 2.

---

## Open Questions

1. **ALB sticky sessions in month 1?** Closes S-23 with ~1 day of infra work. Low risk, eliminates a structural gap without an architectural rewrite. Recommended to scope in.

2. **Staged html5core rollout?** If Bucket A can be deployed to a subset of the fleet first (5–10 devices), the QA regression cycle compresses and Bucket B could potentially ship in month 1.

3. **State Service broker migration scope:** If full content delivery coverage for S-17 is required (guarantee delivery, not just detect failure), a 2-week architecture spike would produce a reliable effort estimate for migrating `PLAYER_*` to a durable Amazon MQ topology.
