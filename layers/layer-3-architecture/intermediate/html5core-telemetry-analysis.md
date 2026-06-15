---
title: "html5core Telemetry Analysis — Kill Zones and Instrumentation Gaps"
owner: "Tech Lead"
status: in_progress
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
  - layers/layer-3-architecture/intermediate/investigation/html5core-telemetry-investigation.md
---

# html5core Telemetry Analysis — Kill Zones and Instrumentation Gaps

Analysis of what telemetry survives, what is lost, and what was never attempted across all nodes of the html5core playback lifecycle and content-update flow. Input to the 80% coverage feasibility assessment.

Scope: html5core fleet — covers the full system stack (html5core player, fmcom-player-api, fmcom-api, RNF, State Service). Two dimensions per node: kill zones (code tries to log, signal doesn't survive) and instrumentation gaps (code never tries to log that path). Roku and Android out of scope.

Case file: `investigation/html5core-telemetry-investigation.md`

---

## Node Analysis — Kill Zones and Instrumentation Gaps

### Playback Flow

> Nodes P-N0–P-N11 from `html5core-playlist-playback-flow.md`. Conditional paths P-CA, P-CB, P-CC.

#### Kill Zones (Playback Flow)

| Flow | Nodo | Señal intentada hoy | ¿Sobrevive? | Razón | ¿Reparable? | Señal alternativa |
|---|---|---|---|---|---|---|
| Playback | P-N9 — Steady-state telemetry flush | Playback events → localStorage buffer → WebSocket send (batch of 30 or 5-min timer) | No — OOM path | Buffer has no size cap, no TTL. If device OOMs with < 30 buffered events and 5-min timer not yet fired, all events lost. | Yes | Add buffer size cap + HTTP POST fallback when WS closed |
| Playback | P-N9 — Steady-state telemetry flush | Same buffer → WebSocket TextMessage send | No — WS-closed path | WS closes mid-send; batch in transit is lost; buffer position after partial send is undefined; events are not re-queued. | Yes | Add HTTP fallback transport; retry failed batch via HTTP |
| Playback | P-N9 — localStorage quota overflow | Playback + watchdog events → localStorage writes | No — overflow path | No size cap → extended WS outage fills localStorage (~5–10MB limit in WebView). Subsequent writes fail silently; all events after overflow are lost. | Yes | Add per-item eviction (FIFO) or cap at N events; alert when cap is hit |
| Playback | P-N7 — WebSocket handshake failure | None from device side | N/A | No device-side event for WS establishment failure. ConnectionState type exists in telemetry but requires WS to send. | Yes | Emit ConnectionState failure event via HTTP fallback (no WS required) |
| Playback | P-CA — Disconnect + CONTENT_CHANGED during gap | CONTENT_CHANGED stored in UnsentNoticeService | No — 30s TTL | If device offline > 30s, UnsentNoticeService discards the notice. Device reconnects with no knowledge of the missed update. | Partial — TTL is architectural | Add expiry metric; longer TTL is a backend config change |
| Playback | P-N10 — Watchdog 30s reload fires | PlaybackWatchdog telemetry → localStorage → post-reload flush | Yes (localStorage survives reload) | localStorage persists across `window.location.reload()`. Event is flushed on next WS reconnect — UNLESS OOM occurs after reload before WS reconnect. | Yes | OOM risk minor; main issue is the 20–30s delay before signal appears |

#### Instrumentation Gaps (Playback Flow)

| Flow | Nodo | ¿Qué información se pierde definitivamente? | ¿Reparable? | Fix requerido |
|---|---|---|---|---|
| Playback | P-N0 — Device boot | Shell-level failure (S3/CloudFront unavailable, Cordova crash) produces zero signal. App never starts; nothing to log. | Partial | Server-side: alert on absence of registration call within expected boot window for a known device MAC. Client-side: not fixable at this layer. |
| Playback | P-N1–N3 — App init, device detection, env select | Failures before first API call (Vue mount failure, localStorage corruption, missing platform SDK) are completely silent. | Partial | Server-side inference via missing registration. Client-side: not fixable without OS-level instrumentation. |
| Playback | P-N4 — Activation retry cycles | `checkActivation.ts` logs no retry attempts — only success is recorded. Number of failed 3-second poll attempts is lost. | Yes | Add retry counter telemetry event in `checkActivation.ts`. Add fmcom-player-api metric on registration failure rate. |
| Playback | P-N5 — Config fetch failure | `config.ts` fetch failure produces no device-side event. App stays in loading state with no signal. | Yes | Add telemetry event for config fetch failure. Server-side: alert on error rate for `GET /player/config`. |
| Playback | P-N6 — setPlaylist([]) blank window | The exact moment the screen goes blank is never logged. `setPlaylist([])` is called before the network fetch and transitions to PlaybackState.None — not modeled as a failure event. | Yes | Emit a dedicated telemetry event at the `setPlaylist([])` call site with context (trigger: CONTENT_CHANGED / watchdog / initial-load). |
| Playback | P-N6 — Fetch failure (apiRequest returns {}) | `apiRequest()` returns `{}` on any network or server error. No exception thrown. `_parsePlaylist` silently produces []. No device-side log. | Yes | Add error telemetry event in `apiRequest()` or at the `_parsePlaylist` call site when response is empty/malformed. |
| Playback | P-N10 — Watchdog healthy skip vs stall loop | Both appear as `PlaybackWatchdog` telemetry with the same event type. Single healthy recovery and sustained S-3 reload loop are indistinguishable. | Yes | Add a `consecutiveCount` field to watchdog telemetry; add server-side alert when count exceeds N within a window. |
| Playback | P-CB — Item failure: contentId not in watchdog telemetry | PlaybackState.Error fires and watchdog counts correctly, but no contentId is included in the watchdog telemetry event. Can't identify which content item caused the failure. | Yes | Include `currentContentId` in watchdog telemetry payload. |
| Playback | All — serverLogger.ts dead code | `sendIssue()` has unconditional `return` on line 38. No client-side error ever reaches the server proactively. Entire error-reporting path is disabled. | Yes | Remove the unconditional `return`. Reconnect to an available API endpoint (or use the existing telemetry WebSocket path for issue events). |

---

### Update Flow

> Nodes U-N0–U-N8 from `html5core-playlist-update-flow.md`.

#### Kill Zones (Update Flow)

| Flow | Nodo | Señal intentada hoy | ¿Sobrevive? | Razón | ¿Reparable? | Señal alternativa |
|---|---|---|---|---|---|---|
| Update | U-N1 — JMS publish deferred post-commit | JMS message dispatched after DB transaction commits via `TransactionSynchronizationManager`. | No — JVM crash in gap | If JVM crashes between DB commit and JMS publish, content is in MySQL as PENDING but no downstream notification fires. Message is permanently lost. | No (architectural) | Transactional outbox pattern. Alt: poll for PENDING content stuck > N minutes and re-dispatch. |
| Update | U-N2 — RNF System.exit(-1) kills in-flight transcodes | `FeignConfig.connectionCheck()` logs ERROR + container exit event. | Partial | Error log and ECS exit event exist, but no structured metric distinguishing "RNF exited due to State Service ping" from other crash causes. In-flight `PLAYER_CONTENT_TRANSCODED` messages not published. | Yes for observability | Add dedicated metric on `System.exit(-1)` code path. Requires restart-recovery retry for in-flight messages (architectural). |
| Update | U-N4 — State Service broker OOM-kill (PLAYER_* messages) | In-memory broker queue. | No | OOM-kill (SIGKILL) drops all undelivered messages. Elasticsearch snapshot only runs on clean shutdown. At-most-once delivery is a structural guarantee of the in-process broker. | No (architectural) | Migrate to Amazon MQ (durable) for PLAYER_* messages, or add DLQ + redelivery on restart from ES snapshot. |
| Update | U-N4 — fmcom-player-api client offset eviction | fmcom-player-api's BrokerStateClient offset reset after 5 min inactivity. | No | All messages published during the eviction gap are silently missed. No alert or log for offset reset. | Partial | Add alert on broker client eviction. Architectural fix: increase heartbeat frequency below 5-min threshold. |
| Update | U-N4 — Amazon MQ transient failure during publish | JMS `MessagingService.send()` call. | No | No dead-letter queue configured on any `PLAYER_*` destination. Transient MQ failure silently drops the message. | Yes | Add DLQ on `PLAYER_*` destinations; add retry/redelivery policy. |
| Update | U-N5 — CONTENT_CHANGED on wrong fmcom-player-api node | `WebSocketMessagingService.send()` → `UnsentNoticeService` fallback (30s TTL). | No — TTL path | Cross-node message: device's WS is on node B, notification arrives on node A → stored in node A's UnsentNoticeService → 30s TTL → discarded if device doesn't reconnect to node A within 30s. | Partial | Add sticky sessions (ALB) — eliminates cross-node delivery gap. Add UnsentNotice expiry metric. |
| Update | U-N5 — TelemetryController exception swallowing | `TelemetryEventAnalyzerService` fire-and-forget. | No | All exceptions in telemetry processing (escalation rule failures, manifest incompatible detection failures) are silently swallowed. No error metric. | Yes | Add exception metric in TelemetryController. Remove swallow-all; route errors to dead-letter or structured error log. |

#### Instrumentation Gaps (Update Flow)

| Flow | Nodo | ¿Qué información se pierde definitivamente? | ¿Reparable? | Fix requerido |
|---|---|---|---|---|
| Update | U-N1 — Throttle suppression for FREE/LOCKED | No metric on how many content updates are suppressed per subscription tier. Devices on FREE/LOCKED play stale playlists with no observable signal until next daily sweep. | Yes | Add metric: updates suppressed per tier. Add alert when a FREE/LOCKED device's active playlist has not been refreshed within 24h AND contains content that may be unplayable. |
| Update | U-N3 — Generation timeout produces no metric | `waitForCompletion` returns null silently. Only a `detectLongRunningTask` log line at the screen level. No metric, no alert, no retry. | Yes | Emit metric on generation timeout (increment counter per timed-out screen). Add alert when timeout rate exceeds threshold. Add per-screen "last successfully generated" timestamp with staleness alert. |
| Update | U-N6 — Consultation mode CONTENT_CHANGED drop | `reloadCurrentPlaylist()` guard `if (isConsults) return` — no log, no telemetry event, no server-side record. The update is permanently lost for this device. | Yes | Log/emit telemetry event when `CONTENT_CHANGED` is dropped due to consultation mode. Include screen MAC and timestamp. |
| Update | U-N6 — Concurrent reload CONTENT_CHANGED drop | `reloadCurrentPlaylist()` guard `if (__currentPlaylistLoading) return` — second call silently discarded with no log. | Yes | Log the drop. If the dropped update was for different content, schedule a re-fetch after `__currentPlaylistLoading` clears. |
| Update | U-N6 — setPlaylist([]) blank before fetch | Same as P-N6 gap. Every `CONTENT_CHANGED` causes an immediate blank before the network request begins. No telemetry for this moment. | Yes | Same fix as P-N6: emit dedicated event at `setPlaylist([])` call site with trigger context. |
| Update | U-N6 — Fetch failure during content reload | Same as P-N6 fetch failure gap. `apiRequest()` returns {} silently. Screen stays blank until watchdog 20s. | Yes | Same fix as P-N6: add error telemetry at fetch failure. |
| Update | U-N5 — CONTENT_CHANGED delivery confirmation absent | No end-to-end correlation between a transcode completion (U-N2) and a confirmed device-side playlist reload (U-N6). A transcode can complete successfully with no path to know whether any device received and applied the update. | Yes | Add correlation ID from `MediaProcessingMessage` through `PLAYER_CONTENT_TRANSCODED` through `CONTENT_CHANGED` through device reload. Add delivery confirmation metric at U-N5. |

---

## Blank Screen Paths Without Any Signal

These are nodes or paths where there is no kill zone to fix — the code simply never modeled this path as requiring a log entry. The blank screen persists with zero observable signal anywhere in the stack until an unrelated event (admin update, next daily sweep, watchdog stall) accidentally triggers a recovery.

**Path 1: Consultation mode absorbs CONTENT_CHANGED silently (S-22)**
Device is in consultation mode when a `CONTENT_CHANGED` WebSocket command arrives. `reloadCurrentPlaylist()` returns immediately at the `isConsults` guard. No log. No telemetry. No server-side record. After the consultation ends, the device resumes the stale playlist. The blank screen risk materializes later: if the content update removed quarantined items and the stale playlist still references them, the next playback attempt fails. Duration of zero signal: from CONTENT_CHANGED delivery until either (a) consultation ends and another update arrives, or (b) watchdog fires for an unrelated reason. In a healthcare setting with multi-hour consultation sessions, this window can exceed a shift.

**Path 2: UnsentNotice TTL expiry after device reconnect (S-24)**
Device's WebSocket was closed during a `CONTENT_CHANGED` dispatch. Notice stored in UnsentNoticeService (30s TTL). Device reconnects after > 30s — normal registration, normal WebSocket establishment. No CONTENT_CHANGED delivered. Device plays stale playlist. Registration logs show a normal reconnect; there is no record anywhere in the system that a CONTENT_CHANGED was missed. Duration of zero signal: indefinite — device continues playing stale content until the next admin update triggers another push, or the watchdog fires for an unrelated reason.

**Path 3: JMS message loss from State Service broker OOM-kill (S-17)**
Content is successfully transcoded. `PLAYER_CONTENT_TRANSCODED` is published by RNF and queued in the in-process broker. State Service is OOM-killed. Queue is lost. fmcom-player-api never receives the event. No `CONTENT_CHANGED` is sent. Devices continue playing old playlists. ECS restart event is visible in CloudWatch, but there is no end-to-end correlation between the OOM event and missed content delivery on specific screens. Duration: until next admin update or daily sweep (up to 24h).

**Path 4: encodeURIComponent bug creates infinite blank-screen loop (S-21)**
If a query parameter value contains multiple occurrences of the same reserved character, `apiRequest()` produces a malformed signed URL. Server rejects it (401 or 403). `apiRequest()` returns `{}`. `setPlaylist([])` has already been called. Watchdog fires at 20s → reloadCurrentPlaylist() → same malformed URL → same rejection → infinite loop. `serverLogger.ts` is dead code — no client-side error report reaches the server. Server-side: 401/403 errors visible at player-api but indistinguishable from an expired signature. Duration: indefinite until the parameter value changes (content update, device config change).

**Path 5: Initial playlist fetch fails at boot (P-CC)**
On boot, `setPlaylist([])` is called before the fetch. `apiRequest()` returns `{}`. Screen is blank. No telemetry event is emitted for this moment. Only recovery signal: watchdog fires at 20s (if WS is up — but WS connects at N7, after N6, and if N6 failed permanently, WS may be established). The blank-to-watchdog window (0–20s) contains zero signal anywhere in the stack. After watchdog fires, partial recovery signal exists (watchdog telemetry). If the underlying cause persists (fmcom-player-api down, RNF down), the watchdog loop (S-3) begins and the device loops indefinitely with blank screen between cycles.

---

## Cobertura por Escenario — Tabla

For each blank-screen scenario: was the blank moment logged, was the recovery logged, was causal context preserved?

**Legend:** ✓ Yes | ~ Partial | ✗ No

| ID | Escenario | ¿Blank logueado? | ¿Recovery logueado? | ¿Contexto causal preservado? |
|---|---|---|---|---|
| S-1 | RNF crash via State Service ping loss | ✗ | ~ (watchdog fires 20s+ after blank; not the blank itself) | ✗ (no metric distinguishing RNF-caused blank from generic blank) |
| S-2 | ABR escalation reaches QUARANTINE | ✗ | ~ (watchdog cycles visible; empty-playlist moment not logged) | ~ (MITIGATION events in ES track escalation; not correlated to specific blank event) |
| S-3 | Watchdog reload loop on dead endpoint | ✗ | ~ (watchdog events logged, but healthy-skip vs loop indistinguishable) | ✗ (no consecutive-count field in watchdog events) |
| S-4 | Transcoding failure, no playable content | ✗ | ✗ | ~ (FAILED status in MySQL; no correlation to screen blank) |
| S-5 | State Service cold-start cache miss | ✗ | ✗ (activation screen shown; no metric on stuck-activation duration) | ✗ |
| S-6 | State Service outage → ES quota fallback | ✗ | ✗ | ~ (ES throttle stats exist; no correlation to screen impact) |
| S-7 | JMS message loss prevents playlist regen | ✗ | ✗ | ✗ (no correlation ID across broker path) |
| S-8 | RNF generation timeout, no schedule | ✗ | ✗ (retry fires next daily sweep; no alert) | ~ (detectLongRunningTask log only; no metric) |
| S-9 | EFS mount unavailability | ✗ | ✗ | ~ (I/O exceptions in CloudWatch; FAILED in MySQL) |
| S-10 | Daily sweep skips screens under ES throttle | ✗ | ✗ | ✗ |
| S-11 | fm-common version skew, JMS deserialization | ✗ | ✗ | ✗ |
| S-12 | Device re-registration loop after reload | ✗ | ~ (activation polling loggable at player-api; no alert threshold) | ✗ |
| S-13 | Bad manifest triggers quarantine | ✗ | ~ (MITIGATION events after quarantine) | ✗ (no alert when screen reaches zero playable content) |
| S-14 | Redis escalation state permanent | ✗ | ✗ | ~ (escalation state visible in Redis; no age-distribution alert) |
| S-15 | ES write failure, stale playlist schedule | ✗ | ✗ | ~ (MySqlElasticsearchSaveFailure records; no per-screen freshness alert) |
| S-16 | XXL-Job outage stops daily sweep | ✗ | ✗ | ✗ |
| S-17 | State Service broker loses messages on OOM-kill | ✗ | ✗ | ✗ (no end-to-end delivery correlation) |
| S-18 | SyncOpService global lock saturation | ✗ | ✗ | ✗ |
| S-19 | Org-wide fanout, unnecessary reloads | ✗ | ~ (CONTENT_CHANGED loggable at player-api; no intended-vs-unintended metric) | ✗ |
| S-20 | Clear-before-fetch blank | ✗ | ~ (watchdog 20s event if fetch fails) | ✗ (no blank-duration metric) |
| S-21 | encodeURIComponent bug corrupts URLs | ✗ | ✗ (loop repeats indefinitely) | ✗ (server-side 401/403 indistinguishable from expired signature) |
| S-22 | Consultation mode drops CONTENT_CHANGED | ✗ | ✗ (no deferred delivery; stale content until next admin update) | ✗ |
| S-23 | In-memory WS sessions lost across nodes | ✗ | ✗ | ✗ (no UnsentNotice expiry metric) |
| S-24 | UnsentNotice 30s TTL drops CONTENT_CHANGED | ✗ | ✗ | ✗ (device reconnects normally; no record of missed update) |
| S-25 | FREE/LOCKED tiers no push notifications | ✗ | ~ (daily sweep runs; no alert on stale-content risk) | ✗ |

**Summary:**
- Blank moment logged: **0 / 25** (0%)
- Recovery logged (at least partial): **9 / 25** (36%)
- Causal context preserved (at least partial): **8 / 25** (32%)

---

## Narrativa por Path de Impacto Máximo

These are the paths where there is zero signal across the entire stack — no log, no metric, no telemetry — and the blank screen can persist for an extended, operationally significant window.

### Path: Consultation Mode Absorbs CONTENT_CHANGED (S-22)

A medical provider updates content in VPM (e.g., removes a quarantined item, adds a new patient-facing video). `fmcom-api` dispatches `RNF_GENERATE`, RNF regenerates the playlist, `PLAYER_ORGANIZATION_CONTENT_UPDATED` is published, fmcom-player-api fans it out to all org devices, and `CONTENT_CHANGED` arrives at the html5core player via WebSocket. The player is in consultation mode — a practitioner is running a brand consultation with a patient. `reloadCurrentPlaylist()` checks `playbackController.isConsults === true` and returns immediately. No log. No telemetry event. No server-side record. The CONTENT_CHANGED is gone.

After the consultation ends, `isConsults` flips to false. Playback resumes from the stale playlist. The stale playlist may still contain the removed-quarantined item. The player attempts to load it; `VideoPlayer.vue` fires `@error`; watchdog fires at 10s → pressNext. The screen may or may not blank depending on whether the watchdog skip is seamless. The practitioner and the next patient see content the provider intended to remove. The operator has no signal that this happened — the `CONTENT_CHANGED` that was supposed to apply is gone without trace.

**Duration with zero signal:** From CONTENT_CHANGED delivery until either (a) the consultation ends and a second admin update triggers another push, or (b) watchdog stalls for an unrelated reason. In a full-day clinic, consultations may run 8+ hours. During that window, the device is operationally unreachable for content updates with no visibility into this state.

**Operational decision blocked:** An operator cannot know whether a specific device received and applied a content update during an active consultation. There is no way to confirm content compliance on consulting devices without manual physical inspection.

### Path: UnsentNotice Expiry After Device Reconnect (S-24)

A device loses its WebSocket connection — network blip, ISP latency spike, device reboot after a power surge. At the same moment, an admin updates content. fmcom-player-api dispatches CONTENT_CHANGED. The device's WS session is closed; the notice goes to `UnsentNoticeService`. html5core reconnects after 1000ms — but the building's network takes 45 seconds to recover. The 30-second TTL fires. UnsentNoticeService's 10-second cleanup task discards the notice.

The device reconnects at 45 seconds. `register()` is called. `UnsentNoticeService` has nothing to deliver — the notice was discarded 15 seconds earlier. WebSocket is re-established. Device resumes playing the old playlist. The registration call at player-api looks completely normal. CloudWatch shows a successful reconnect. The device is playing content the admin updated 45 seconds ago.

**Duration with zero signal:** Until the next admin content change (could be hours, days), or until a coincident watchdog reload (unlikely if playback is healthy). In the absence of another triggering event, the device plays stale content indefinitely with no observable signal.

**Operational decision blocked:** An operator investigating "why is this screen showing old content?" will find no evidence in logs, metrics, or telemetry that a CONTENT_CHANGED was missed. The reconnect looks clean. The telemetry shows no errors. Only a manual check of the device's current playlist vs. the admin's intended content reveals the divergence.

### Path: State Service Broker OOM-Kill Swallows Transcode Completion (S-17)

RNF finishes transcoding a newly-uploaded video. `UnifiedVideoPipeline.onComplete()` publishes `PLAYER_CONTENT_TRANSCODED` to the State Service in-process broker. Simultaneously, State Service hits its unbounded `ConcurrentHashMap` heap limit (screen cache grows without eviction). ECS kills the container with SIGKILL. The broker's `BrokerServiceImpl.stop()` never fires — the Elasticsearch snapshot is not written. The queued `PLAYER_CONTENT_TRANSCODED` message is gone.

fmcom-player-api instances that subscribe via `BrokerStateClient` never receive the event. No `CONTENT_CHANGED` is sent to any device. The new video is fully transcoded, S3 artifacts exist, CloudFront is populated. But devices play the old playlist indefinitely. State Service restarts, ECS brings it back online. Everything looks healthy. CloudWatch shows an OOM-kill event on State Service — but this event is not linked to any downstream content delivery outcome.

**Duration with zero signal:** Until the next daily `playlistDailyUpdate` sweep (up to 24h), which will regenerate schedules including the new content, or until a subsequent admin action triggers another PLAYER_* event.

**Operational decision blocked:** An operator who uploaded a video and is watching for it to appear on screens has no way to determine from the system's telemetry whether the video was delivered. The transcode-to-screen path is untracked end-to-end. The operator must wait 24h and check devices manually to confirm delivery.

### Path: encodeURIComponent Bug Creates Infinite Blank Loop (S-21)

A content item or playlist with a parameter value containing multiple occurrences of the same reserved character (e.g., `&&` in a content ID, `==` in a playlist token) triggers the `apiRequest()` encoding bug in html5core. The encoded URL is incorrect. The SHA-1 signature is computed over the wrong URL. fmcom-player-api rejects the request (401 or 403 — indistinguishable from an expired signature). `apiRequest()` returns `{}`. `setPlaylist([])` was called before the request. Screen is blank.

Watchdog fires at 20s → `reloadCurrentPlaylist()` → `setPlaylist([])` again → same malformed request → same rejection → screen blank again. This cycles every 20–30 seconds: blank, watchdog, reload, blank. `serverLogger.ts` is dead code — no client-side error reports reach the server. Server-side: a stream of 401/403 errors on `GET /player/playlist/current` is visible but indistinguishable from an expired device signature (any device that hasn't re-registered recently produces the same pattern).

**Duration with zero signal:** Indefinite. The loop continues until the parameter value that triggered the encoding bug changes — which requires either a content update that removes the problematic item, or manual device intervention. There is no self-healing mechanism. The device looks like it's "trying" (watchdog and reload events fire) but the root cause is invisible.

**Operational decision blocked:** Support cannot distinguish this scenario from S-3 (dead endpoint loop) or S-12 (re-registration failure) without physically inspecting the device. The 401/403 error stream at player-api could indicate device auth expiry, network interception, or the encoding bug — all look the same from the server's perspective.

---

## Distribución de Responsabilidad de los Fixes

Who needs to change code to close each gap. "html5core" = requires a player app deployment. "Backend" = deployable independently of html5core. "Both" = requires changes in both.

| Categoría | Total findings | Reparables (sin cambio arquitectural) | Requiere html5core | Solo backend | Ambos |
|---|---|---|---|---|---|
| Kill zones | 11 | 7 | 4 | 3 | 0 |
| Instrumentation gaps | 12 | 12 | 8 | 4 | 0 |
| Estructurales (cambio arquitectural requerido) | 4 | 0 | 0 | 4 | 0 |
| **Total** | **27** | **19** | **12** | **11** | **0** |

### Kill zones — detalle

| Kill zone | Reparable? | Propietario | Tipo de fix |
|---|---|---|---|
| localStorage buffer OOM / no size cap | Sí | html5core | Add cap (e.g., 200 events max) + evict oldest on overflow |
| WS batch lost mid-send | Sí | html5core | Add HTTP fallback transport; retry failed batch |
| localStorage quota overflow | Sí | html5core | Same as cap fix above; add write-failure detection |
| WS handshake failure — no device signal | Sí | html5core | Emit ConnectionState failure event via HTTP |
| TelemetryController swallows exceptions | Sí | Backend (player-api) | Add error metric; structured error log |
| Amazon MQ no DLQ on PLAYER_* | Sí | Backend (player-api / RNF) | Add DLQ + redelivery policy |
| fmcom-player-api broker client eviction 5min | Sí | Backend (player-api) | Increase polling/heartbeat frequency below 5-min threshold |
| UnsentNotice 30s TTL — no expiry metric | Parcial | Backend (player-api) | Add expiry counter metric; TTL increase is config change |
| State Service broker at-most-once (OOM-kill) | No — arquitectural | Backend (state-service) | Migrate PLAYER_* to Amazon MQ (durable); or at-least-once broker |
| Cross-node WS delivery (no sticky sessions) | No — arquitectural | Backend (player-api) | ALB sticky sessions OR distributed WsSessionHolder |
| fmcom-api JMS deferred publish (post-commit gap) | No — arquitectural | Backend (fmcom-api) | Transactional outbox pattern |
| RNF System.exit(-1) in-flight messages lost | No — arquitectural | Backend (RNF) | Retry on restart; State Service health check with backoff |

### Instrumentation gaps — detalle

| Gap | Reparable? | Propietario | Tipo de fix |
|---|---|---|---|
| setPlaylist([]) blank moment — no event | Sí | html5core | Emit `PlaylistCleared` telemetry event with trigger context |
| apiRequest() fetch failure — silent | Sí | html5core | Emit error telemetry in `apiRequest()` on failure |
| Consultation mode CONTENT_CHANGED drop | Sí | html5core | Log + emit telemetry on guard-return |
| Concurrent reload drop | Sí | html5core | Log drop; optionally schedule re-fetch |
| Activation retry cycles unlogged | Sí | html5core | Add retry counter telemetry in `checkActivation.ts` |
| serverLogger.ts dead code | Sí | html5core | Remove unconditional `return` on line 38 of `serverLogger.ts` |
| PlaybackState.None not modeled as failure | Sí | html5core | Distinguish "blank-before-fetch" from "normal item-end None" via trigger field |
| Watchdog: healthy-skip vs stall-loop same event | Sí | html5core | Add `consecutiveCount` field to PlaybackWatchdog event |
| RNF generation timeout — no metric | Sí | Backend (RNF) | Emit metric on timeout; add per-screen freshness staleness alert |
| Per-screen "last generated" freshness alert | Sí | Backend (RNF / player-api) | Track last-generated timestamp per screen; alert when stale > 25h |
| FAILED transcode — no alert threshold | Sí | Backend (RNF / fmcom-api) | Alert on FAILED transcode count > N within window |
| CONTENT_CHANGED delivery confirmation absent | Sí | Backend (player-api) | Add correlation ID from U-N2 to U-N6; delivery confirmation metric |

---

## Key Constraints for Feasibility Assessment

The following facts are inputs for the `skill-roundtable` Step 2 evaluation:

1. **0 of 25 blank-screen scenarios have the blank moment itself logged today.** This means the baseline is zero for the most operationally important signal. Getting to 80% from zero requires both instrumentation additions and, for some scenarios, architectural changes.

2. **12 of 27 findings require html5core changes.** Each html5core fix requires a player deployment to all devices. Deployment cadence and staging risk (webOS/Tizen backward compatibility, Chrome 53 target) are execution constraints.

3. **4 structural kill zones cannot be fixed by adding instrumentation.** They require backend architectural changes: at-least-once delivery for the State Service broker, distributed or sticky WebSocket sessions, transactional outbox in fmcom-api, and DLQs on all PLAYER_* message destinations. These are the highest-effort items and block complete coverage of S-7, S-17, S-23, and the JMS-post-commit gap.

4. **The 19 reparable findings (12 gaps + 7 kill zones) are achievable without architectural changes** — they require code additions, not rewrites. These alone would move coverage from ~5% to an estimated 55–65% of observable failures (not 80%), because the 4 structural kill zones cover a significant share of the highest-frequency failure modes (S-7, S-17, S-23, S-24 collectively represent the primary content-update delivery path).

5. **Backend fixes (11 findings) do not require html5core changes** and can be deployed independently. They can proceed in parallel with html5core work, which has higher deployment risk.

6. **The html5core `serverLogger.ts` dead-code fix is the highest leverage single change**: re-enabling `sendIssue()` (removing one `return` statement) would restore the proactive error-reporting path for all client-side failure events — making all other html5core instrumentation additions immediately deliverable to the backend without the 5-minute telemetry flush delay.