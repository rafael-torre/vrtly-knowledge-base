---
title: "Blank Screen Scenarios — Risk Register"
last_updated: 2026-06-12
status: in_progress
relates_to:
  - layers/layer-3-architecture/intermediate/tech-spike-rnf.md
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-player-api.md
  - layers/layer-3-architecture/intermediate/tech-spike-html5core-player.md
  - layers/layer-3-architecture/intermediate/tech-spike-state-service.md
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-api.md
  - layers/layer-3-architecture/intermediate/tech-spike-fm-common.md
---

# Blank Screen Scenarios — Risk Register

This document catalogues every identified scenario that can cause a physical display device to show a blank or frozen screen. Each entry documents the full failure flow across services, the repos involved, current telemetry coverage, and any unverified assumptions.

Sources: tech spikes for `reach-n-freq`, `fmcom-player-api`, `html5core-player`, `state-service`, `fmcom-api`, `fm-common`.

---

## Scenario Index

| ID | Name | Primary Trigger |
|---|---|---|
| S-1 | RNF crash via State Service ping loss | `FeignConfig.connectionCheck()` calls `System.exit(-1)` on State Service ping failure |
| S-2 | ABR escalation reaches QUARANTINE with no recovery path | Accumulated decode failures advance escalation ladder to terminal state |
| S-3 | Playback watchdog reload loop on dead playlist endpoint | `playbackWatchdog` reloads into a still-failing API call |
| S-4 | Content transcoding failure leaves screen with no playable content | `UnifiedVideoPipeline` failure with no `ContentAddMessage` published |
| S-5 | State Service cold-start cache miss during device registration | Empty `ConcurrentHashMap` on restart causes serial MySQL failures under load |
| S-6 | State Service outage cascades to ES quota fallback and playlist generation failure | All services fall back to `initial-limit` (1–3 queries/instance) |
| S-7 | JMS message loss prevents playlist regeneration after content change | Amazon MQ or in-process broker drops `PLAYER_CONTENT_TRANSCODED` |
| S-8 | RNF playlist generation timeout produces no schedule for a screen | `waitForCompletion` returns null/empty set silently after 5-minute deadline |
| S-9 | EFS mount unavailability halts transcoding pipeline | No new transcoded content; existing content eventually exhausted or quarantined |
| S-10 | Daily playlist generation sweep silently skips screens under Elasticsearch throttle | ES quota exhausted before all screens are generated |
| S-11 | `fm-common` version skew causes silent JMS payload deserialization failure | State Service at 8.7.8 drops fields added in 8.9.x payload DTOs |
| S-12 | Device re-registration loop after watchdog reload | Session key lost on reload; re-registration blocks on slow or unavailable State Service |
| S-13 | Bad content manifest triggers quarantine via `ContentManifestIncompatibleDetectionRule` | Multi-vendor codec errors escalate content to quarantine before re-transcode can recover it |
| S-14 | Redis escalation state permanent without TTL — content never recovers after partial failure | `PLAYBACK_ESCALATION_PREFIX` key has no TTL; stage is never reset unless re-transcode event arrives |
| S-15 | Elasticsearch index write failure leaves playlist schedule stale | `ElasticsearchSaveFailure` records accumulate; `PlaylistCurrentService` reads from a stale or missing index |
| S-16 | XXL-Job admin outage stops daily playlist generation sweep | All 18 RNF XXL-Job handlers cease; daily `playlistDailyUpdate` never runs |
| S-17 | In-process broker in State Service loses messages on ungraceful shutdown | State Service OOM-kill or SIGKILL drops all undelivered `PLAYER_*` topic messages |
| S-18 | Deployment write storm saturates `SyncOpService` global lock in State Service | Per-screen mutex serializes all screen writes through a single monitor during deployment window |

---

### S-1: RNF Crash via State Service Ping Loss

**Summary:** A transient State Service outage causes `FeignConfig.connectionCheck()` in RNF to call `System.exit(-1)`, restarting the container and leaving `fmcom-player-api` unable to serve playlists for the restart gap duration.

**Trigger:** The 1-minute `@Scheduled` timer in `FeignConfig.connectionCheck()` fires while the State Service ping at `GET /ping` (via `InstanceStateClient`) fails — whether due to State Service restart, network hiccup, or health-check flapping.

**Full flow:**
1. [reach-n-freq] `FeignConfig.connectionCheck()` fires on its 1-minute `@Scheduled` interval. It calls `InstanceStateClient.ping()` (Feign HTTP → `${SERVICE_DISCOVER_STATE}/ping`).
2. [state-service] The ping fails (State Service is restarting, network is degraded, or load balancer health check is in progress).
3. [reach-n-freq] `FeignConfig.connectionCheck()` immediately calls `System.exit(-1)` — no retry, no backoff, no circuit breaker. The JVM terminates. Any in-flight transcodes are abandoned; the shutdown hook marks claimed rows as `FAILED`.
4. [reach-n-freq] AWS ECS detects the exited container and schedules a replacement task. There is a restart gap (typically tens of seconds) while the new container initialises and passes health checks.
5. [fmcom-player-api] During the restart gap, `RnfFeignClient.getPlaylistCurrent(screenId)` calls `GET ${SERVICE_DISCOVER_RNF}/playlist/current/{screenId}` and receives a connection error or 503.
6. [fmcom-player-api] The playlist endpoint returns an error response. `fmcom-player-api` cannot serve `GET /player/playlist/current` to devices.
7. [html5core-player] The `playbackWatchdog` fires its graduated recovery sequence: at 10 s of no state-hash change, it calls `pressNext`; at 20 s, it calls `resetPlaylist` (re-fetches from the API — fails again); at 30 s, it calls `window.location.reload()` (the app restarts, re-registers, and immediately re-fetches — still fails because RNF is not yet up).
8. [html5core-player] With no local playlist cache (no IndexedDB, no localStorage playlist storage), the player has nothing to fall back on. The screen shows whatever frame was last rendered and then goes blank, or displays the loading/activation screen.
9. [reach-n-freq] Once ECS brings the new RNF container online, `fmcom-player-api` can again call `GET /playlist/current/{screenId}` and normal playlist delivery resumes.

**Repos involved:** `reach-n-freq`, `fmcom-player-api`, `html5core-player`, `state-service`

**Telemetry coverage:**
- *Exists today:* `FeignConfig` logs `FATAL: Connection to State Service lost` at `ERROR` level in CloudWatch. ECS task stop and restart events are visible in CloudWatch ECS logs. `html5core-player` sends `PlaybackWatchdog` telemetry events over WebSocket to `fmcom-player-api`, which writes them to Elasticsearch (`TelemetryDto` with type `PlaybackWatchdog`). Player heartbeat gaps are visible in WebSocket connection logs.
- *Missing:* No dedicated CloudWatch alarm or metric on the specific `System.exit(-1)` path — it appears only as an ERROR log line and a container exit event. No metric distinguishing "RNF exited due to State Service ping failure" from a crash for another reason. No alert on `fmcom-player-api` playlist endpoint error rate spike corresponding to RNF restart gap. No signal that the device ended up blank (the watchdog telemetry records that it fired, but there is no explicit "no content served" event). No RNF restart-gap duration SLO or alert.

**Assumptions:**
- [assumption - strong] `FeignConfig.connectionCheck()` in RNF calls `System.exit(-1)` with no retry or backoff on any ping failure — this is directly confirmed in the tech spike for `reach-n-freq` and in the `config` package description.
- [assumption - strong] There is no local playlist cache in `html5core-player` — the spike explicitly confirms no IndexedDB or localStorage playlist storage.
- [assumption - strong] ECS restarts the container but there is a finite restart gap during which RNF is unavailable.
- [assumption - unverified] `PlaylistCurrentServiceLocal` in `fmcom-player-api` is not a hot standby fallback for the RNF Feign path during restarts. The system map notes this is unconfirmed and the spike evidence does not confirm it acts as a circuit-breaker.
- [assumption - unverified] The exact restart gap duration under ECS task replacement in the production cluster is not documented in any spike.

---

### S-2: ABR Escalation Reaches QUARANTINE with No Recovery Path

**Summary:** Accumulated decode failures on a device advance the per-(screen, content) escalation state machine in `fmcom-player-api` through all six stages to `QUARANTINE`, at which point content stops playing on that screen entirely and the state persists indefinitely unless a re-transcode event clears it.

**Trigger:** A content item with a bad transcode (incompatible codec, corrupted HLS segments, or resolution mismatch for the device) causes repeated decode failures reported as telemetry events by `html5core-player`.

**Full flow:**
1. [html5core-player] `VideoPlayer.vue` fails to decode a content item (HLS segment decode error, codec mismatch, or FFmpeg artifact). The player emits a telemetry event with type indicating decode failure, batched in `telemetryQueue` and sent over WebSocket to `fmcom-player-api`.
2. [fmcom-player-api] `TelemetryEventAnalyzerServiceImpl` dispatches the event asynchronously to `ContentPlaybackEscalationRule`.
3. [fmcom-player-api] `ContentPlaybackEscalationRule` increments the `freshFails` counter for this `(screenId, contentId)` pair. When `freshFails` exceeds the configured threshold and the 30-minute `settle-grace-minutes` window has elapsed, `PlaybackEscalationServiceImpl` advances the `PlaybackEscalationStage` enum: `HLS_FULL → HLS_720 → SRC_ORIGINAL → SRC_720 → SRC_540 → QUARANTINE`. Each advance is stored in Redis at key `screen:content:escalation:{screenId}:{contentId}` with no TTL.
4. [fmcom-player-api] `ContentUtils.updateContentUrls()` reads the escalation state from Redis on every playlist and consult response, rewriting content URLs to serve the degraded variant. At `QUARANTINE`, `ContentQuarantineService` (from `fm-common`) places a quarantine record in MySQL (`MySqlContentQuarantine`) and publishes `API_CONTENT_QUARANTINE` to JMS.
5. [fmcom-api] `ContentQuarantineHandlers` receives `API_CONTENT_QUARANTINE` and processes the quarantine. The content item is removed from playlist eligibility for that screen.
6. [html5core-player] On the next `resetPlaylist` or `CONTENT_CHANGED` WebSocket push, `html5core-player` fetches a new playlist from `fmcom-player-api`. If enough content items are quarantined, the playlist shrinks. If all content for a screen is quarantined (all items for the organization failed), the playlist becomes empty and the player has nothing to play — resulting in a blank screen.
7. [reach-n-freq] Playlist generation (`PlaylistGenerationServiceImpl`) reads eligible content via `ContentServiceExt`. Quarantined content is excluded. If the organization has insufficient non-quarantined content to fill a full schedule, the generated schedule is sparse or empty.
8. [html5core-player] The `playbackWatchdog` fires if no content plays (10 s → pressNext, 20 s → resetPlaylist, 30 s → reload). Each reload re-fetches the playlist, which remains empty. The screen stays blank.

**Repos involved:** `html5core-player`, `fmcom-player-api`, `fmcom-api`, `reach-n-freq`, `fm-common`

**Telemetry coverage:**
- *Exists today:* `MITIGATION` telemetry events are written to Elasticsearch for each escalation advance. `ContentPlaybackEscalationRule` records stage transitions. `API_CONTENT_QUARANTINE` JMS publish is observable through broker logs. `MySqlContentQuarantine` rows in MySQL record quarantined content. `PlaybackWatchdog` telemetry events from the device are written to Elasticsearch.
- *Missing:* No alert when a screen reaches zero playable content in its generated playlist. No user-facing notification in VPM when a content item is quarantined (confirmed gap in the roundtable: "no confirmed user-facing surface in the provider portal that exposes quarantine state"). No automatic re-transcode trigger when content is quarantined — recovery requires manual operator action. No signal that the watchdog is cycling on an empty playlist vs. cycling on a slow network. No "playlist is empty" event emitted by `fmcom-player-api` or `html5core-player`.

**Assumptions:**
- [assumption - strong] The escalation state has no TTL in Redis — the spike for `fmcom-player-api` explicitly states the escalation state is "stored permanently in Redis (no TTL)."
- [assumption - strong] State is only reset by a re-transcode event or device firmware change triggering `QuarantineRestoreServiceImpl.`
- [assumption - strong] `ContentUtils.updateContentUrls()` reads Redis escalation state on every content item in every playlist response — confirmed in spike observation 13 (30–60 synchronous Redis reads per request on large playlists).
- [assumption - unverified] Whether `PlaylistCurrentServiceLocal` in `fmcom-player-api` can serve a non-empty playlist for a screen when all content is quarantined is not confirmed. The spike does not document its content-eligibility filtering logic.
- [assumption - unverified] The exact threshold for `freshFails` before escalation advances is configuration-dependent and not documented in the spikes.

---

### S-3: Playback Watchdog Reload Loop on Dead Playlist Endpoint

**Summary:** When `fmcom-player-api` is unavailable or returns errors on `GET /player/playlist/current`, the `playbackWatchdog` in `html5core-player` enters a 30-second loop that terminates in a full `window.location.reload()`, which re-fetches from the same broken endpoint, creating an indefinite reload loop with blank screen between cycles.

**Trigger:** Any condition that makes `fmcom-player-api`'s playlist endpoint unavailable or error-returning for more than 30 seconds: RNF downtime (see S-1), Redis unavailability (endpoint reads escalation state), MySQL pool exhaustion (endpoint reads screen config), or network partition between the device and the player API.

**Full flow:**
1. [html5core-player] The `playbackController` is playing content normally. A disruption occurs — `fmcom-player-api` becomes unreachable or returns 5xx for all playlist requests.
2. [html5core-player] `playbackWatchdog` monitors the playback state hash. If the hash does not change for 10 seconds (because the current content stalls or the playlist is exhausted), it calls `pressNext` (advances to the next item in the current playlist array).
3. [html5core-player] If the hash still does not change after 20 seconds, `playbackWatchdog` calls `resetPlaylist`. `playlists.ts` calls `GET /player/playlist/current` from `fmcom-player-api`. The request fails. The playlist store retains the old (possibly stale) playlist or sets it to empty.
4. [html5core-player] If the hash still does not change after 30 seconds, `playbackWatchdog` calls `window.location.reload()`. The entire Vue SPA restarts from the beginning of the activation flow.
5. [html5core-player] On reload, `checkActivation.ts` polls `POST /player/registerDevice` every 3 seconds. `fmcom-player-api` responds (if available); the session key is reissued. The app transitions to the player screen.
6. [html5core-player] The player immediately calls `GET /player/playlist/current` to fetch the playlist. If `fmcom-player-api` is still returning errors (because it depends on the still-broken upstream — RNF, Redis, MySQL), the fetch fails again.
7. [html5core-player] With no local cache, there is nothing to play. The screen is blank (or shows a loading state). The `playbackWatchdog` starts its 30-second cycle again.
8. [html5core-player] The loop repeats: every 30 seconds the page reloads; every reload re-registers and immediately re-fetches a playlist that cannot be served.
9. The loop continues until `fmcom-player-api` and its upstream dependencies recover.

**Repos involved:** `html5core-player`, `fmcom-player-api`, `reach-n-freq`

**Telemetry coverage:**
- *Exists today:* `PlaybackWatchdog` telemetry events at each threshold (10 s, 20 s, 30 s) are sent via WebSocket and written to Elasticsearch. WebSocket reconnection events after each `window.location.reload()` are observable in connection logs. HTTP 5xx errors on `GET /player/playlist/current` are loggable at `fmcom-player-api`.
- *Missing:* No metric or alarm on `window.location.reload()` call frequency per screen. No alert when a screen has reloaded more than N times within a window. No signal distinguishing a "healthy watchdog skip" from a "watchdog reload loop" — both appear as `PlaybackWatchdog` telemetry with the same type. No count of consecutive playlist-fetch failures per screen. The `serverLogger.ts` server-side issue reporting feature in `html5core-player` is confirmed dead code (`sendIssue()` has an unconditional early `return`), so no server-side error reporting exists from the player on reload.

**Assumptions:**
- [assumption - strong] There is no local playlist cache in `html5core-player` — confirmed in the tech spike.
- [assumption - strong] `window.location.reload()` at the 30-second watchdog threshold is confirmed in `src/store/playbackWatchdog.ts`.
- [assumption - strong] `serverLogger.ts` `sendIssue()` is dead code — confirmed in the spike ("has an unconditional `return` on line 38, making the entire server-side logging feature dead code").
- [assumption - unverified] The duration of the app bootstrap and activation cycle after `window.location.reload()` on a slow device (webOS, Tizen with Chrome 53 target) may be significant, extending the blank screen window beyond 30 seconds per cycle.
- [assumption - unverified] Whether the `autoUpdate` check on playlist reload can compound this scenario by triggering an additional `window.location.reload()` for a pending build update during the loop is not confirmed.

---

### S-4: Content Transcoding Failure Leaves Screen with No Playable Content

**Summary:** A failure anywhere in the `UnifiedVideoPipeline` four-stage transcoding process prevents `API_CONTENT_ADD` from being published, leaving the content in a `PENDING` or `FAILED` transcode state permanently and never adding it to any screen's playlist.

**Trigger:** Any of the following inside `UnifiedVideoPipeline`: S3 download failure, FFmpeg normalisation crash, standalone-tier variant generation error, HLS ladder generation error, S3 upload failure, or EFS unavailability during file staging.

**Full flow:**
1. [fmcom-api] A provider uploads a video via VPM. `fmcom-api` stores the file on S3, creates a `Content` entity in MySQL with `transcodingStatus: PENDING`, and dispatches `MediaProcessingMessage` to the `RNF_MEDIA_PROCESSING` JMS queue.
2. [reach-n-freq] `MediaProcessingHandlers` receives the JMS message and routes it through `MediaPipelineOrchestrator` to `UnifiedVideoPipeline`. The pipeline claims the content item (marks it in-flight in the `inPipeline` set and the database).
3. [reach-n-freq] The pipeline fails at one of its four stages. Failure modes include: EFS mount unavailable (no file staging path), FFmpeg exits non-zero (codec or container incompatibility), S3 upload error (credentials expired, bucket policy change), or an uncaught exception in the HLS ladder generation.
4. [reach-n-freq] On pipeline failure for `TriggerMode.MESSAGE` flows, the shutdown hook marks the claimed content row as `FAILED` in MySQL (via `transcodingStatus` update). `UnifiedVideoPipeline.onComplete()` is not called, so `ContentAddMessage` is never published to `API_CONTENT_ADD`.
5. [fmcom-api] With no `API_CONTENT_ADD` received, `ContentMessageHandlers` never fires. The content is not added to any screen's `ScreenContent` association. The content item's `transcodingStatus` stays at `FAILED` (or `PENDING` if the failure happened before claim).
6. [reach-n-freq] Playlist generation (`PlaylistGenerationServiceImpl`) runs the next daily sweep. `ContentServiceExt` loads content eligible for the screen. Content with `transcodingStatus: FAILED` is excluded from eligibility. If all new content for an organization failed transcoding, the playlist is generated from the existing pool of previously-successful content.
7. If the previously-successful content pool is empty (new organization with no historical content, or all prior content has since been quarantined), the generated playlist is empty. `fmcom-player-api` serves an empty playlist; `html5core-player` has nothing to play and the screen goes blank.
8. [reach-n-freq] The `executeTranscoding` XXL-Job sweep (`TranscodeHandlers.executeTranscoding`) is designed to retry stuck or FAILED transcodes. If the underlying failure condition persists (EFS unavailable, FFmpeg version mismatch), the retry will fail again.

**Repos involved:** `reach-n-freq`, `fmcom-api`, `fmcom-player-api`, `html5core-player`

**Telemetry coverage:**
- *Exists today:* `transcodingStatus: FAILED` is a queryable MySQL state. `UnifiedVideoPipeline` logs FFmpeg stderr and exception stack traces to CloudWatch. JMS `API_CONTENT_ADD` publication absence is not directly observable without a dead-letter queue or correlation ID.
- *Missing:* No alert on `transcodingStatus: FAILED` entries older than a threshold (e.g., failed transcode not retried within 24 hours). No metric on the number of screens with empty generated playlists. No notification to the provider in VPM that a content upload failed transcoding — the spike identifies this as a product gap. No correlation between failed transcode events and subsequent playlist emptiness per screen. No dead-letter queue on `RNF_MEDIA_PROCESSING` for messages that could not be processed.

**Assumptions:**
- [assumption - strong] `UnifiedVideoPipeline.onComplete()` is the only publisher of `API_CONTENT_ADD` for `TriggerMode.MESSAGE` flows — confirmed in the RNF spike observation 1.
- [assumption - strong] EFS unavailability directly halts the pipeline with no code-level fallback — confirmed in the RNF spike observation 5.
- [assumption - unverified] Whether `ContentAddMessage` idempotency in `ContentMessageHandlers` would prevent a re-published message (after a retry sweep) from double-adding content to a screen is confirmed as an open question in the system map.
- [assumption - unverified] The exact set of conditions that produce `PENDING` vs `FAILED` transcode status after a pipeline abort is not fully documented in the spikes.

---

### S-5: State Service Cold-Start Cache Miss During Device Registration

**Summary:** After a State Service restart with an empty in-memory cache, a wave of simultaneous device registrations causes serial MySQL lookups for every screen, potentially exceeding the connection pool and causing registration failures that leave devices on the blank activation screen.

**Trigger:** State Service container replacement (planned deployment or crash recovery) with a large fleet of devices simultaneously re-registering (e.g., after a power outage in a building or a mass player reload triggered by S-3).

**Full flow:**
1. [state-service] State Service restarts with an empty `ConcurrentHashMap<Long, ScreenDto>` cache. No pre-warming mechanism exists — the spike confirms there is no pre-load on startup, only lazy population on first request.
2. [fmcom-player-api] Devices reconnect and call `POST /player/registerDevice` every 3 seconds. `fmcom-player-api`'s `RegistrationServiceImpl` calls `ScreenStateClient.getByMac(mac)` to look up the screen.
3. [state-service] `ScreenController.getByMac()` has a cache miss (empty map). It queries MySQL via `ScreenRepository.findByMac()`. For N simultaneous reconnecting devices, N concurrent MySQL queries are issued.
4. [state-service] `state-service` has a MySQL pool of 10 connections. With hundreds of simultaneously reconnecting devices, the pool is exhausted and new requests queue or time out. The JPA query timeout is 15 seconds and the lock timeout is 1 second.
5. [fmcom-player-api] `ScreenStateClient.getByMac()` calls time out or return errors. `RegistrationServiceImpl` cannot complete device registration. The response to `POST /player/registerDevice` is an error.
6. [html5core-player] `checkActivation.ts` retries every 3 seconds. The device displays the pairing QR code screen (activation screen) to waiting-room patients.
7. [state-service] As the MySQL queries complete one by one, cache entries are populated. Subsequent lookups for the same screen hit the cache. But during the cold-start flood, some devices may wait minutes before their registration succeeds.

**Repos involved:** `html5core-player`, `fmcom-player-api`, `state-service`

**Telemetry coverage:**
- *Exists today:* MySQL slow query logs (if enabled) would capture pool-exhaustion delays. `state-service` logs connection pool metrics via Spring Boot Actuator. CloudWatch ECS task restart events mark the start of the cold-start window.
- *Missing:* No metric on `ConcurrentHashMap` cache miss rate in `state-service`. No alert when `ScreenStateClient.getByMac()` error rate spikes. No signal distinguishing a cold-start registration failure from a normal registration flow (both look the same from the device's perspective — the activation screen is shown). No cache pre-warming mechanism or documented warm-up procedure.

**Assumptions:**
- [assumption - strong] The in-memory cache has no pre-load — confirmed in state-service spike open question 6: "On a fresh start with an empty cache, all screen lookups trigger MySQL queries."
- [assumption - strong] MySQL pool size in `state-service` is 10 connections — confirmed in the state-service spike.
- [assumption - unverified] The exact number of devices that simultaneously reconnect after a State Service restart in production is not documented.
- [assumption - unverified] Whether ALB session affinity routes all device registrations to the same `fmcom-player-api` node (which would cache the screen lookup result in its own session store) is not confirmed.

---

### S-6: State Service Outage Cascades to Elasticsearch Quota Fallback and Playlist Generation Failure

**Summary:** When State Service is down, it cannot allocate Elasticsearch query budgets to registered services. All services fall back to `initial-limit` (1–3 queries per instance in production), which is insufficient for `reach-n-freq`'s playlist generation sweeps. Generation sweeps time out or produce incomplete schedules, leaving screens with stale or empty playlists.

**Trigger:** State Service container replacement, crash, or extended network partition.

**Full flow:**
1. [state-service] State Service becomes unavailable. Its `ElasticsearchLimitCoordinatorService` stops consuming JMS messages from `ELASTICSEARCH_INSTANCE_REGISTERED`, `ELASTICSEARCH_QUOTA_REQUEST`, and `ELASTICSEARCH_PERFORMANCE_FAILURE` topics.
2. [reach-n-freq] `ElasticsearchLimitClient` (from `fm-common` `ThrottlingServiceModule`) cannot obtain quota allocation from State Service. All ES throttle clients fall back to `initial-limit` — confirmed in the spike as `1 query/instance` in dev and `3 queries/instance` in prod.
3. [reach-n-freq] `GenerateDailyPlaylistJob.playlistDailyUpdate()` runs the daily sweep via XXL-Job. `PlaylistGenerationServiceImpl` attempts to generate schedules for all active screens. Each screen generation requires multiple Elasticsearch reads from `ElasticAdCampaignScreenSlot` (SOV rules), `ElasticPlaylistSchedule`, and `ElasticPlayCurrent`.
4. [reach-n-freq] With a quota of 3 concurrent ES queries in production, the generation sweep is severely throttled. `ThrottledElasticsearchTransport` queues requests. The `TIMEOUT_EXECUTION_ORG_MS = 1,800,000` (30-minute) deadline per organization is hit for large organizations with many screens.
5. [reach-n-freq] `waitForCompletion` returns null/empty set silently. Screens within timed-out organizations receive no updated playlist. The existing `ElasticPlaylistSchedule` for those screens remains from the previous day's run.
6. [fmcom-player-api] `GET /player/playlist/current` calls `RnfFeignClient.getPlaylistCurrent(screenId)`, which RNF serves from its stale `ElasticPlaylistSchedule` and `ElasticPlayCurrent` data. The playlist returned may reference content slots that have since been updated, quarantined, or changed.
7. [html5core-player] The player receives a stale playlist. As long as the content referenced still exists in S3 and has valid CloudFront signed URLs, playback continues with old content. If the signed URLs expire (24-hour window per the `Cache-Control` header on HLS streaming), content becomes unplayable.
8. Additionally, RNF's `FeignConfig.connectionCheck()` pings State Service every minute. If State Service is down, RNF's JVM exits with `System.exit(-1)` (see S-1), compounding the failure.

**Repos involved:** `reach-n-freq`, `state-service`, `fmcom-player-api`, `html5core-player`, `fm-common`

**Telemetry coverage:**
- *Exists today:* `state-service` CloudWatch logs show container exit. ES throttle stats are written to `ElasticThrottleStatsModule` index by `fm-common`. JMS messages accumulate in `ELASTICSEARCH_INSTANCE_REGISTERED` queue as unprocessed.
- *Missing:* No alert when ES quota allocation falls back to `initial-limit`. No alert when `ElasticsearchLimitAllocator.getTotalBudget()` uses the fallback value of `48` because the system param is missing (confirmed in state-service spike observation 12). No signal that playlist generation for specific screens was skipped due to timeout (only a log entry via `detectLongRunningTask` — not a metric or alert). The `CriticalIssueService` default implementation in `fm-common` only logs — no PagerDuty or Slack alert is confirmed for production.

**Assumptions:**
- [assumption - strong] State Service is the sole coordinator for ES quota allocation — confirmed explicitly in both the state-service spike and the system map.
- [assumption - strong] `initial-limit` is 3 queries per instance in production — confirmed in the `fmcom-player-api` spike ("initial limit 3 in prod").
- [assumption - strong] RNF will exit via `System.exit(-1)` if State Service is down for longer than 1 minute — confirmed in the RNF spike.
- [assumption - unverified] Whether the ES throttle fallback limit (3 queries) is sufficient for serving `GET /playlist/current/{screenId}` requests to `fmcom-player-api` (read-only, single-item queries) is not benchmarked in any spike.

---

### S-7: JMS Message Loss Prevents Playlist Regeneration After Content Change

**Summary:** When a new piece of content is successfully transcoded but the `PLAYER_CONTENT_TRANSCODED` or `PLAYER_ORGANIZATION_CONTENT_UPDATED` JMS message is lost (broker failure, `BrokerStateClient` client eviction, or in-process broker crash), `fmcom-player-api` never receives the push to invalidate cached playlists and trigger a device-side `CONTENT_CHANGED` WebSocket command. Devices continue playing the old playlist indefinitely.

**Trigger:** State Service ungraceful shutdown (OOM-kill, SIGKILL) drops all in-memory broker messages; or `BrokerStateClient` client offset is evicted after 5 minutes of inactivity (see state-service spike observation 14); or Amazon MQ transient outage during JMS publish.

**Full flow:**
1. [reach-n-freq] `UnifiedVideoPipeline.onComplete()` (for `TriggerMode.MESSAGE`) publishes two JMS messages: `ContentAddMessage` to `API_CONTENT_ADD` and `ContentTranscodedMessage` to `PLAYER_CONTENT_TRANSCODED` (single item) via `MessagingService.send()`.
2. [state-service / Amazon MQ] One of the following failure modes occurs: (a) State Service's in-process broker (`BrokerServiceImpl`) is OOM-killed before delivering the message to any `fmcom-player-api` subscriber; or (b) the `fmcom-player-api` instance's `ClientDetails` in the in-process broker is evicted after 5 minutes of inactivity, resetting its offset to current tail — all messages delivered during the gap are missed; or (c) Amazon MQ is transiently unavailable during the `send()` call and the message is lost (no dead-letter queue is mentioned in any spike).
3. [fmcom-player-api] `MessageHandlers` never receives the `PLAYER_CONTENT_TRANSCODED` event. No cache invalidation is performed. No `CONTENT_CHANGED` WebSocket command is sent to connected devices.
4. [html5core-player] Devices do not receive a `CONTENT_CHANGED` push. The `playbackController` continues playing the existing playlist. The new content is never shown even though it is fully transcoded and available in S3.
5. [fmcom-player-api] Subsequent `GET /player/playlist/current` calls may or may not include the new content depending on whether `rnf`'s pre-computed `ElasticPlaylistSchedule` has been updated by the playlist generation sweep. The next scheduled sweep will include the new content, but the device will not know to re-fetch until the WebSocket command arrives or the `playbackWatchdog` triggers a `resetPlaylist` at 20 seconds.
6. [html5core-player] If no watchdog trigger occurs (playback is proceeding normally), the new content may not appear on screen until the next daily playlist regeneration cycle.

**Repos involved:** `reach-n-freq`, `state-service`, `fmcom-player-api`, `html5core-player`, `fm-common`

**Telemetry coverage:**
- *Exists today:* `BrokerServiceImpl` logs on shutdown. Client eviction after 5 minutes is a documented behavior. Amazon MQ broker metrics are available in AWS CloudWatch (message delivery counts, queue depth).
- *Missing:* No dead-letter queue for `PLAYER_CONTENT_TRANSCODED` or `PLAYER_ORGANIZATION_CONTENT_UPDATED` JMS messages. No correlation ID linking a transcode completion event to a downstream `CONTENT_CHANGED` WebSocket delivery. No alert when a `fmcom-player-api` instance's broker offset is reset (silent miss). No metric on how many `CONTENT_CHANGED` commands were expected vs. delivered per transcode event. The at-most-once delivery guarantee of the in-process broker is not documented in user-facing operational runbooks.

**Assumptions:**
- [assumption - strong] The in-process broker in State Service delivers at-most-once — confirmed in state-service spike observation 6: "If state-service is OOM-killed or receives SIGKILL, all undelivered topic messages are lost."
- [assumption - strong] Client offset eviction after 5 minutes of inactivity causes silent message loss — confirmed in state-service spike observation 14.
- [assumption - unverified] Whether `MessagingService` in `fm-common` uses `JmsMode.MQ` (Amazon MQ) or `JmsMode.STATE` (in-process broker) for `PLAYER_CONTENT_TRANSCODED` in the production environment is not confirmed in the spikes. The routing decision determines which failure mode applies.
- [assumption - unverified] Whether there is a dead-letter queue configured on the Amazon MQ broker for any of the `PLAYER_*` destinations is not confirmed.

---

### S-8: RNF Playlist Generation Timeout Produces No Schedule for a Screen

**Summary:** When `PlaylistGenerationServiceImpl.waitForCompletion()` exceeds its per-screen 5-minute or per-org 30-minute wall-clock deadline, it returns null/empty set silently with no metric emitted and no retry. The screen's `ElasticPlaylistSchedule` is not updated, leaving it with a stale or empty schedule that `PlaylistCurrentService` will continue to serve.

**Trigger:** Large organization with many screens, Elasticsearch throttling (see S-6), or a slow database query in the SOV resolution path causes the generation task to exceed the deadline.

**Full flow:**
1. [reach-n-freq] `GenerateDailyPlaylistJob.playlistDailyUpdate()` runs via XXL-Job. It calls `PlaylistGenerationService.generateOrg(orgId)` for each active organization. Tasks are dispatched to `PlaylistPrioritizedTaskExecutor`.
2. [reach-n-freq] For a specific screen, `PlaylistGeneratorServiceImpl.generate()` begins iterating time periods. It calls `ScreenSlotSovServiceImpl` to resolve SOV rules from Elasticsearch (`ElasticAdCampaignScreenSlot`). Under ES throttling or Elasticsearch latency, this call is slow.
3. [reach-n-freq] `waitForCompletion(task, ..., TIMEOUT_EXECUTION_SCREEN_MS)` blocks for up to 5 minutes (300,000 ms). The deadline passes. `waitForCompletion` returns the default value (null or empty `PlaylistScheduleDto`).
4. [reach-n-freq] A `detectLongRunningTask` log line is emitted at the threshold but no metric, alert, or retry is triggered. The screen's `ElasticPlaylistSchedule` is not updated in Elasticsearch.
5. [fmcom-player-api] When `html5core-player` calls `GET /player/playlist/current`, `fmcom-player-api` calls `RnfFeignClient.getPlaylistCurrent(screenId)`. RNF's `PlaylistCurrentController` reads from `ElasticPlaylistSchedule` and `ElasticPlayCurrent`. It returns the previous day's schedule (if one exists) or an empty playlist (if the screen is new or the previous schedule has expired).
6. [html5core-player] If the schedule is stale (yesterday's content), playback proceeds but may play content that is no longer allocated (wrong SOV distribution). If the schedule is empty (new screen or expired schedule), the player has no items to play and the screen goes blank.
7. The failure repeats on the next daily sweep unless the underlying cause (Elasticsearch latency, SOV resolution complexity) is resolved.

**Repos involved:** `reach-n-freq`, `fmcom-player-api`, `html5core-player`

**Telemetry coverage:**
- *Exists today:* `detectLongRunningTask` logs the screen ID and elapsed time to CloudWatch. Elasticsearch query latency is observable via the `ElasticThrottleStatsModule` index.
- *Missing:* No metric emitted on generation timeout — only a log line. No alert when a screen has not had its `ElasticPlaylistSchedule` updated within the last 24+N hours. No retry mechanism after a timeout: the spike confirms `waitForCompletion` returns the default silently and the sweep moves on. No distinction in `fmcom-player-api` responses between a schedule that is stale vs. one that is empty vs. one that was generated successfully.

**Assumptions:**
- [assumption - strong] `TIMEOUT_EXECUTION_SCREEN_MS = 300,000` (5 min) and `TIMEOUT_EXECUTION_ORG_MS = 1,800,000` (30 min) — confirmed in the RNF spike observation 13.
- [assumption - strong] `waitForCompletion` returns silently with no alert or metric on timeout — confirmed in the RNF spike.
- [assumption - unverified] Whether `PlaylistCurrentService` in `fmcom-player-api` (via `PlaylistCurrentServiceModule` reading `ElasticPlaylistSchedule`) has any minimum-freshness check before serving a schedule is not documented in the spikes.

---

### S-9: EFS Mount Unavailability Halts Transcoding Pipeline

**Summary:** `UnifiedVideoPipeline` uses the shared EFS volume at `/mnt/efs` as a staging filesystem for downloaded source video before FFmpeg processing. If the EFS mount is unavailable, all in-progress and queued transcoding jobs fail, no `API_CONTENT_ADD` messages are published, and no new content can reach device playlists.

**Trigger:** EFS mount detaches or becomes unavailable due to AWS infrastructure issues, ECS task restart with mount failure, or NFS timeout.

**Full flow:**
1. [reach-n-freq] `UnifiedVideoPipeline`'s download stage receives a `MediaProcessingMessage` for a new upload. The download worker writes the S3-sourced video to `${transcoding.temp-storage-path}` on the EFS mount.
2. [reach-n-freq] The EFS mount is unavailable. The file write fails with an I/O exception (likely `java.io.IOException` propagating from the OS-level NFS layer).
3. [reach-n-freq] The exception propagates up through the download stage. The pipeline marks the content item as `FAILED` in MySQL. No `ContentAddMessage` is published to `API_CONTENT_ADD`.
4. [reach-n-freq] All subsequent JMS messages queued in `RNF_MEDIA_PROCESSING` encounter the same failure. The `downloadedQueue` (bounded `LinkedBlockingQueue` with `pipelineDownloadAheadLimit = 10` items) fills up. Back-pressure prevents new download submissions, but queued messages accumulate on the JMS broker.
5. [fmcom-api] Content uploaded by providers accumulates with `transcodingStatus: PENDING` or `FAILED`. No content advances to a playable state for any screen.
6. [reach-n-freq] The `executeTranscoding` XXL-Job sweep also fails for the same reason. All retry attempts fail until EFS is restored.
7. [html5core-player] Screens already playing previously-transcoded content continue normally (their S3 artifacts are unaffected). However, any screen that depended on newly-uploaded content to fill a sparse playlist, or any new screen with no historical content, will have an empty or stale playlist.

**Repos involved:** `reach-n-freq`, `fmcom-api`, `fmcom-player-api`, `html5core-player`

**Telemetry coverage:**
- *Exists today:* FFmpeg / I/O exception stack traces are logged to CloudWatch from RNF. `transcodingStatus: FAILED` accumulates in MySQL. EFS CloudWatch metrics (throughput, IOPS, mount target health) are available via AWS.
- *Missing:* No code-level error handling for filesystem unavailability beyond exception propagation in RNF — confirmed in the RNF spike observation 5. No alert when the EFS IOPS or throughput metric drops to zero for an extended period. No alert on the ratio of `FAILED` vs `COMPLETE` transcode events. No signal from `fmcom-api` to providers that their uploaded content failed transcoding.

**Assumptions:**
- [assumption - strong] EFS is required for transcoding — confirmed in the RNF spike: "The critical dependency is the shared EFS mount at `/mnt/efs`: if EFS is unavailable, the pipeline cannot stage files."
- [assumption - unverified] Whether the EFS mount is configured with retry/reconnect behavior at the ECS task definition level is not visible from the spike (it is an infrastructure concern, not a code concern).

---

### S-10: Daily Playlist Generation Sweep Silently Skips Screens Under Elasticsearch Throttle

**Summary:** When `reach-n-freq`'s daily generation sweep requests a quota increase for the heavy job via `ElasticsearchLimitClient.requestQuotaIncreaseForHeavyJob()` but the State Service does not respond (or the increased quota is insufficient), individual screen generation tasks queue behind the throttle and may time out silently, producing stale or empty schedules for affected screens.

**Trigger:** Heavy daily sweep concurrent with other Elasticsearch-intensive operations from `fmcom-api` or `fmcom-player-api`, or State Service degradation limiting available quota.

**Full flow:**
1. [reach-n-freq] `GenerateDailyPlaylistJob.playlistDailyUpdate()` calls `ElasticsearchLimitClient.requestQuotaIncreaseForHeavyJob()` to signal the start of a heavy sweep. The request is published as a JMS message to `ELASTICSEARCH_QUOTA_REQUEST`.
2. [state-service] `ElasticsearchLimitCoordinatorService` receives the request and recalculates budget allocation. If the cluster is under load (other services also at peak), the increased quota may be modest.
3. [reach-n-freq] `PlaylistGenerationServiceImpl` runs `ConcurrentExecutor.execute(..., MAX_ALLOWED_PARALLEL_GENERATIONS = 6)` — limited to 6 parallel org-level generation tasks. Each task requires multiple ES reads from `ElasticAdCampaignScreenSlot` and `ElasticPlaylistSchedule`.
4. [reach-n-freq] The `ThrottledElasticsearchTransport` queues ES operations exceeding the allocated budget. Queued operations delay generation tasks. Per-screen 5-minute timeouts expire silently (see S-8).
5. [reach-n-freq] After the sweep, `releaseQuotaFromHeavyJob()` is called to restore the budget. However, if an uncaught exception is thrown before the `finally` block (open question identified in the RNF spike, question 9), the quota remains elevated indefinitely, starving other services of their allocated share.
6. [fmcom-player-api] Screens with timed-out generation tasks are served stale or empty schedules (see S-8 flow steps 5–7).

**Repos involved:** `reach-n-freq`, `state-service`, `fmcom-player-api`, `html5core-player`, `fm-common`

**Telemetry coverage:**
- *Exists today:* ES throttle statistics are written to the `ElasticThrottleStatsModule` index. JMS `ELASTICSEARCH_QUOTA_REQUEST` messages are observable on the broker.
- *Missing:* No alert if `requestQuotaIncreaseForHeavyJob` fails silently (no response from State Service). No alert if the quota remains elevated after a sweep due to exception before `finally`. No metric distinguishing screens skipped by timeout from screens successfully generated. No per-screen "last successfully generated" timestamp with a freshness alert.

**Assumptions:**
- [assumption - strong] `MAX_ALLOWED_PARALLEL_GENERATIONS = 6` is enforced only in the XXL-Job daily sweep — confirmed in the RNF spike observation 4. JMS-triggered `generateOrg` calls share the same pool without a cap.
- [assumption - unverified] Whether `releaseQuotaFromHeavyJob()` is called in a `finally` block (safe) or inline (unsafe under exception) is noted as an open question in the RNF spike and not resolved.

---

### S-11: `fm-common` Version Skew Causes Silent JMS Payload Deserialization Failure

**Summary:** State Service runs `fm-common` 8.7.8 while `reach-n-freq` (8.9.1) and `fmcom-api` (8.9.0) use the 8.9.x series. The 8.9.x line introduced typed `JmsDestination<T>` with new DTO fields. State Service's deserializer silently drops unknown fields, causing it to misprocess ES-limit coordination JMS messages from the newer services, potentially corrupting ES quota allocations across the fleet.

**Trigger:** Any 8.9.x service publishes a JMS message to an ES-limit coordination topic with a field that was added in 8.9.x and does not exist in the 8.7.8 DTO definition.

**Full flow:**
1. [reach-n-freq or fmcom-player-api] An 8.9.x service publishes a message (e.g., `ELASTICSEARCH_INSTANCE_REGISTERED`, `ELASTICSEARCH_QUOTA_REQUEST`, or `ELASTICSEARCH_PERFORMANCE_FAILURE`) using the 8.9.x payload DTO, which may include fields not present in `fm-common` 8.7.8.
2. [state-service] `ElasticsearchLimitCoordinatorService` (running on `fm-common` 8.7.8) receives the JMS message. Jackson deserializes it into the 8.7.8 version of the DTO. Fields present in the 8.9.x DTO but absent in the 8.7.8 DTO are silently ignored.
3. [state-service] `ElasticsearchLimitAllocator` processes the incomplete DTO. If the missing fields were quota-relevant (e.g., a new service-weight field or a backlog indicator), the budget calculation is incorrect. `ElasticsearchLimitsAllocated` is broadcast with wrong values.
4. [reach-n-freq, fmcom-api, fmcom-player-api] All services receive and apply the incorrect quota allocation. Services with understated quotas throttle their ES writes more than necessary. Services with overstated quotas may overload Elasticsearch.
5. If ES is overloaded, write errors accumulate in `MySqlElasticsearchSaveFailure`. Playlist schedules and telemetry data are not written. `PlaylistCurrentService` serves from a stale `ElasticPlaylistSchedule`. Eventually screens serve stale content.

**Repos involved:** `state-service`, `reach-n-freq`, `fmcom-api`, `fmcom-player-api`, `fm-common`

**Telemetry coverage:**
- *Exists today:* Jackson deserialization warnings (if `DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES` is enabled) would appear in CloudWatch. ES throttle stats are written to `ElasticThrottleStatsModule`. ES write failures accumulate in `MySqlElasticsearchSaveFailure`.
- *Missing:* No cross-service `fm-common` version compatibility check at JVM startup or deployment time. No CHANGELOG for `fm-common` to identify which DTOs changed between 8.7.8 and 8.9.x. No alert on deserialization warnings in State Service. No integration test across services running different `fm-common` versions — confirmed absent in the system map.

**Assumptions:**
- [assumption - strong] Four different `fm-common` versions are in production — confirmed in the system map: `fmcom-api` 8.9.0, `fmcom-player-api` 8.8.9, `rnf` 8.9.1, `state` 8.7.8.
- [assumption - strong] The typed `JmsDestination<T>` system and new DTO fields were introduced in the 8.9.x line — confirmed in the `fm-common` spike version skew analysis.
- [assumption - unverified] Whether Jackson is configured with `FAIL_ON_UNKNOWN_PROPERTIES = false` (silent drop) or `true` (exception) in State Service is not confirmed in the state-service spike. Silent drop is the Jackson default and is the assumed behavior.
- [assumption - unverified] Whether any specific DTO fields relevant to ES quota calculation changed between 8.7.8 and 8.9.x is not determinable without a changelog or diff.

---

### S-12: Device Re-registration Loop After Watchdog Reload

**Summary:** After `window.location.reload()` in `html5core-player`, the app re-enters the activation polling loop. If State Service is slow or unavailable, `fmcom-player-api`'s `RegistrationServiceImpl` cannot complete registration, and the device displays the pairing QR code (activation screen) instead of content — visible to patients in the waiting room.

**Trigger:** Any `window.location.reload()` call in the player (from `playbackWatchdog` at 30 s, from `autoUpdate` on a new build hash, or from the WebSocket `DISCONNECT` command) combined with State Service latency or unavailability.

**Full flow:**
1. [html5core-player] `window.location.reload()` is called (watchdog at 30 s, new build hash in `autoUpdate`, or WebSocket DISCONNECT).
2. [html5core-player] `checkActivation.ts` begins polling `POST /player/registerDevice` every 3 seconds. The AES-CBC session key stored in Pinia memory is lost.
3. [fmcom-player-api] `RegistrationServiceImpl.registerDevice()` calls `ScreenStateClient.getByMac(mac)` (Feign → State Service) to look up the screen by MAC address.
4. [state-service] If State Service is under load (cold cache on restart, `SyncOpService` global lock contention, deployment write storm), the lookup is slow or times out.
5. [fmcom-player-api] The `ScreenStateClient` Feign call has no circuit-breaker configured — confirmed in the `fm-common` spike observation 10. The call blocks until the Feign default connect/read timeout.
6. [fmcom-player-api] `registerDevice` returns an error to `html5core-player`.
7. [html5core-player] `checkActivation.ts` retries after 3 seconds. The device shows the activation screen (pairing QR code). Each retry cycle is 3 seconds; with a 15-second JPA query timeout in State Service and 10-connection pool, the effective retry-to-success latency can be tens of seconds to minutes.
8. [html5core-player] During the activation polling period, the screen displays the QR code — which patients see instead of waiting-room content.

**Repos involved:** `html5core-player`, `fmcom-player-api`, `state-service`, `fm-common`

**Telemetry coverage:**
- *Exists today:* WebSocket disconnection events are logged. Activation polling calls are loggable at `fmcom-player-api`. State Service MySQL timeout exceptions appear in CloudWatch.
- *Missing:* No circuit breaker on `ScreenStateClient` — confirmed in the `fm-common` spike. No metric on registration failure rate per device. No alert when a device has been in activation polling for longer than N minutes. `checkActivation.ts` has no telemetry for its retry cycles — it only reports success (session key received).

**Assumptions:**
- [assumption - strong] The AES-CBC session key is stored only in Pinia memory and lost on reload — confirmed in both the `html5core-player` spike and the `fmcom-player-api` spike.
- [assumption - strong] `ScreenStateClient` has no circuit breaker — confirmed in the `fm-common` spike observation 10: "There is no circuit-breaker configuration visible in `StateClientModule`."
- [assumption - unverified] The Feign connect/read timeout configured for `ScreenStateClient` in `fmcom-player-api` is not documented in the spike.

---

### S-13: Bad Content Manifest Triggers Quarantine via `ContentManifestIncompatibleDetectionRule`

**Summary:** A content item whose HLS master manifest is incompatible with multiple device hardware types (codec mismatch, container error, or malformed segment list) triggers `ContentManifestIncompatibleDetectionRule` in `fmcom-player-api`, which places a quarantine on that content across all affected screens. If a screen's entire playlist consists of such items, it goes blank.

**Trigger:** A transcoded content item with a structural manifest defect that multiple device types (tracked by `BAD_MANIFEST_HW_TYPES_PREFIX` Redis ZSET) fail to decode.

**Full flow:**
1. [html5core-player] `VideoPlayer.vue` fails to load the HLS master manifest for a content item. The player emits a codec/manifest error telemetry event via WebSocket.
2. [fmcom-player-api] `TelemetryEventAnalyzerServiceImpl` dispatches the event to `ContentManifestIncompatibleDetectionRule`.
3. [fmcom-player-api] The rule writes the `screenId` to the Redis ZSET at `content:bad_manifest:screens:{contentId}` (score = epoch ms, 7-day sliding window) and the `hardwareType` to `content:bad_manifest:hwtypes:{contentId}`. Both keys are defined in `TelemetryRedisKeys` from `fm-common`.
4. [fmcom-player-api] When the ZSET reaches the multi-vendor threshold (evidence from multiple hardware types required before quarantine), the rule calls `ContentQuarantineService.place(...)` from `fm-common`. A `MySqlContentQuarantine` row is inserted with type `ALL` (all screens). A Redis marker is set at `content:bad_manifest:quarantined:{contentId}` with a 30-day TTL to suppress duplicate quarantine actions.
5. [fmcom-player-api] `ContentQuarantineService.place()` publishes `API_CONTENT_QUARANTINE` to JMS.
6. [fmcom-api] `ContentQuarantineHandlers` receives `API_CONTENT_QUARANTINE` and removes the content from screen assignments.
7. [reach-n-freq] The next playlist generation sweep excludes the quarantined content from all screens. Screens that had this content as a significant portion of their playlist now have fewer eligible items.
8. [html5core-player] Screens receive updated playlists (via `CONTENT_CHANGED` WebSocket push or on next `resetPlaylist`). If the quarantined content was the only content for a screen's organization, the playlist is empty and the screen goes blank.

**Repos involved:** `html5core-player`, `fmcom-player-api`, `fmcom-api`, `reach-n-freq`, `fm-common`

**Telemetry coverage:**
- *Exists today:* `MITIGATION` telemetry events for quarantine actions are written to Elasticsearch. `MySqlContentQuarantine` rows are queryable. `BAD_MANIFEST_SCREENS_PREFIX` and `BAD_MANIFEST_HW_TYPES_PREFIX` Redis ZSETs are observable.
- *Missing:* No user-facing notification in VPM when content is quarantined platform-wide — confirmed as a product gap in the roundtable. No automatic re-transcode trigger when `ALL` type quarantine is placed. No alert when a specific organization's playlist shrinks below a minimum item count. The 30-day TTL on the dedup marker means if a re-transcode fixes the manifest, the quarantine will not be automatically lifted — it requires manual operator action via `QuarantineRestoreServiceImpl`.

**Assumptions:**
- [assumption - strong] `BAD_MANIFEST_SCREENS_PREFIX` and `BAD_MANIFEST_HW_TYPES_PREFIX` Redis keys are confirmed in `TelemetryRedisKeys` in `fm-common`.
- [assumption - strong] The 30-day TTL on `BAD_MANIFEST_QUARANTINED_MARKER_PREFIX` is confirmed in the `fm-common` spike.
- [assumption - unverified] The exact multi-vendor threshold (number of distinct hardware types required before quarantine triggers) is a configuration value not documented in the spikes.

---

### S-14: Redis Escalation State Permanent Without TTL — Content Never Recovers After Partial Failure

**Summary:** The `PlaybackEscalationStage` state machine stores per-(screen, content) escalation state in Redis at `screen:content:escalation:{screenId}:{contentId}` with no TTL. A content item that has degraded due to a transient network issue or device-specific condition will remain at the degraded stage indefinitely, even after the underlying issue is resolved — unless a manual re-transcode or specific API call clears the state.

**Trigger:** A transient network degradation on a specific screen causes decode failures that advance the escalation ladder. The network recovers, but the escalation stage is not reset.

**Full flow:**
1. [html5core-player] A transient network issue on a specific screen causes HLS segment failures for a content item. The player reports decode failures via telemetry.
2. [fmcom-player-api] `ContentPlaybackEscalationRule` advances the `PlaybackEscalationStage` for `(screenId, contentId)` from `HLS_FULL` to `HLS_720` (or further). The new stage is written to Redis with no TTL.
3. [html5core-player] The 30-minute `settle-grace-minutes` window begins. During this window, new failures on the current variant are not counted — the rule is effectively blind to real failures for 30 minutes after each advance.
4. The network recovers. The content would play fine at `HLS_FULL`, but the escalation state is permanently `HLS_720` (or lower). `ContentUtils.updateContentUrls()` reads the Redis state on every playlist request and serves the downgraded variant.
5. [html5core-player] The device continues receiving a lower-quality variant of the content indefinitely. If the escalation has reached `SRC_540` or `QUARANTINE`, the content may be visually degraded or entirely absent from the playlist, causing partial or complete blank screen for that content item.
6. Recovery requires: (a) a content re-transcode event that triggers `QuarantineRestoreServiceImpl` to clear the Redis state; or (b) a device firmware upgrade that resets the escalation state per the fmcom-player-api spike observation 5; or (c) manual operator intervention via the diagnostics dashboard.

**Repos involved:** `fmcom-player-api`, `html5core-player`, `fm-common`

**Telemetry coverage:**
- *Exists today:* Escalation stage transitions are written as `MITIGATION` telemetry events to Elasticsearch. The `screen:content:escalation:index:{screenId}` Redis reverse-index tracks which content IDs have active escalation per screen.
- *Missing:* No alert when a screen has content items at `SRC_540` or `QUARANTINE` for longer than N days without a re-transcode. No automatic escalation revert on network recovery (the 30-minute settle window is a blind period, not a recovery mechanism). No metric on the age distribution of escalation states across the fleet. No operator dashboard showing which screens have the most escalated content items.

**Assumptions:**
- [assumption - strong] Escalation state has no TTL in Redis — confirmed in the `fmcom-player-api` spike: "stored permanently in Redis (no TTL)."
- [assumption - strong] The 30-minute `settle-grace-minutes` window is a blind period after each advance — confirmed in the `fmcom-player-api` spike observation 5.
- [assumption - unverified] Whether a firmware upgrade unconditionally clears all escalation state for a device or only clears it under specific conditions is not documented.

---

### S-15: Elasticsearch Write Failure Leaves Playlist Schedule Stale

**Summary:** When Elasticsearch writes for `ElasticPlaylistSchedule` fail (throttle budget exceeded, ES cluster disk pressure, or network partition), `PlaylistCurrentService` serves the last successfully written schedule. If enough time passes, that schedule refers to content slots that no longer reflect the current SOV allocation, and eventually the schedule expires or references content that has been removed.

**Trigger:** Elasticsearch cluster degradation (disk full, node failure, or 429/503 from throttle), compounded by State Service throttle coordinator unavailability (see S-6).

**Full flow:**
1. [reach-n-freq] `PlaylistGenerationServiceImpl` completes generation for a screen and calls the Elasticsearch repository to write the new `ElasticPlaylistSchedule` document.
2. [reach-n-freq] The Elasticsearch write fails: 429 (throttle), 503 (node unavailable), or network timeout. The failure is recorded in `MySqlElasticsearchSaveFailure` via `fm-common`'s `ElasticSaveFailureModule`.
3. [reach-n-freq] The `ElasticOptimizationJob` XXL-Job handler may attempt to retry `ElasticsearchSaveFailure` records, but retry timing is not documented in the spikes.
4. [fmcom-player-api] `PlaylistCurrentService.getCurrentPlaylist(screenId, from, length)` reads from `ElasticPlaylistSchedule`. It returns the last successfully written schedule — which may be hours or days old.
5. [html5core-player] The player receives and plays the stale schedule. Content that has since been quarantined, removed, or changed SOV allocation plays with incorrect weighting. If the stale schedule references S3 objects that have been deleted (orphan cleanup), CloudFront returns 403/404 and the content fails to load.
6. [html5core-player] Failed content loads produce decode errors. The escalation ladder advances (see S-2). If enough content in the stale schedule is unplayable, the screen goes blank.

**Repos involved:** `reach-n-freq`, `fmcom-player-api`, `html5core-player`, `fm-common`

**Telemetry coverage:**
- *Exists today:* `MySqlElasticsearchSaveFailure` records accumulate and are queryable. `ELASTICSEARCH_PERFORMANCE_FAILURE` JMS messages are published when ES returns 429/503 — State Service receives them and may decrease the budget.
- *Missing:* No alert when `ElasticPlaylistSchedule` for a specific screen has not been updated within the last 25+ hours. No metric on the age of the most recent `ElasticPlaylistSchedule` entry per screen. No automatic alert from `CriticalIssueService` for ES write failures — the default implementation only logs.

**Assumptions:**
- [assumption - strong] `MySqlElasticsearchSaveFailure` is the failure record mechanism — confirmed in `fm-common` as `ElasticSaveFailureModule`.
- [assumption - strong] `CriticalIssueService` default implementation only logs — confirmed in the `fm-common` spike. No PagerDuty or Slack alert is confirmed for production.
- [assumption - unverified] The retry behavior of `ElasticOptimizationJob` on `MySqlElasticsearchSaveFailure` records is not detailed in the RNF spike.

---

### S-16: XXL-Job Admin Outage Stops Daily Playlist Generation Sweep

**Summary:** All three backend services (`fmcom-api`, `fmcom-player-api`, `reach-n-freq`) register their scheduled jobs with a single shared XXL-Job admin server. If the XXL-Job admin is unavailable, the daily playlist generation sweep (`playlistDailyUpdate`) does not run. After 24+ hours without a fresh sweep, `ElasticPlaylistSchedule` documents expire or become stale and devices play incorrect or empty playlists.

**Trigger:** XXL-Job admin server (`https://jobs.prod.vrtly.app/job-admin/`) crashes, is scaled to zero, or becomes network-unreachable.

**Full flow:**
1. [xxl-job-admin] The shared XXL-Job admin server becomes unavailable.
2. [reach-n-freq] `XxlJobConfig` executor registration (port 9996) cannot heartbeat to the admin. XXL-Job executors operate independently of the admin for already-running jobs, but scheduled job dispatch originates from the admin. The admin does not trigger the next `playlistDailyUpdate` execution.
3. [reach-n-freq] `GenerateDailyPlaylistJob.playlistDailyUpdate()` does not run. `ElasticPlaylistSchedule` documents for all screens are not refreshed.
4. [fmcom-player-api] `PlaylistCurrentService` continues serving `ElasticPlaylistSchedule` data. As the schedule ages past 24 hours, the time-indexed slots it contains are for past datetimes. `PlaylistCurrentService` uses `LOOKUP_MINUTES_BEFORE_REQUEST = 5` and `DEFAULT_REQUEST_SIZE = 30` to find upcoming slots. With an expired schedule, no upcoming slots are found.
5. [html5core-player] `GET /player/playlist/current` returns an empty or near-empty playlist. The player has nothing to advance to. `playbackWatchdog` fires: 10 s → pressNext (no next item), 20 s → resetPlaylist (empty again), 30 s → `window.location.reload()`.
6. [html5core-player] After reload, re-registration succeeds, but the playlist fetch still returns empty. The reload loop from S-3 begins.

**Repos involved:** `reach-n-freq`, `fmcom-player-api`, `html5core-player`

**Telemetry coverage:**
- *Exists today:* XXL-Job admin exposes its own health endpoints. CloudWatch alarms can be configured on the XXL-Job ECS service. RNF executor registration failures would appear in CloudWatch logs.
- *Missing:* No alert documented when XXL-Job executor registration fails. No fallback scheduling mechanism — the RNF spike confirms there is no `@Scheduled` Spring annotation fallback, only XXL-Job. No per-screen "last playlist generation timestamp" alert. The system map identifies this as a gap: "XXL-Job admin is a single point of failure for all scheduled tasks across three services."

**Assumptions:**
- [assumption - strong] XXL-Job admin is a single point of failure — confirmed in the `fmcom-api` spike observation 12 and the system map.
- [assumption - unverified] Whether `playlistDailyUpdate` has any fallback execution path (e.g., triggered by a JMS message from `fmcom-api` via `RNF_GENERATE`) that would compensate for a missed XXL-Job trigger is not confirmed in the spikes. `RNF_GENERATE` JMS messages do trigger playlist generation in `MessageHandlers`, which could partially compensate for a missed daily sweep if `fmcom-api` sends them — but the trigger conditions are not documented.

---

### S-17: In-Process Broker in State Service Loses Messages on Ungraceful Shutdown

**Summary:** State Service implements its JMS broker entirely in-memory. If State Service receives SIGKILL or is OOM-killed, all undelivered `PLAYER_*` topic messages in the in-process broker are lost. Devices connected to `fmcom-player-api` instances that route through `BrokerStateClient` miss content-change and playlist-reload commands, leaving them playing stale content.

**Trigger:** State Service OOM-kill (heap exhaustion from unbounded cache growth — see state-service spike observation 2), or SIGKILL from ECS during a forced task replacement.

**Full flow:**
1. [state-service] State Service is OOM-killed. `BrokerServiceImpl.stop()` is not called. The Elasticsearch fallback snapshot (which persists broker state to `ElasticBrokerMessages`) does not run.
2. [state-service] All in-memory queues and topic state in `BrokerServiceImpl` are lost. Any `PLAYER_CONTENT_TRANSCODED`, `PLAYER_ORGANIZATION_CONTENT_UPDATED`, or `PLAYER_SCREEN_CONTENT_UPDATED` messages that had been published but not yet consumed by `fmcom-player-api` instances are permanently lost.
3. [fmcom-player-api] Instances that use `BrokerStateClient` (`JmsMode.STATE`) for these topics never receive the notifications. No `CONTENT_CHANGED` WebSocket command is pushed to connected devices.
4. [html5core-player] Devices continue playing the previous playlist with no knowledge that new content is available. New content from a recent transcode completion does not appear on screen until the next `resetPlaylist` cycle or the next daily generation sweep.
5. [state-service] After restart, `BrokerServiceImpl.start()` reads from `ElasticBrokerMessages` to restore broker state. Since the snapshot was not written (OOM-kill, not graceful), the ES index has the previous clean-shutdown state. Any messages published after that clean shutdown are lost.
6. [state-service] New `fmcom-player-api` instances reconnect to the broker with fresh offsets. They miss all messages delivered between the last graceful shutdown snapshot and the OOM-kill.

**Repos involved:** `state-service`, `fmcom-player-api`, `html5core-player`, `fm-common`

**Telemetry coverage:**
- *Exists today:* CloudWatch OOM-kill events on the ECS task are visible. `ElasticBrokerMessages` index can be inspected for the last snapshot content. ECS task stop reason `OutOfMemoryError` is distinguishable in CloudWatch.
- *Missing:* No alert when the in-memory screen cache in State Service exceeds a heap threshold (no size bound exists — confirmed in state-service spike observation 2). No metric on undelivered broker messages at State Service shutdown. No end-to-end correlation between a transcode completion event and a confirmed `CONTENT_CHANGED` WebSocket delivery on a device. The at-most-once delivery guarantee is noted in state-service spike observation 6 but is not documented in an operator runbook.

**Assumptions:**
- [assumption - strong] The Elasticsearch fallback snapshot runs only on clean `stop()` — confirmed in state-service spike observation 6: "it does not run on a crash."
- [assumption - strong] The `ConcurrentHashMap` screen cache has no size bound and no eviction policy — confirmed in state-service spike observation 2. This is the primary OOM risk.
- [assumption - unverified] Whether `JmsMode.STATE` (in-process broker) is the active routing mode for `PLAYER_*` messages from `reach-n-freq` and `fmcom-api` in production is not confirmed. If `JmsMode.MQ` (Amazon MQ) is used for these messages, the broker-loss scenario does not apply to them.

---

### S-18: Deployment Write Storm Saturates `SyncOpService` Global Lock in State Service

**Summary:** During rolling deployments, State Service sets a JVM-wide `deployment` flag that forces synchronous MySQL writes for every screen update for a 5-minute window. Combined with Salesforce notification JMS publishes on every screen persist and a single `synchronized(locks)` monitor for all screen IDs, a deployment causes a write storm that serializes all screen operations and can cause `ScreenStateClient` calls from `fmcom-player-api` to time out during device registration or playlist delivery.

**Trigger:** Any rolling deployment of State Service that triggers `DeploymentServiceImpl.started()`.

**Full flow:**
1. [state-service] `DeploymentServiceImpl.started()` sets the static `AtomicBoolean deployment` flag to `true`. All subsequent `ScreenStateService.update()` calls execute `persistenceService.save()` synchronously instead of deferring to the 1-minute flush.
2. [state-service] Simultaneously, `SalesforceNotificationService` is called from `ScreenPersistenceServiceImpl.save()` after every screen persist, publishing three JMS messages (`RNF_SALESFORCE_ORGANIZATION_UPDATED`, `RNF_SALESFORCE_SCREEN_UPDATED`, `RNF_SALESFORCE_USER_UPDATED`) for every screen write.
3. [state-service] `SyncOpService.execute(screenId, ...)` acquires the per-key lock via `synchronized(locks)` — a single global monitor for all screen IDs. A long-running `persistenceService.save()` for one screen blocks all other screen ID lock acquisitions for its duration.
4. [fmcom-player-api] The player fleet is running normally. Devices send `lastDisplay` heartbeat updates, registration calls, and playlist fetches — all of which call `ScreenStateClient` methods that route through `ScreenController` in State Service.
5. [state-service] Under the global `synchronized(locks)` contention, `ScreenController` endpoints queue behind the serialized writes. Response times increase. The JPA query timeout of 15 seconds begins to fire for queued operations.
6. [fmcom-player-api] `ScreenStateClient` Feign calls begin timing out (no circuit breaker). `RegistrationServiceImpl.registerDevice()` fails. Devices fail registration and display the activation/pairing screen (see S-12).
7. [fmcom-player-api] `GET /player/playlist/current` may also be impacted if any playlist delivery path calls `ScreenStateClient` for screen config. Errors cascade to `html5core-player` (see S-3 flow).
8. [state-service] After 5 minutes (`DELAY_BEFORE_DEPLOYMENT_CANCEL_MIN = 5`), the deployment flag is reset and deferred flushing resumes. The write storm subsides.

**Repos involved:** `state-service`, `fmcom-player-api`, `html5core-player`, `fm-common`

**Telemetry coverage:**
- *Exists today:* MySQL slow query log captures lock contention. CloudWatch ECS deployment events mark the start of each rolling deployment. State Service Actuator metrics expose thread pool saturation.
- *Missing:* No alert on `ScreenStateClient` error rate during deployment windows. No metric on `SyncOpService` lock wait time. No damping or batching on Salesforce JMS publish during deployment windows — confirmed in system map NR1. No per-screen registration failure rate correlated to State Service deployment events.

**Assumptions:**
- [assumption - strong] `SyncOpService` uses a single `synchronized(locks)` monitor for all screen IDs — confirmed in state-service spike observation 3.
- [assumption - strong] `SalesforceNotificationService` is called on every `ScreenPersistenceServiceImpl.save()` — confirmed in state-service spike external integrations table.
- [assumption - strong] The deployment flag forces synchronous writes for 5 minutes — confirmed in state-service spike observation 11.
- [assumption - unverified] The exact number of screen writes that flow through State Service during a production deployment window is not documented.

---

## Cross-Cutting Observations

The following observations apply to multiple scenarios and represent systemic gaps rather than single-scenario risks.

**No local content cache on devices.** Every scenario above is amplified by the absence of a local playlist or content cache in `html5core-player`. Any backend disruption lasting more than 30 seconds triggers the watchdog reload loop. A local cache (IndexedDB, localStorage playlist store) would allow devices to continue playing last-known-good content during transient outages. This is confirmed absent in the spikes.

**No circuit breakers on any cross-service Feign calls.** `RnfFeignClient` in `fmcom-player-api`, `ScreenStateClient` in `fm-common`, and `InstanceStateClient` in RNF all lack circuit breakers. A single upstream service failure propagates synchronously to all callers with no fallback behavior.

**`CriticalIssueService` default implementation only logs.** No production alert integration (Slack, PagerDuty, OpsGenie) is confirmed for any of the critical conditions documented in these scenarios. Operators must actively monitor CloudWatch logs to detect most failure modes.

**State Service is a single point of failure for multiple independent platform capabilities** — screen state authority, auth token management, Elasticsearch quota governance, and the in-process JMS broker. Every scenario that involves State Service unavailability cascades into multiple simultaneous failure modes across all other services.

**`serverLogger.ts` is dead code.** The `html5core-player` server-side issue reporting mechanism (`sendIssue()`) has an unconditional early `return`, confirmed in the spike. No client-side error reporting reaches the backend except through the standard telemetry WebSocket path.
