---
title: "Investigation — html5core Telemetry Kill Zones and Instrumentation Gaps"
owner: "Tech Lead"
status: consensus
last_updated: 2026-06-15
relates_to:
  - layers/layer-3-architecture/intermediate/html5core-playlist-playback-flow.md
  - layers/layer-3-architecture/intermediate/html5core-playlist-update-flow.md
  - layers/layer-3-architecture/intermediate/blank-screen-scenarios.md
  - layers/layer-3-architecture/intermediate/tech-spike-html5core-player.md
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-player-api.md
  - layers/layer-3-architecture/intermediate/tech-spike-rnf.md
  - layers/layer-3-architecture/intermediate/tech-spike-state-service.md
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-api.md
---

# Investigation: html5core Telemetry Kill Zones and Instrumentation Gaps

## Hand-off Brief

1. **What happened.** For each node in the html5core playback and content-update flows, the investigation mapped which telemetry signals are attempted but lost in transit (kill zones) and which failure paths emit no signal at all (instrumentation gaps); the consolidated findings are in `html5core-telemetry-analysis.md`.
2. **Where the case stands.** Concluded. 23 distinct findings identified: 11 kill zones (7 reparable by instrumentation, 4 requiring architectural change) and 12 instrumentation gaps (all reparable). Of the 25 blank-screen scenarios, none have the blank moment itself logged; 9 have partial recovery signal; 8 have partial causal context.
3. **What's needed next.** `skill-roundtable` (Winston + Amelia + John) to evaluate whether 80% coverage is achievable in 1 month given this distribution of fixes — particularly the 4 structural kill zones that require architectural changes rather than logging additions.

## Case Info

| Field | Value |
|---|---|
| Ticket | N/A |
| Date opened | 2026-06-15 |
| Status | Concluded |
| System | html5core + fmcom-player-api + RNF + State Service + fmcom-api (html5core fleet) |
| Evidence sources | playback-flow doc, update-flow doc, 25 blank-screen scenarios, html5core tech spike |

## Problem Statement

For each node of the html5core general playback lifecycle (boot → steady-state) and the content update flow (admin action → device reload), determine: what information is definitively lost on failure, and whether it can be recovered or approximated with instrumentation changes.

The investigation is area-exploration, not symptom-driven. The anchor is the two flow documents; every finding maps to a named node.

## Evidence Inventory

| Source | Status | Notes |
|---|---|---|
| `html5core-playlist-playback-flow.md` | Available | P-N0–P-N11, 3 conditional paths; code-level detail confirmed |
| `html5core-playlist-update-flow.md` | Available | U-N0–U-N8; full cross-service chain |
| `blank-screen-scenarios.md` | Available | 25 scenarios with "Missing" telemetry per scenario |
| `tech-spike-html5core-player.md` | Available | localStorage flush, PlaybackState, watchdog, serverLogger dead code |
| `tech-spike-fmcom-player-api.md` | Available (via update-flow) | UnsentNoticeService, WsSessionHolder, TelemetryController |
| `tech-spike-rnf.md` | Available (via blank-screen-scenarios) | System.exit(-1), generation timeout, dedup |
| `tech-spike-state-service.md` | Available (via blank-screen-scenarios) | Broker at-most-once, client eviction, OOM risk |

## Investigation Backlog

| # | Path to Explore | Priority | Status | Notes |
|---|---|---|---|---|
| 1 | Map all playback-flow nodes against telemetry dimensions | High | Done | See canonical analysis |
| 2 | Map all update-flow nodes against telemetry dimensions | High | Done | See canonical analysis |
| 3 | Map blank-screen scenarios "Missing" sections to flow nodes | High | Done | Coverage table in canonical analysis |
| 4 | Identify paths with zero signal across entire stack | High | Done | 5 zero-signal paths documented |
| 5 | Quantify distribution of fix responsibility (html5core vs backend) | High | Done | See responsibility table |
| 6 | Verify serverLogger.ts dead-code status | Medium | Done | Confirmed: unconditional return on line 38 per spike |
| 7 | Verify localStorage buffer has no size cap | Medium | Done | Confirmed in tech spike open question 6 |

## Confirmed Findings

### Finding 1: serverLogger.ts is dead code — no client-side error reporting path exists

**Evidence:** `tech-spike-html5core-player.md` — "`sendIssue()` has an unconditional `return` on line 38, making the entire server-side logging feature dead code." Confirmed independently in blank-screen-scenarios.md S-3, S-20, S-21, S-22.

**Detail:** The only mechanism by which the html5core player could proactively report errors to the backend is completely disabled. Every client-side failure path is invisible to the server unless it eventually produces a telemetry event that survives the localStorage → WebSocket flush path.

### Finding 2: localStorage telemetry buffer has no size cap, no TTL, no HTTP fallback

**Evidence:** `tech-spike-html5core-player.md` open question 6: "The telemetry queue in localStorage has no size cap. What is the expected behavior if the WebSocket is offline for an extended period?" Confirmed in `html5core-playlist-playback-flow.md` N9: "If WebSocket is closed: buffer accumulates without bound — no size cap, no TTL."

**Detail:** Kill zone during extended WebSocket outages. Two failure modes: (a) OOM before flush destroys events, (b) localStorage quota overflow (~5–10MB in WebView) causes subsequent writes to fail silently. Both are completely invisible to the server.

### Finding 3: setPlaylist([]) blank window is uninstrumented

**Evidence:** `html5core-playlist-playback-flow.md` N6: "`setPlaylist([])` is called immediately before the fetch begins. The screen goes blank at this point and stays blank until `setPlaylist(newPlaylist)` completes." `html5core-playlist-update-flow.md` N6a: same pattern confirmed for content-reload path.

**Detail:** The blank-screen moment itself — the exact instant when the screen goes dark — is never logged. No telemetry event is emitted for `setPlaylist([])`. The only downstream signal is the watchdog firing 20 seconds later if the fetch fails. This applies to every `reloadCurrentPlaylist()` call: triggered by `CONTENT_CHANGED`, watchdog 20s, or `CONFIG` message.

### Finding 4: consultation-mode CONTENT_CHANGED drop produces no record

**Evidence:** `html5core-playlist-update-flow.md` N6: "Guard: isConsults? → skip." Blank-screen-scenarios.md S-22: "No server-side or client-side record that a CONTENT_CHANGED was dropped due to consultation mode."

**Detail:** The guard check is correct behavior (don't interrupt consultations), but the absence of any log or telemetry event means there is no observable record that the update was missed. After the consultation ends, the device plays stale content with no signal to the operator.

### Finding 5: State Service broker provides at-most-once delivery — structural kill zone

**Evidence:** `blank-screen-scenarios.md` S-17: "In-process broker in State Service delivers at-most-once — confirmed in state-service spike observation 6: 'If state-service is OOM-killed or receives SIGKILL, all undelivered topic messages are lost.'" Also S-7: "client offset eviction after 5 minutes of inactivity causes silent message loss — confirmed in state-service spike observation 14."

**Detail:** Two independent at-most-once kill zones in the message delivery path (U-N4). Neither can be repaired by adding instrumentation — both require architectural changes (durable broker, at-least-once delivery guarantee, dead-letter queues).

### Finding 6: PlaybackWatchdog telemetry cannot distinguish healthy skip from stall loop

**Evidence:** `blank-screen-scenarios.md` S-3: "No signal distinguishing a 'healthy watchdog skip' from a 'watchdog reload loop' — both appear as PlaybackWatchdog telemetry with the same type."

**Detail:** The watchdog fires the same telemetry event whether it's advancing a slow-loading item (expected behavior) or cycling indefinitely on a broken endpoint (S-3 loop). This means the telemetry that does survive is structurally ambiguous.

### Finding 7: TelemetryController in fmcom-player-api swallows all exceptions

**Evidence:** `html5core-playlist-update-flow.md` architecture note 7: "Telemetry is best-effort. player-api's TelemetryController swallows all exceptions; TelemetryEventAnalyzerService runs fire-and-forget. Loss is silent."

**Detail:** Even when device-side telemetry events reach player-api via WebSocket, downstream processing (escalation rules, content manifest detection, watchdog analysis) runs fire-and-forget with no error surfacing. Failures in telemetry analysis are invisible.

## Deduced Conclusions

### Deduction 1: The blank-screen moment itself is unobservable in all 25 scenarios

**Based on:** Findings 3, 4; analysis of all 25 blank-screen scenarios' "Missing" sections.

**Reasoning:** `setPlaylist([])` always precedes the network fetch. No telemetry event is emitted at this call site. Server-side signals (HTTP requests, WebSocket messages) don't capture the device's visual state. Therefore the exact moment a screen goes blank is never recorded in any log, metric, or telemetry event across the entire system.

**Conclusion:** Baseline telemetry coverage for the blank-screen event itself is 0/25. This is the most fundamental gap in the current instrumentation model.

### Deduction 2: The majority of high-impact zero-signal paths are due to instrumentation gaps, not kill zones

**Based on:** Finding 3, 4, full node analysis; S-22, S-24, P-CC.

**Reasoning:** The cases where signals are most completely absent (consultation mode drop, UnsentNotice TTL expiry after reconnect, initial fetch failure before watchdog fires) are not cases where code tried to log and failed — they are cases where the code path was not modeled as a failure at all. Kill zones (OOM, WS-closed-during-flush) are real but affect a minority of signals. The dominant cause of missing telemetry is architectural: these paths were not instrumented.

**Conclusion:** A larger share of the 80% coverage gap is addressable through instrumentation additions (no architecture change required) than through structural fixes. This is relevant for the feasibility assessment.

### Deduction 3: html5core is responsible for more instrumentation gaps; backend is responsible for more kill zones

**Based on:** Full node analysis; Findings 1–7.

**Reasoning:** The player is responsible for 8 of 12 instrumentation gaps (client-side failure paths that were never modeled). The backend is responsible for 7 of 11 kill zones (at-most-once broker, UnsentNotice TTL, cross-node delivery, JMS deferred publish, no DLQs). This asymmetry matters for workload distribution: html5core changes require a player deployment to all devices; backend changes can be deployed independently.

## Hypothesized Paths

### Hypothesis 1: localStorage survives `window.location.reload()` — watchdog events are not lost on reload

**Status:** Confirmed (deduced from browser behavior and tech spike)

**Theory:** localStorage persists across page reloads in WebView environments. The watchdog 30s event written to localStorage just before `window.location.reload()` survives the reload. It is flushed when the WebSocket reconnects after the new page load.

**Resolution:** Confirmed by browser localStorage spec and consistent with tech spike description of the buffering model.

### Hypothesis 2: PlaybackState.None is not emitted as a failure telemetry event when setPlaylist([]) is called

**Status:** Confirmed (deduced)

**Theory:** `setPlaylist([])` transitions playback to None/empty state. The telemetry subsystem emits `Playback` events for content transitions. PlaybackState.None is the normal end-of-item state and would not be distinguishable from "playlist was cleared for reload."

**Resolution:** Confirmed by flow doc: the PlaybackState.None state is used both for normal item-end transitions and for the blank-before-fetch moment. No dedicated event type exists for the latter. This is Finding 3.

### Hypothesis 3: RNF generation timeout at U-N3 is a kill zone, not an instrumentation gap

**Status:** Refuted — reclassified as instrumentation gap

**Theory:** Initially suspected that RNF generation timeout might involve a code path that tries to publish a PLAYER_* message and fails.

**Resolution:** Refuted by flow doc and S-8. `waitForCompletion` returns null silently — the code never attempts to publish a message on timeout. No message is intended to be sent; the timeout path simply exits without publishing. This is an instrumentation gap (no metric, no alert, no retry), not a kill zone.

## Missing Evidence

| Gap | Impact | How to Obtain |
|---|---|---|
| Whether ALB sticky sessions are configured for fmcom-player-api target group | Determines whether S-23 cross-node delivery is a current production issue or a theoretical risk | Check AWS ALB target group configuration in production |
| Whether `JmsMode.STATE` or `JmsMode.MQ` is active for `PLAYER_*` messages in production | Determines which kill zone (in-process broker vs Amazon MQ) applies to U-N4 | Check `fm-common` MessagingService configuration in production env vars |
| localStorage quota observed on production FireTV devices | Determines real OOM-before-flush risk vs theoretical | Instrument with localStorage size monitoring on a test device |
| Feign connect/read timeout for ScreenStateClient in fmcom-player-api | Determines how long devices wait on re-registration after reload (S-12 duration) | Check fmcom-player-api application.yml / env config |

## Source Code Trace

| Element | Detail |
|---|---|
| Kill zone — telemetry buffer | `src/store/telemetry/telemetryQueue` → localStorage → WebSocket send; no cap, no TTL, no HTTP fallback |
| Kill zone — WS flush transport | `telemetryQueue` flush sends via WebSocket only; closed WS → events in batch are lost |
| Gap — setPlaylist blank | `src/store/playlists.ts` → `reloadCurrentPlaylist()` → `playbackController.setPlaylist([])` — no telemetry event emitted here |
| Gap — serverLogger dead code | `src/store/serverLogger.ts` line 38 — unconditional `return` makes `sendIssue()` a no-op |
| Gap — consultation guard | `src/store/playlists.ts` → `reloadCurrentPlaylist()` guard: `if (playbackController.isConsults) return` — no log |
| Gap — concurrent reload guard | `src/store/playlists.ts` → `reloadCurrentPlaylist()` guard: `if (__currentPlaylistLoading) return` — no log |
| Kill zone — State Service broker | `BrokerServiceImpl` (state-service) — in-memory, at-most-once; OOM-kill loses all queued PLAYER_* messages |
| Kill zone — UnsentNotice TTL | `UnsentNoticeService` (fmcom-player-api) — 30s TTL, cleanup every 10s, no expiry metric |
| Gap — watchdog telemetry | `src/store/playbackWatchdog.ts` — emits `PlaybackWatchdog` telemetry at 10s/20s/30s thresholds; no context field to distinguish healthy-skip from stall-loop |
| Gap — activation retry | `src/store/checkActivation.ts` — no telemetry for retry cycles; only success is recorded |

## Conclusion

**Confidence:** High — all findings are Confirmed from direct source citations or Deduced from confirmed facts.

Of the 11 kill zones identified, 7 are repairable through instrumentation changes (localStorage buffer cap, HTTP fallback transport, WS-closed retry, WS establishment failure event, UnsentNotice expiry metric, TelemetryController error surfacing) and 4 require architectural changes (State Service broker at-most-once → at-least-once, cross-node WebSocket delivery → sticky sessions or distributed store, fmcom-api JMS deferred publish → transactional outbox, Amazon MQ → add DLQs).

Of the 12 instrumentation gaps, all 12 are repairable without architectural changes: 8 require html5core changes (add telemetry at setPlaylist[], fetch failure, consultation drop, concurrent drop, activation retry, PlaybackState.None as failure event, watchdog context field, re-enable serverLogger), and 4 require backend changes (generation timeout metric, per-screen freshness alert, FAILED transcode alert, CONTENT_CHANGED delivery metric).

The full findings, node-by-node table, scenario coverage table, and responsibility distribution are in `html5core-telemetry-analysis.md`.

## Recommended Next Steps

### Fix direction

Two distinct workstreams:
1. **Instrumentation additions** (html5core + backend, no architecture change): 12 gaps and 7 kill zones where adding logging/telemetry/metrics is sufficient. Highest-value items: re-enable serverLogger, add telemetry at setPlaylist[], add localStorage buffer cap + HTTP fallback.
2. **Architectural fixes** (backend): 4 structural kill zones. Required for complete coverage of S-7, S-17, S-23, S-24. Estimated significantly higher effort than workstream 1.

### Diagnostic

Run `skill-roundtable` with Winston (architect) + Amelia (dev) + John (PM) against `html5core-telemetry-analysis.md` to assess feasibility of 80% coverage in 1 month and required team profile.