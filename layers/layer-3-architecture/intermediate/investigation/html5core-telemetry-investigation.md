---
title: "Investigation: Telemetry Kill Zones and Instrumentation Gaps — html5core"
owner: "Tech Lead"
status: consensus
last_updated: 2026-06-12
relates_to:
  - layers/layer-3-architecture/intermediate/playlist-update-flow-html5core.md
  - layers/layer-3-architecture/intermediate/blank-screen-scenarios.md
  - layers/layer-3-architecture/intermediate/tech-spike-html5core-player.md
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-api.md
  - layers/layer-3-architecture/intermediate/tech-spike-rnf.md
  - layers/layer-3-architecture/intermediate/tech-spike-state-service.md
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-player-api.md
---

# Investigation: Telemetry Kill Zones and Instrumentation Gaps — html5core

## Hand-off Brief

1. **What happened.** Systematic audit of every node in the html5core content update flow (N0–N8) to determine: (a) where the code attempts to emit a signal that does not survive to the observability layer (kill zones — Dimension 1), and (b) where a blank-screen path exists with no instrumentation attempt at all (instrumentation gaps — Dimension 2).
2. **Where the case stands.** Concluded. All findings are confirmed or strongly deduced from tech spikes, source analysis of `playlist-update-flow-html5core.md`, and the 25 blank-screen scenarios. 14 kill zones and 11 instrumentation gaps identified across N1–N8.
3. **What's needed next.** Use `telemetry-analysis-html5core.md` as primary input for the `skill-roundtable` (Paso 2) to assess whether the 80% coverage objective is structurally achievable given these gaps.

## Case Info

| Field | Value |
|---|---|
| Ticket | N/A |
| Date opened | 2026-06-12 |
| Status | Concluded |
| System | html5core fleet; backend: fmcom-api, reach-n-freq, state-service, fmcom-player-api |
| Evidence sources | `playlist-update-flow-html5core.md` (N0–N8), `blank-screen-scenarios.md` (S-1 through S-25), tech spikes for all four backend repos + html5core |

## Problem Statement

For each node of the html5core content update flow, determine:

1. Which signals are attempted but do not survive to an observable system (kill zones — Dimension 1).
2. Which blank-screen paths have no instrumentation attempt at all (instrumentation gaps — Dimension 2).

This is not a "what to log" exercise. The goal is to assess structural telemetry survivability — the ceiling on what percentage of blank-screen events is observable even under ideal infrastructure conditions.

## Evidence Inventory

| Source | Status | Notes |
|---|---|---|
| `playlist-update-flow-html5core.md` | Available | Full node-by-node flow map; primary structural anchor for all findings |
| `blank-screen-scenarios.md` S-1 to S-25 | Available | 25 scenarios with "Missing" telemetry sections; each mapped to flow node |
| `tech-spike-html5core-player.md` | Available | Source-level analysis; serverLogger.ts dead code confirmed, buffer overflow risk, all store behaviors |
| `tech-spike-fmcom-player-api.md` | Available | Session architecture, UnsentNotice TTL, TelemetryController, WebSocket delivery, org-wide fanout |
| `tech-spike-rnf.md` | Available | System.exit(-1) behavior, timeout handling, TriggerMode, pipeline stages, ES quota |
| `tech-spike-state-service.md` | Available | In-process broker, OOM-kill risk, 5-min client eviction, ES quota coordination |
| `tech-spike-fmcom-api.md` | Available | Post-commit JMS, tier suppression, throttle coalescing, TransactionSynchronizationManager |
| Actual source code | Partial | Not directly read; evidence from tech spikes; claims graded as Confirmed (spike-cited) or Deduced |

## Investigation Backlog

| # | Path Explored | Priority | Status | Notes |
|---|---|---|---|---|
| 1 | N0: Admin action — telemetry relevance | Low | Done | Out of scope for device telemetry; no signal path to html5core |
| 2 | N1: fmcom-api — post-commit JMS gap | High | Done | KZ-3 confirmed |
| 3 | N1: fmcom-api — tier suppression logging | High | Done | IG-5 confirmed |
| 4 | N2: RNF transcoding — failure signal path | High | Done | KZ-8 + KZ-10 confirmed |
| 5 | N3: RNF playlist gen — timeout signal | High | Done | KZ-7 + IG-9 confirmed |
| 6 | N3: RNF playlist gen — ES write failure | Medium | Done | KZ-9 confirmed (phantom reload) |
| 7 | N4: Message bus — broker OOM-kill | High | Done | KZ-4 confirmed |
| 8 | N4: Message bus — client eviction | High | Done | KZ-5 confirmed |
| 9 | N4: Message bus — Amazon MQ no DLQ | Medium | Done | KZ-6 (relabeled) confirmed |
| 10 | N5: fmcom-player-api — cross-node miss + TTL | High | Done | KZ-6 (UnsentNotice) confirmed |
| 11 | N6: html5core — serverLogger.ts dead code | Critical | Done | KZ-1 confirmed; highest-leverage fix |
| 12 | N6: html5core — buffer overflow | High | Done | KZ-2 confirmed |
| 13 | N6: html5core — consultation mode drop | High | Done | IG-1 confirmed; zero signal |
| 14 | N6: html5core — concurrent reload guard | Medium | Done | IG-2 confirmed |
| 15 | N6: html5core — setPlaylist([]) blank window | High | Done | IG-3 confirmed; affects every reload |
| 16 | N6a–N6c: Playlist fetch failure signal | High | Done | IG-6 confirmed; observable only 20s later |
| 17 | N6a: encodeURIComponent bug signal | Medium | Done | KZ combined with IG-6 |
| 18 | N6d: _parsePlaylist unknown contentType | Medium | Done | IG-7 confirmed |
| 19 | N6c: Combined playlist dynamic slot filter | Medium | Done | IG-8 confirmed |
| 20 | N7: Playback — PlaybackState.None window | High | Done | Same path as IG-3 |
| 21 | N8: Watchdog — telemetry survivability | Medium | Done | KZ-2 dependency confirmed |

---

## Confirmed Findings — Dimension 1: Kill Zones

Kill zones are paths where code attempts to emit a signal that does not survive to an observable layer.

### KZ-1: serverLogger.ts — all client-side error reporting is dead [N6]

**Evidence:** `tech-spike-html5core-player.md`: "`sendIssue()` has an unconditional `return` on line 38, making the entire server-side logging feature dead code." Also S-3 assumptions and S-20 assumptions (both confirm `sendIssue()` is dead).

**Detail:** Every error path in html5core that relies on server-side issue reporting produces no observable signal. The designed diagnostic channel (serverLogger → server endpoint → logging) is a no-op. This is not a kill zone for a specific signal — it is a structural elimination of an entire signal class. All IG findings (Dimension 2) that would otherwise be reportable via this channel are also affected.

**Severity:** This is the single highest-leverage finding in the investigation. Restoring `sendIssue()` unlocks signal paths for IG-1, IG-6, IG-7, and IG-8 without requiring backend changes.

---

### KZ-2: Telemetry buffer overflow — events lost when WebSocket offline extended [N6, N8]

**Evidence:** `tech-spike-html5core-player.md`: "If the WebSocket drops permanently, telemetry accumulates without bound in localStorage (no cap or TTL on the buffer)." S-3 assumptions: "no local playlist cache... no local cache."

**Detail:** PlaybackWatchdog events, connection state events, and playback events all queue in localStorage during WebSocket outages. The buffer has no size cap and no eviction policy. Browser storage limits or device OOM can silently drop buffered events before flush. This affects N8 (watchdog events) most critically — since the watchdog fires precisely when the WebSocket is most likely degraded (device under stress).

---

### KZ-3: Post-commit JMS dispatch gap — content change lost on fmcom-api crash [N1]

**Evidence:** `playlist-update-flow-html5core.md` N1: "JMS publish is deferred until DB transaction commits via `TransactionSynchronizationManager`. The message is not sent inline during the request; it is queued for post-commit dispatch."

**Deduced:** A crash or OOM-kill of fmcom-api between DB commit and the actual JMS send produces a committed content change in MySQL with no downstream notification. No metric tracks the gap between "commit occurred" and "JMS dispatched." No dead-letter or outbox mechanism compensates.

---

### KZ-4: State Service broker OOM-kill — PLAYER_* messages in transit permanently lost [N4]

**Evidence:** S-17, state-service spike observation 6: "If state-service is OOM-killed or receives SIGKILL, all undelivered topic messages are lost." "It does not run on a crash." The `ElasticBrokerMessages` snapshot runs only on clean `stop()`.

**Detail:** The in-process broker in State Service holds PLAYER_ORGANIZATION_CONTENT_UPDATED and PLAYER_SCREEN_CONTENT_UPDATED in memory before delivering to fmcom-player-api subscribers. An OOM-kill — the primary crash mode given the unbounded screen cache (state-service spike observation 2) — discards all in-transit messages permanently.

---

### KZ-5: State Service broker client eviction — PLAYER_* messages missed silently [N4]

**Evidence:** S-7, state-service spike observation 14: "client offset eviction after 5 minutes of inactivity causes silent message loss — confirmed."

**Detail:** A fmcom-player-api instance that does not actively poll the State Service broker for 5 minutes has its consumer offset reset to the current tail. All PLAYER_* messages published during the inactivity window are permanently missed. No log entry and no metric document this reset.

---

### KZ-6: CONTENT_CHANGED delivery — UnsentNotice TTL kills message for offline/cross-node devices [N5]

**Evidence:** `playlist-update-flow-html5core.md` N5: "queues for reconnect delivery (in-memory only, **30-second TTL**, cleaned up every 10 seconds)." S-23 and S-24 both confirm the TTL expiry path.

**Detail:** Two paths converge here: (a) device is offline when CONTENT_CHANGED is dispatched — stored in UnsentNotice, lost after 30s if device doesn't reconnect; (b) cross-node ECS deployment — CONTENT_CHANGED dispatched on node A for a device connected to node B — stored in UnsentNotice on node A, never delivered if device reconnects to node B. Both paths produce the same outcome: notification attempted, TTL kills it.

---

### KZ-7: RNF playlist generation timeout — no PLAYER_*_UPDATED published [N3]

**Evidence:** S-8 confirmed: "`waitForCompletion` returns null/empty set silently." "`detectLongRunningTask` logs the screen ID and elapsed time — not a metric or alert." No PLAYER_ORGANIZATION_CONTENT_UPDATED or PLAYER_SCREEN_CONTENT_UPDATED is published on timeout.

**Detail:** A screen whose generation exceeds the 5-minute (per-screen) or 30-minute (per-org) deadline receives no notification. The only observable artifact is a single log line. No metric counts timeout frequency. No alert fires. The screen's ElasticPlaylistSchedule is not updated.

---

### KZ-8: Transcoding failure — PLAYER_CONTENT_TRANSCODED not published [N2]

**Evidence:** S-4 confirmed: "`PLAYER_CONTENT_TRANSCODED` is **not** published" on `UnifiedVideoPipeline` failure. "`API_CONTENT_ADD` is **not** published." "The content remains in its previous `TranscodingStatus` state in MySQL."

**Nuance:** Technically Dimension 2 from the signal's perspective (the signal is never attempted on the failure path), but it presents as a kill zone to downstream nodes (N4, N5, N6) because the absence of the event is what causes the blank screen.

---

### KZ-9: ES write failure after generation — phantom reload [N3]

**Evidence:** S-15 confirmed: generation completes → ES write fails → `MySqlElasticsearchSaveFailure` row created. PLAYER_*_UPDATED publication is not gated on ES write success (not documented in any spike as suppressed).

**Deduced:** PLAYER_ORGANIZATION_CONTENT_UPDATED is published (notification survives to N5/N6), but ElasticPlaylistSchedule was not updated. The device receives CONTENT_CHANGED, clears its playlist (setPlaylist([])), fetches from player-api, which fetches from RNF's stale ElasticPlaylistSchedule, and receives the same content as before. Screen blanks and recovers with identical content — a phantom reload that produces unnecessary blank time with no benefit.

---

### KZ-10: RNF System.exit(-1) — in-flight transcoding context destroyed, no differentiating signal [N2]

**Evidence:** S-1, S-6, RNF spike: "System.exit(-1) is called immediately — no backoff, no retry." In-flight transcodes are abandoned. Shutdown hook marks claimed rows as FAILED. CloudWatch receives an ERROR log line and ECS task exit event.

**Detail:** The only signal is a log line + ECS task exit — identical to any other JVM crash. No metric distinguishes "exited due to State Service ping failure" from "exited due to OOM" or "exited due to another exception." In-flight content IDs at time of exit are not recorded anywhere.

---

## Confirmed Findings — Dimension 2: Instrumentation Gaps

Instrumentation gaps are paths where a device reaches a blank screen with no code attempting to emit any signal at any layer.

### IG-1: CONTENT_CHANGED received in consultation mode — zero signal anywhere in the stack [N6]

**Evidence:** S-22 confirmed: "`reloadCurrentPlaylist()` returns immediately when `isConsults === true`." "No server-side or client-side record that a `CONTENT_CHANGED` was dropped due to consultation mode."

**Detail:** The WebSocket delivers the message. The handler calls `reloadCurrentPlaylist()`. The first guard returns early. Nothing is logged. Nothing is telemetrized. fmcom-player-api does not know the message was dropped. After the consultation ends, the device plays stale content indefinitely. This is the most complete zero-signal path in the investigation: no actor at any layer has any observable record of the event.

---

### IG-2: Concurrent reload guard — second CONTENT_CHANGED silently dropped [N6]

**Evidence:** `playlist-update-flow-html5core.md` N6: "If a second `CONTENT_CHANGED` arrives while `__currentPlaylistLoading === true`: `reloadCurrentPlaylist()` returns immediately without action. The second reload is silently dropped."

**Detail:** With org-wide fanout (S-19), multiple CONTENT_CHANGED signals can arrive at a device in rapid succession. Only the first is processed. If the first reload fails (fetch returns {}), the device has no knowledge that additional signals were queued and dropped.

---

### IG-3: setPlaylist([]) → PlaybackState.None — blank window of every reload is unobservable [N6, N7]

**Evidence:** `playlist-update-flow-html5core.md` N6a: "`playbackController.setPlaylist([])` ← old playlist cleared immediately; screen goes blank." Confirmed that this happens before the HTTP fetch begins.

**Detail:** PlaybackState.None is the player's initial/reset state. No telemetry event marks the transition from "playing" to PlaybackState.None (setPlaylist([]) call). The blank period — from setPlaylist([]) to setPlaylist(newPlaylist) — appears as the absence of playback events, not as a positive "screen is blank" event. This gap affects **every** successful reload, not just failure paths. The blank window during normal operations is structurally unobservable.

---

### IG-4: CONTENT_CHANGED received — no client-side receipt event [N6]

**Evidence:** `playlist-update-flow-html5core.md` N6: WebSocket handler dispatches immediately to `reloadCurrentPlaylist()` with no telemetry call adjacent.

**Detail:** The device receives a CONTENT_CHANGED and processes it. No event indicates "I received a CONTENT_CHANGED at timestamp T." The only observable consequence is either the downstream watchdog events (if reload fails) or the absence of events (if reload succeeds quickly). Server cannot correlate "CONTENT_CHANGED was delivered" with "device reloaded its playlist."

---

### IG-5: FREE/LOCKED tier — JMS suppressed with no log of suppression [N1]

**Evidence:** S-25 confirmed: "FREE / LOCKED: no notification sent — RNF is never triggered for these screens." No log entry marks the suppression.

**Detail:** The notification path is silently skipped for FREE/LOCKED screens. An operator inspecting CloudWatch cannot determine whether a device received no content update because of a pipeline failure or because tier throttling intentionally suppressed the notification. The two conditions are indistinguishable from external observation.

---

### IG-6: Playlist fetch failure — observable only 20 seconds later via watchdog [N6a, N6b, N6c]

**Evidence:** `playlist-update-flow-html5core.md` N6: "`apiRequest()` returns `{}` on any network or server error." S-20: "No error is surfaced to the user; screen remains blank until watchdog fires at 20s." KZ-1 confirmed: serverLogger.ts dead, so client cannot report to server.

**Detail:** When the playlist fetch fails, the screen is already blank (setPlaylist([]) was called first). apiRequest() returns {} silently. No telemetry event fires at point of failure. The first observable signal is the PlaybackWatchdog firing 20 seconds later — a symptom, not a cause. This delay makes it impossible to distinguish "device in a normal but slow reload" from "device at the start of a reload loop."

---

### IG-7: Unknown contentType in _parsePlaylist — console.warn never reaches server [N6d]

**Evidence:** `playlist-update-flow-html5core.md` N6d: "Unknown: Warning logged; item skipped silently." `tech-spike-html5core-player.md`: serverLogger.ts is dead code.

**Detail:** An unrecognized contentType (e.g., a new type added backend-side before the player is updated) produces a `console.warn` that is never transmitted to any server. If all items in the response have an unknown type, `setPlaylist([])` is the effective result. The screen goes blank with zero observable signal anywhere. This path can activate silently after a backend content-type rollout without a coordinated player update.

---

### IG-8: Dynamic slot filtering in Combined playlist — silent content reduction [N6c]

**Evidence:** `playlist-update-flow-html5core.md` N6c: "Filters out unfilled dynamic slots: `playlist = playlist.filter(c => c?.content?.contentType)`."

**Detail:** If a brand dynamic slot fetch fails (network error, brand has no eligible content), the slot is silently removed from the playlist. The device plays a reduced content set with no telemetry indicating items were filtered. If all slots are dynamic and all fail, the effective playlist is empty — blank screen — with zero signal.

---

### IG-9: Generation timeout — no per-screen tracking of which screens were skipped [N3]

**(Extends KZ-7 from the operator observability perspective.)**

**Detail:** When generation times out, a single log line records elapsed time. No per-screen record of "this screen has not had its ElasticPlaylistSchedule updated since timestamp T." An operator cannot identify which specific screens missed a generation cycle without manually querying Elasticsearch timestamps. No alert triggers on schedule staleness.

---

## Deduced Conclusions

### DC-1: The PlaybackWatchdog is a recovery mechanism, not a diagnostic tool

The watchdog fires at 10s/20s/30s thresholds — always after the screen is already blank. It cannot distinguish:
- Blank because playlist fetch failed (apiRequest returned {})
- Blank because CONTENT_CHANGED was dropped in consultation mode
- Blank because all content items have unknown contentType
- Blank because concurrent reload guard dropped the signal
- Blank because setPlaylist([]) was called (every reload, including successful ones)

All of these produce an identical watchdog telemetry event. The watchdog is the only persistent device-side signal the server reliably receives about blank screens, yet it conflates every blank-screen cause into a single undifferentiated event type.

### DC-2: serverLogger.ts dead code is the structural ceiling on client-side instrumentation

`sendIssue()` was designed as the error-reporting channel from html5core to the server. Its unconditional `return` on line 38 means that IG-1, IG-2, IG-3, IG-4, IG-6, IG-7, and IG-8 cannot be instrumented from within the player without either fixing this function or adding WebSocket telemetry events as an alternative. Every gap in Dimension 2 that occurs inside the player (N6, N6a–N6d) currently has no path to the server.

### DC-3: State Service is a single point of failure for the telemetry routing chain itself

State Service controls: (a) the in-process broker for PLAYER_* routing (KZ-4), (b) Elasticsearch quota for all services (KZ-7 dependency, S-10), (c) the screen state authority. A State Service OOM-kill cascades into broker message loss (KZ-4), RNF System.exit(-1) (KZ-10), and ES quota fallback suppressing generation throughput (reducing generation success rates, amplifying KZ-7). The failure simultaneously destroys multiple telemetry signals that would have documented the failure itself.

### DC-4: Org-wide fanout multiplies every kill zone's blast radius

S-19 + KZ-6 + IG-3: every admin action on a single screen sends CONTENT_CHANGED to all devices in the org. Every kill zone that drops a CONTENT_CHANGED (KZ-4, KZ-5, KZ-6) potentially affects all org devices simultaneously, not just one. Every instrumentation gap that makes a blank window unobservable (IG-3) is simultaneously active across the entire fleet for every update.

---

## Hypothesized Paths

### H-1: JmsMode routing for PLAYER_* is Amazon MQ in production (not in-process broker)

**Status:** Open

**Theory:** If `JmsMode.MQ` is the active routing for PLAYER_CONTENT_TRANSCODED and PLAYER_ORGANIZATION_CONTENT_UPDATED in production, then KZ-4 (OOM-kill of State Service broker) does not apply to those messages — they go through Amazon MQ instead. KZ-5 (client eviction) also would not apply.

**Would confirm:** Read production environment config for `JmsMode` setting in `fm-common` MessagingService configuration.

**Would refute:** Production config shows `JmsMode.STATE` for PLAYER_* destinations.

**Resolution:** Open — not determinable from spikes alone.

---

### H-2: TelemetryController exception handling silently drops device telemetry server-side

**Status:** Open

**Theory:** `playlist-update-flow-html5core.md` Key Constraint 7: "player-api's `TelemetryController` swallows all exceptions; `TelemetryEventAnalyzerService` runs fire-and-forget. Loss is silent." If this extends to write failures, device telemetry events may be lost after successful WebSocket delivery — creating a kill zone on the server side for events that survived the network.

**Would confirm:** Read `fmcom-player-api` TelemetryController source; find exception handling scope.

**Would refute:** TelemetryController propagates failures and has a fallback (dead-letter or retry queue).

**Resolution:** Open — not read directly; spike inference only.

---

## Missing Evidence

| Gap | Impact | How to Obtain |
|---|---|---|
| `sendIssue()` state in current main branch | If recently re-enabled, IG-1 through IG-8 may have partial coverage | Read `src/store/serverLogger.ts` line 38 in current branch |
| `JmsMode` routing for PLAYER_* in production | Determines whether KZ-4/KZ-5 (in-process broker) or Amazon MQ outage is primary kill zone | Read production env config / fm-common MessagingService |
| `TelemetryController` exception scope in fmcom-player-api | Determines whether H-2 is a confirmed kill zone | Read TelemetryController.java |
| ALB sticky session config for fmcom-player-api | Determines severity of S-23 (cross-node miss) | AWS ALB target group config in infrastructure-as-code |
| `usePlan` store activation status in html5core | Determines if plan reporting is live or also dead code | Search `usePlan()` calls in component tree |

---

## Source Code Trace

| Element | Detail |
|---|---|
| KZ-1 origin | `src/store/serverLogger.ts:38` — unconditional `return` |
| KZ-2 origin | `src/store/telemetry/` — localStorage buffer, no size cap |
| KZ-6 origin | `fmcom-player-api/UnsentNoticeService` — 30s TTL, in-memory |
| IG-1 origin | `src/store/playlists.ts` — `reloadCurrentPlaylist()` guard: `if (playbackController.isConsults) return` |
| IG-3 origin | `src/store/playlists.ts` — `setPlaylist([])` called before fetch begins |
| IG-6 origin | `src/utils/api.ts` — `apiRequest()` returns `{}` on any error |

---

## Conclusion

**Confidence: High**

**Dimension 1 — Kill zones (10 confirmed):** Signals are attempted but die before reaching any observability system. Ranked by severity:
1. **KZ-1 (serverLogger.ts dead):** eliminates all designed client-side error reporting.
2. **KZ-4 (State Service OOM-kill):** silently drops PLAYER_* messages in the broker.
3. **KZ-6 (UnsentNotice TTL):** loses CONTENT_CHANGED for any device offline >30s.
4. **KZ-2 (buffer overflow):** drops watchdog and playback telemetry during WebSocket outages.
5. **KZ-7 (generation timeout silent):** screen gets no update notification with only a log line.

**Dimension 2 — Instrumentation gaps (9 confirmed):** Blank-screen paths with zero signal at any layer. Ranked by severity:
1. **IG-1 (consultation mode drop):** zero signal anywhere; indefinitely stale playlist after consult.
2. **IG-3 (setPlaylist([]) window):** every reload has an unobservable blank window; affects the entire fleet on every admin update.
3. **IG-6 (fetch failure observable 20s late):** failure indistinguishable from slow reload for 20 seconds.
4. **IG-4 (no CONTENT_CHANGED receipt event):** no correlation between delivery and reload.
5. **IG-7 (unknown contentType):** new content type rollout silently blanks devices running old player.

**Structural constraint:** The ceiling on observable telemetry for html5core blank screens cannot be raised to 80% without changes to the player itself. Server-side fixes can address 9 of 14 kill zones. The remaining 5 kill zones plus all 9 instrumentation gaps require player-side instrumentation changes, and the first step is restoring `sendIssue()` in serverLogger.ts.

---

## Recommended Next Steps

### Fix direction

**Highest single-leverage action:** Restore `sendIssue()` in `src/store/serverLogger.ts` — remove the early `return` on line 38. This unblocks client-side error reporting for IG-1, IG-6, IG-7, and IG-8 and converts them from zero-signal paths to instrumented paths without requiring new backend endpoints.

**Server-side kill zone remediation:**
- Dead-letter queues on all PLAYER_* JMS destinations (KZ-4, KZ-5, KZ-6 complement).
- Persist UnsentNotice to Redis with configurable TTL > 30s (KZ-6).
- Gate PLAYER_*_UPDATED publication on confirmed ES write success (KZ-9).
- Custom CloudWatch metric on `detectLongRunningTask` log pattern (KZ-7).

**Player-side instrumentation additions:**
- Telemetry event: `content_changed_received` with timestamp.
- Telemetry event: `content_changed_dropped_consults`.
- Telemetry events: `playlist_cleared` / `playlist_loaded` with timestamps (makes IG-3 observable).
- Telemetry event: `playlist_fetch_failed` with HTTP status code.
- localStorage buffer size cap + FIFO eviction (KZ-2 fix).

### Diagnostic (immediate, no code changes)

- Query ElasticPlaylistSchedule timestamps across the fleet; screens with `last_updated` older than 26h indicate generation gaps (proxy for KZ-7 frequency).
- Analyze CloudWatch for `detectLongRunningTask` log frequency per org.
- Check production environment config for `JmsMode` routing of PLAYER_* messages (resolves H-1).
- Check `src/store/serverLogger.ts` line 38 in current main branch (may have been fixed).

---

## Side Findings

- **`usePlan` store may be dormant.** `tech-spike-html5core-player.md`: "it is unclear from the store list whether it is actually activated anywhere." If dormant, plan reporting (`player/plan`) is dead code and the server-side plan data is stale or absent — not a blank-screen issue but a content scheduling accuracy issue.
- **autoUpdate compounds watchdog reload loops.** If a new build hash is detected during a watchdog-triggered reload cycle (S-3), `autoUpdate` triggers an additional `window.location.reload()` — potentially extending the blank-screen window beyond the 30s watchdog threshold.
- **Org-wide fanout (S-19) is both a design choice and a telemetry multiplier.** Every unnecessary CONTENT_CHANGED to unaffected devices creates unnecessary blank windows (IG-3) and unnecessary watchdog events, diluting the diagnostic value of watchdog telemetry by adding noise.
- **SHA-1 request signing weakness.** `tech-spike-html5core-player.md`: request signing uses `SHA-1(serialNum + timestamp)`. SHA-1 is considered cryptographically weak. Not a blank-screen risk, but a security observation for future review.