---
title: "Telemetry Feasibility Assessment — html5core: 80% Coverage in 1 Month"
owner: "Tech Lead"
status: in_progress
last_updated: 2026-06-12
relates_to:
  - layers/layer-3-architecture/intermediate/telemetry-analysis-html5core.md
  - layers/layer-3-architecture/intermediate/playlist-update-flow-html5core.md
  - layers/layer-3-architecture/intermediate/blank-screen-scenarios.md
---

# Telemetry Feasibility Assessment — html5core: 80% Coverage in 1 Month

**Scope:** html5core fleet. Assessment based on the outputs of Step 0 (flow N0–N8) and Step 1 (10 kill zones, 11 instrumentation gaps). Roku and Android are out of scope.

**Central question:** Based on the kill zone and instrumentation gap analysis, is it feasible to reach 80% telemetry coverage in html5core within 1 month?

**Analysis participants:** Winston (architect), Amelia (dev), John (PM, moderator).

---

## Operational Definition of 80%

For the number to be measurable and honest, 80% coverage is defined as:

> For 80% of blank screen incidents occurring in the html5core fleet, there is at least one observable telemetry signal **at the moment of the blank or within the following 5 seconds** that allows identifying the causal node.

"Identifying the causal node" means distinguishing between:
- Blank from expected normal reload (setPlaylist([]) window)
- Blank from failed fetch
- Blank from discarded CONTENT_CHANGED (consults mode or concurrent guard)
- Blank from watchdog loop

This definition **deliberately excludes the WATCHDOG at 20 seconds** as a valid signal toward the 80% — that event is recovery, not diagnosis. It does not identify the cause; it only confirms the device is still blank.

**Current baseline:** ~0%. In none of the analyzed scenarios is the moment of the blank logged. The only observable event in most cases is the late WATCHDOG with no causal context.

---

## Work Distribution by Dimension

### Kill zones — Dimension 1 (10 total)

| Location | Count | Fixable in 1 month |
|---|---|---|
| html5core | 2 (KZ-1, KZ-2) | Yes — code changes in the player |
| Backend (fmcom-api, RNF, State Service, fmcom-player-api) | 8 (KZ-3 to KZ-10) | Not in 1 month — require infrastructure changes: outbox pattern, persistent Amazon MQ, Redis for offsets and UnsentNotice |

The 8 backend KZs affect infrequent failure paths: RNF timeout, State Service OOM-kill, transcoding pipeline failure, device offline >30s on cross-node ECS. They are critical in depth but not in daily frequency.

### Instrumentation gaps — Dimension 2 (11 total)

| Location | Count | Fixable in 1 month |
|---|---|---|
| html5core | 9 (IG-1 to IG-8, IG-10, IG-11) | Yes — add telemetry events in the player |
| Backend (fmcom-api, RNF) | 2 (IG-5, IG-9) | Require changes in backend services |

The 9 html5core gaps cover the most frequent blank screen paths: consultation mode drop, concurrent drop, setPlaylist([]) window, CONTENT_CHANGED receipt, fetch failure at the moment of failure, unknown contentType, empty combined playlist filter, and watchdog with enriched cause.

---

## Feasibility Verdict

**80% is technically achievable in 1 month, with conditions.**

If the 80% is measured against device-side blank screen scenarios — which are the most frequent — all required changes are in html5core and are within the scope of 1 month of development. The 8 backend KZs affect infrastructure failure scenarios that do not represent the bulk of reported incidents.

If the 80% is measured against all scenarios including backend KZs, **the achievable number drops to 50–60% in the same timeframe**, because those KZs require infrastructure changes across multiple services with cross-team coordination.

**Unvalidated assumption — requires data before the verdict is defensible:** The conclusion that 80% is achievable with html5core-only changes rests on the claim that device-side blank screen scenarios represent the majority of reported incidents. This proportion has never been quantified with production data. If backend KZs (RNF timeout, State Service OOM-kill, cross-node ECS failures) turn out to account for more than 20% of incidents, the 80% target cannot be reached with html5core changes alone. To make this verdict defensible, a breakdown of observed incidents by origin type (device-side vs. backend-originated) is needed before committing to the 1-month scope.

**The main risk is not technical — it is operational.** Without a reliable staging environment, every player change goes directly to production. With 1 QA person, the verification cycle on real devices is the bottleneck. The code can be written in 2 weeks; the safe, verified deployment may consume the rest of the month.

---

## Non-Negotiable Prerequisites

Before writing the first new telemetry event, two conditions must be resolved:

### Prerequisite 1 — Verify that the telemetry backend receives and persists events

The analysis identified that `TelemetryController` in fmcom-player-api swallows all exceptions and runs fire-and-forget. If the backend silently discards events, adding instrumentation in html5core produces no observable coverage. Before any development, confirm with an end-to-end test that an event emitted from the device arrives and is persisted in the telemetry system.

### Prerequisite 2 — Restore `sendIssue()` in html5core as the first release

`src/store/serverLogger.ts:38` has an unconditional `return` that turns the player's entire error reporting channel into dead code (KZ-1). This channel is the prerequisite for critical errors to arrive with high priority, separate from the batched telemetry channel. It is a 1-line fix, the highest-leverage change with the lowest cost and risk, and must be the first deploy.

---

## Recommended Execution Sequence

### Week 1 — Verification infrastructure + KZ-1

1. Verify end-to-end that the telemetry backend receives and persists events (prerequisite 1).
2. Confirm access to test devices with real-time logs to observe events during QA.
3. Restore `sendIssue()` in serverLogger.ts — deploy, verify that error events reach the backend.

### Week 2 — High-frequency gaps in html5core

Instrument in order of occurrence frequency:

| Gap | Event to add | Node |
|---|---|---|
| IG-4 | `content_changed_received` with timestamp | N6 — WS message receipt |
| IG-3 | `playlist_cleared` + `playlist_loaded` with timestamps | N6a — before and after the fetch |
| IG-6 | `playlist_fetch_failed` with HTTP status | N6a/N6b — at the moment of failure, not at 20s |
| IG-1 | `content_changed_dropped_consults` with timestamp | N6a — isConsults guard |
| IG-2 | `content_changed_dropped_concurrent` | N6a — __currentPlaylistLoading guard |

### Week 3 — Remaining gaps + watchdog enrichment

| Gap | Event to add | Node |
|---|---|---|
| IG-7 | `unknown_content_type` per discarded item | N6d — _parsePlaylist |
| IG-8 | event when filter() removes items from combined playlist | N6c |
| IG-10 | `cause` field in WATCHDOG payload | N8 |
| IG-11 | `consecutive_resets` field + server-side alert | N8 |
| KZ-2 | FIFO cap on localStorage buffer + priority flush on WS reconnection | N6 |

### Week 4 — Verification, adjustments, and coverage measurement

- Verify on real devices that all emitted events reach the backend.
- Measure event distribution by type to confirm that frequent scenarios have coverage.
- Document what % of observed incidents now have an observable causal signal.
- Produce the residual gap list: which scenarios still lack coverage and why (backend KZs or out-of-html5core scope).

---

## What Falls Outside the 80% in 1 Month

The following scenarios will not have full coverage by end of month, as they require infrastructure changes outside of html5core:

| Scenario | KZ/IG | Reason |
|---|---|---|
| fmcom-api crash between DB commit and JMS send | KZ-3 | Outbox pattern in MySQL — backend |
| State Service OOM-kill destroys in-transit PLAYER_* messages | KZ-4 | Persistent Amazon MQ — infra |
| Client eviction due to inactivity in State Service broker | KZ-5 | Persistent offset in Redis — backend |
| Device offline >30s, UnsentNotice TTL expires | KZ-6 | UnsentNotice in Redis — backend |
| RNF generation timeout with no signal | KZ-7 | CloudWatch metric + alert — infra |
| Transcoding failure with no TRANSCODE_FAILED published | KZ-8 | Dead-letter queue — backend |
| Phantom reload from ES write failure | KZ-9 | Gate PLAYER_*_UPDATED on ES write — backend |
| FREE/LOCKED tier — JMS suppression with no log | IG-5 | INFO log in fmcom-api — backend |
| Per-screen staleness in playlist generation | IG-9 | Field in ElasticPlaylistSchedule — backend |

These scenarios are candidates for a Phase 2 instrumentation effort.

---

## Structural Findings That Instrumentation Does Not Change

Regardless of the telemetry work, these architectural problems remain and affect both user experience and signal quality:

1. **Org-wide fanout amplifies the blast radius of every update.** A change to one screen in the org blanks all devices. Every IG-3 (reload blank window) occurs simultaneously across the entire org. Telemetry can measure this; it cannot resolve it without a change in fmcom-player-api.

2. **setPlaylist([]) before the fetch is a design decision.** The blank screen on every normal reload is intentional — the player clears state before knowing the new content. Telemetry can make the duration of that window visible; eliminating it requires changing the loading strategy (e.g., loading the new content into memory before clearing the current one).

3. **The PlaybackWatchdog is recovery, not diagnosis.** Even with `cause` and `consecutive_resets` fields added (IG-10, IG-11), the watchdog remains a late signal. The early events (IG-3, IG-6) are the ones that truly move the needle on diagnosis time.

4. **State Service is a single point of failure for telemetry routing.** An OOM-kill simultaneously destroys multiple signals that would have documented the failure. This does not change with instrumentation in html5core.