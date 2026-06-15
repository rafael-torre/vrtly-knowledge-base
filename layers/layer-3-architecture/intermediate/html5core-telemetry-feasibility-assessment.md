---
title: "html5core Telemetry — 80% Coverage Feasibility Assessment"
owner: "Tech Lead"
status: in_progress
last_updated: 2026-06-15
relates_to:
  - layers/layer-3-architecture/intermediate/html5core-telemetry-analysis.md
  - layers/layer-3-architecture/intermediate/html5core-playlist-playback-flow.md
  - layers/layer-3-architecture/intermediate/html5core-playlist-update-flow.md
  - layers/layer-3-architecture/intermediate/blank-screen-scenarios.md
  - layers/layer-3-architecture/intermediate/tech-spike-html5core-player.md
---

# html5core Telemetry — 80% Coverage Feasibility Assessment

Roundtable output from Winston (architect) + Amelia (developer) + John (PM, moderator). Evaluates whether 80% telemetry coverage for the html5core use case (full stack: player + backend) is achievable, in what timeframe, and with what team. Input: `html5core-telemetry-analysis.md` — 27 findings across both flows, 25 blank-screen scenarios.

**Coverage definition:** A scenario is covered when the blank screen moment is logged and that data is sufficient to diagnose the incident without physical device inspection.

---

## Baseline

| Metric | Today |
|---|---|
| Blank moment logged | 0 / 25 (0%) |
| Recovery logged (partial) | 9 / 25 (36%) |
| Causal context preserved (partial) | 8 / 25 (32%) |

---

## Finding Classification

| Category | Count | Fixable without architectural change? |
|---|---|---|
| Kill zones (code tries to log, signal doesn't survive) | 11 | 7 yes, 4 no |
| Instrumentation gaps (code never tries to log) | 12 | 12 yes |
| Structural / architectural | 4 | No |
| **Total** | **27** | **19 yes, 4 no** |

**html5core changes required:** 12 findings
**Backend-only changes:** 11 findings
**Structural backend (architectural redesign):** 4 findings

---

## The Structural Scenarios — What They Actually Produce

The 4 architectural findings (State Service broker OOM-kill, cross-node WS delivery, fmcom-api JMS post-commit gap, no DLQ on PLAYER_* destinations) underlie scenarios S-7, S-17, S-23, and S-24.

**These scenarios do not produce a device-side blank screen.** They produce stale content: the device continues playing the old playlist because the content update never reached it. There is no blank moment to log on the device — the failure is invisible from the player's perspective until either the stale content becomes unplayable (triggering a watchdog cycle) or an operator manually inspects.

**Consequence for the 80% target:** S-7, S-17, S-23, S-24 are not candidates for blank-moment logging via instrumentation, because the device never goes blank as a direct result of the failure. Diagnosing these scenarios requires server-side delivery confirmation signals (correlation ID from transcode to device reload), absence-of-delivery alerts, and UnsentNotice expiry metrics — all of which are in the backend findings and are fixable. But the "blank moment" metric does not apply to these 4 scenarios.

This changes the effective denominator for the 80% target:

| Scenario group | Count | Blank moment loggable? |
|---|---|---|
| Device-side blank scenarios (playback flow + update flow device-side failures) | ~21 | Yes — fixable via instrumentation |
| Stale-content scenarios (S-7, S-17, S-23, S-24) | 4 | No — no device-side blank to log |
| **Total** | **25** | |

**80% of 25 scenarios = 20 scenarios with blank moment logged.** Given that 4 scenarios have no device-side blank, achieving 20/25 requires logging the blank moment in at least 20 of the 21 loggable scenarios — effectively near-complete coverage of the device-side blank paths.

---

## Coverage Trajectory

### With 19 reparable findings implemented (months 1-2)

| Metric | Estimated outcome |
|---|---|
| Blank moment logged | ~14-17 / 25 (56-68%) |
| Recovery logged | ~20+ / 25 (80%+) |
| Causal context | ~15-18 / 25 (60-72%) |

The 4 stale-content scenarios (S-7, S-17, S-23, S-24) remain at "no blank moment" — no instrumentation change fixes this because the blank doesn't happen. The best coverage for those scenarios is server-side delivery confirmation (backend finding, included in the 19 reparable items), which tells operators that a device did not receive an expected update — not a blank-moment log, but the closest approximation available without architectural changes.

### Reaching 80% (20/25 scenarios with blank logged)

Getting to 20/25 requires near-complete coverage of the 21 device-side blank scenarios. The reparable findings address the majority of these, but a few gaps remain:

- **S-1 (RNF crash via State Service ping):** Blank occurs on device when content update is missed, but the root cause is backend. After fixing `setPlaylist([])` blank event, the blank moment is loggable. The causal context (RNF crashed) requires the RNF System.exit(-1) dedicated metric — a backend finding.
- **S-5 (State Service cold-start cache miss):** Blank is the activation screen stuck indefinitely. Fixable with the `checkActivation.ts` retry counter and a server-side alert on registration failure rate.
- **S-6 (State Service outage → ES quota fallback):** Similar to S-5 — stuck activation. Partially covered by server-side absence alert.

**Honest assessment:** 19 reparable findings gets to approximately 14-17 scenarios with the blank moment logged. To reach 20/25 (80%), a subset of the backend findings must also be deployed — specifically the delivery confirmation metric and the server-side absence alerts. These are included in the 19 reparable backend findings. **80% under this definition is achievable, but requires the full set of 19 reparable findings deployed and validated, not just the html5core changes alone.**

---

## Execution Plan

### html5core Findings — Two Buckets

**Bucket A — Low effort, low risk (6 findings, ~3-4 days development):**

| Finding | Change |
|---|---|
| `serverLogger.ts` dead code | Remove unconditional `return` on line 38 — do this first; validate pipeline before any other change |
| `setPlaylist([])` blank event | Emit `PlaylistCleared` event with trigger context (CONTENT_CHANGED / watchdog / initial-load) |
| `apiRequest()` fetch failure event | Emit error event when response is `{}` |
| `checkActivation.ts` retry counter | Add counter + emit on each retry |
| Consultation mode CONTENT_CHANGED log | Emit at the `isConsults` guard-return with screen MAC + timestamp |
| Watchdog `consecutiveCount` field | Add to existing PlaybackWatchdog event payload |

`serverLogger.ts` must be done first and validated in staging before any other Bucket A change ships. The `sendIssue()` function has been dead code in production — its downstream pipeline has never been exercised at scale. Validate it end-to-end before layering new events on top.

**Bucket B — Moderate effort (6 findings, ~2-2.5 weeks development):**

| Finding | Change | Notes |
|---|---|---|
| localStorage buffer cap + eviction | FIFO eviction at N events; write-failure detection | Testing required — cap size affects high-frequency playback |
| HTTP fallback transport | New transport layer; reuse `sendIssue()` after dead-code fix | ~1 week; Chrome 53 compatibility must be validated |
| WS handshake failure event via HTTP | Emit ConnectionState failure via HTTP | Blocked on HTTP fallback |
| Concurrent reload drop + re-fetch | Log drop; reactive watcher for `__currentPlaylistLoading` clear | Moderate |
| `PlaybackState.None` trigger disambiguation | New trigger field in `playbackController.ts` | 1 day |
| `currentContentId` in watchdog payload | Field addition to watchdog event | 0.5 day |

Bucket B should be in a separate html5core release from Bucket A. Do not ship both together.

### Backend Findings — Independent Deployment

All 11 backend non-architectural findings deploy independently of html5core. TelemetryController exception swallow fix **must be deployed before any html5core instrumentation release** — otherwise new client-side events fail silently.

| Priority | Finding | Effort |
|---|---|---|
| Gate (before html5core ships) | TelemetryController exception swallow — add error metric | 1 day |
| Week 1 | fmcom-player-api broker client eviction alert | 1 day |
| Week 1 | Amazon MQ DLQ on PLAYER_* destinations | 3-5 days |
| Week 2 | UnsentNotice expiry counter | 1 day |
| Week 2 | RNF generation timeout metric + per-screen freshness alert | 2 days |
| Week 2 | CONTENT_CHANGED delivery confirmation + correlation ID | 3-5 days |
| Week 2 | Per-screen "last generated" staleness alert | 2 days |
| Week 3 | FAILED transcode alert threshold | 1 day |
| Week 3 | Subscription tier suppression metric (FREE/LOCKED) | 1 day |
| Week 3 | RNF System.exit(-1) dedicated metric | 1 day |
| Infra | ALB sticky sessions (closes S-23 without architectural redesign) | 1 day infra |

---

## Timeline

### Month 1

**Week 1:**
- Backend: TelemetryController fix (gate), broker eviction alert, DLQ design + start
- html5core: Bucket A development — `serverLogger.ts` first, then remaining 5 changes; staging validation of `sendIssue()` pipeline

**Week 2:**
- Backend: DLQ complete, delivery correlation ID design, per-screen freshness alert
- html5core: Bucket A device QA regression pass (FireTV, webOS, Tizen — ~5-8 days with 1 QA)
- Infra: ALB sticky sessions (if scoped)

**Week 3:**
- Backend: remaining non-architectural findings (suppression metric, timeout alert, System.exit metric)
- html5core: Bucket A released to production; Bucket B development starts

**Week 4:**
- html5core: Bucket B in development (localStorage cap, HTTP fallback start)
- Backend: delivery confirmation metric, correlation ID complete and deployed

**End of month 1:** ~17-18 findings implemented. Blank moment logged in approximately **10-12 of 25 scenarios** (Bucket A html5core + backend alerts deployed). Not at 80% yet — Bucket B and remaining backend findings not yet complete.

### Month 2

**Week 5-6:**
- html5core: Bucket B development complete
- Backend: all 11 non-architectural findings deployed; delivery confirmation in use

**Week 7-8:**
- html5core: Bucket B QA regression pass + second release to production
- All 19 reparable findings live

**End of month 2:** All 19 reparable findings deployed. Blank moment logged in approximately **14-17 of 25 scenarios** — approaching 80% but dependent on how the 4 stale-content scenarios are counted. With server-side delivery confirmation and absence alerts covering S-7, S-17, S-23, S-24, operators can diagnose those incidents from backend signals even without a device-side blank event. Whether this counts toward the 80% target depends on the agreed definition.

---

## Team Requirements

### Month 1

| Role | Allocation | Scope |
|---|---|---|
| Backend developer (mid-senior) | Full-time | 11 backend non-architectural findings |
| Frontend developer (mid-senior, html5core familiarity) | Full-time | 12 html5core findings, Bucket A first |
| QA engineer | Full-time weeks 2-3, part-time weeks 1 + 4 | Device regression: FireTV, webOS, Tizen |
| DevOps / Infra | 0.25 FTE | DLQ config, ALB sticky sessions |

### Month 2

Same team. If structural items (State Service broker migration) are scoped in, add +1 senior backend developer for the architecture work.

---

## Key Constraints

1. **`serverLogger.ts` pipeline validation first.** `sendIssue()` has been dead code in production — its downstream pipeline has never been exercised at scale. Must be validated in staging before any other html5core instrumentation event ships.

2. **TelemetryController gate.** New client-side events route through the backend processing pipeline that currently swallows all exceptions silently. This backend fix must deploy before any html5core instrumentation release or new events will fail silently with no observable signal.

3. **1 QA person, no reliable staging.** Each html5core release requires a device regression pass. With 1 QA person, a release cycle realistically takes 5-8 days. Bucket A and Bucket B must be in separate releases.

4. **Chrome 53 target.** webOS/Tizen compatibility. HTTP Fetch API availability and localStorage quota behavior differ on older WebView versions. Bucket B HTTP fallback transport must be validated against Chrome 53 semantics before it ships.

5. **Correlation ID cross-team coordination.** The delivery confirmation metric requires a correlation ID propagating from `MediaProcessingMessage` → `PLAYER_CONTENT_TRANSCODED` → `CONTENT_CHANGED` → device reload. Needs one technical owner assigned to drive alignment across fmcom-api, RNF, player-api, and html5core teams.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| html5core release cycle takes 3+ weeks | Medium | Bucket B doesn't ship in month 1; 80% slides to month 3 | Gate Bucket A separately; declare month 1 target as Bucket A + backend, not full 80% |
| HTTP fallback surfaces Chrome 53 compat issues | Medium | WS kill zone fixes delayed | Prototype in week 3-4; decouple from Bucket A release |
| TelemetryController not fixed before html5core ships | High if unsequenced | New events fail silently | Hard gate: html5core release is blocked until TelemetryController fix is deployed |
| `sendIssue()` pipeline broken downstream | Unknown | html5core error events never surface in dashboards | Stage and validate before shipping Bucket A |
| Correlation ID design stalls (multi-team) | Medium | Delivery confirmation metric misses month 2 | Assign single owner; design-first in week 1 |

---

## Summary

**Is 80% in 1 month viable?**
No. The html5core release cycle (2-3 weeks per release, 2 releases needed) plus backend deployment and QA cannot physically complete in one calendar month. Month 1 realistically delivers approximately 10-12 of 25 scenarios with blank-moment logging — meaningful improvement from 0%, but not 80%.

**Is 80% in 2 months viable?**
Yes, with caveats. 19 reparable findings get to approximately 14-17 / 25 scenarios with blank moment directly logged. Whether this reaches 80% depends on how the 4 stale-content scenarios (S-7, S-17, S-23, S-24) are counted: they have no device-side blank to log, but the server-side delivery confirmation signals (included in the 19 reparable findings) allow operators to diagnose those incidents. If those server-side signals count toward the target, 80% is achievable in 2 months. If the target strictly requires a device-side blank event, the 4 stale-content scenarios cannot contribute — and the effective ceiling from the 19 reparable findings alone is approximately 17/25 (68%).

**What is the single highest-leverage action?**
Fix `serverLogger.ts` (remove one `return` on line 38 of `serverLogger.ts`). One hour. Re-enables the entire proactive error-reporting path that has been silently disabled in production.

**Non-negotiable sequencing:**
1. `serverLogger.ts` → validate pipeline in staging before any other html5core instrumentation ships
2. TelemetryController fix → deploy before any html5core instrumentation release
3. Bucket A html5core release before Bucket B begins QA
4. Correlation ID — assign single owner in week 1

---

## Open Questions

1. **Stale-content scenarios and the 80% count:** Do S-7, S-17, S-23, S-24 contribute to the 80% target when server-side delivery confirmation signals are present, or does the target require a device-side blank event? This determines whether 80% is achievable in 2 months or requires structural architectural work.

2. **ALB sticky sessions scope:** Should this be a month 1 infra task? It closes S-23 with minimal risk and removes one structural blocker. ~1 day of infra work.

3. **State Service broker migration:** If S-17 must count toward 80%, what is the realistic effort for migrating PLAYER_* to a durable broker? A 2-week architecture spike would produce a reliable estimate.

4. **Staged html5core rollout:** Can html5core telemetry changes be deployed to a subset of the fleet first (e.g., 5-10 devices) before full rollout? If yes, QA cycle compresses and Bucket B can potentially ship in month 1.

5. **Correlation ID ownership:** Who owns the design and implementation across fmcom-api, RNF, player-api, and html5core? Needs to be assigned before implementation begins in week 1.
