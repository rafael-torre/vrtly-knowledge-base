---
title: "Content Update Flow — html5core (end-to-end)"
owner: "Tech Lead"
status: in_progress
last_updated: 2026-06-12
relates_to:
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-api.md
  - layers/layer-3-architecture/intermediate/tech-spike-rnf.md
  - layers/layer-3-architecture/intermediate/tech-spike-state-service.md
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-player-api.md
  - layers/layer-3-architecture/intermediate/tech-spike-html5core-player.md
  - layers/layer-3-architecture/intermediate/investigation/playlist-flow-investigation.md
---

# Content Update Flow — html5core (end-to-end)

Neutral end-to-end map of what happens when an admin modifies content in VAM/VPM and that change reaches an html5core device. Scope: html5core fleet. Roku and Android are out of scope until their repos are available.

This document does not analyze logging coverage. It describes what each component does and how they connect, including the data that travels between them and the conditional paths that matter most.

---

## Overview

There are two distinct triggers for a content update reaching a device:

- **Flow A — New content upload**: admin uploads new media → fmcom-api dispatches transcoding to RNF → RNF transcodes and publishes completion → player-api notifies devices.
- **Flow B — Playlist modification**: admin rearranges or removes existing (already-transcoded) content in a playlist → fmcom-api dispatches playlist regeneration to RNF → RNF regenerates schedule and publishes update → player-api notifies devices.

Both flows share the same tail (N4 → N5 → N6). The path to N4 is what differs.

---

## Flow Map

```
                        ┌──────────────────────────────────────────────────────────┐
                        │  Flow A                        Flow B                    │
                        │                                                          │
N0  Admin action        │  Upload new media         Modify playlist               │
         │              │  (VAM/VPM CMS)            (VAM/VPM CMS)                 │
         ▼              └──────────────────────────────────────────────────────────┘
N1  fmcom-api           Content row created         Playlist updated in MySQL
         │              S3 upload (raw file)        ContentUpdateNotificationService
         │              Throttle check              Throttle check
         ▼ (JMS, after DB commit)
         │              RNF_MEDIA_PROCESSING        RNF_GENERATE / PLAYER_SCREEN_CONTENT_PENDING
N2  RNF (transcode)     Download → FFmpeg → S3      (skipped)
         │              PLAYER_CONTENT_TRANSCODED ──────────────────────┐
         │              API_CONTENT_ADD (→ N1)                          │
         ▼ (JMS)                                                         │
N3  RNF (playlist gen)  Triggered by API_CONTENT_ADD or RNF_GENERATE   │
         │              Reads SOV rules (Elasticsearch)                 │
         │              Writes ElasticPlaylistSchedule                  │
         │              PLAYER_ORGANIZATION_CONTENT_UPDATED ────────────┤
         │              PLAYER_SCREEN_CONTENT_UPDATED ──────────────────┤
         ▼ (JMS / Amazon MQ)                                            │
N4  Message bus         Amazon MQ PLAYER_* topics ◄─────────────────────┘
         │              (State Service in-process broker — see note)
         ▼ (JMS subscription)
N5  fmcom-player-api    MessageHandlers receives PLAYER_* event
         │              PLAYER_ORGANIZATION_CONTENT_UPDATED →
         │                broadcastOrganizationMessage → ALL enabled screens in org
         │              Pushes CONTENT_CHANGED via WebSocket to each device
         ▼ (WebSocket)
N6  html5core player    Receives CONTENT_CHANGED
         │              Guard: isConsults? → skip
         │              Guard: __currentPlaylistLoading? → skip
         │              setPlaylist([]) ← screen blanks immediately
         │              Determine mode: SOV or Combined
         │              Fetch new playlist (Path A or Path B)
         │              _parsePlaylist → setPlaylist(newPlaylist) → setContentIndex(0)
         ▼
N7  Playback            videoTag.load() → videoTag.play()
         │              Watchdog monitors every 500ms
         │              5s→playerStuck, 10s→pressNext, 20s→resetPlaylist, 30s→page reload
```

---

## Node-by-Node Detail

### N0 — Admin action (VAM/VPM)

The admin uses the Vrtly CMS web app (`fmcom-vrtly-fe-monorepo`, out of scope) to upload new media or modify a playlist. The action issues an HTTP request to fmcom-api's CMS REST endpoints (`controller/cms`).

**Entry points (fmcom-api controllers):**
- Add/update/delete content: `ModernContentController` → `POST/PUT/DELETE /cms/content`
- Add content to screen: `ScreenContentController` → `POST /cms/screenContent/addContentToScreen`
- Create/update custom playlist: `CustomPlaylistController` → `POST /cms/custom-playlist`
- Assign playlist to screen: `CustomPlaylistController` → `POST /cms/custom-playlist/assign`

---

### N1 — fmcom-api (content intake and dispatch)

**What fmcom-api does:**

For new content:
1. Receives the upload (multipart or URL reference).
2. Stores the raw file to AWS S3 (via SDK v1 `AmazonS3`).
3. Creates a `Content` JPA entity in MySQL with `TranscodingStatus = PENDING`. Content uses single-table inheritance (`Video`, `Youtube`, `Album`, `SocialNetworkPost`).
4. Dispatches a `MediaProcessingMessage` to JMS destination `RNF_MEDIA_PROCESSING` via `MediaProcessingDispatcher`.

For playlist modifications:
1. Persists playlist changes to MySQL (`Playlist`, `PlaylistContent`, `ScreenPlaylist`).
2. Calls `ContentUpdateNotificationServiceImpl.contentChange(screen)` for each affected screen.
3. Applies **subscription-based throttling** before publishing:
   - PRO subscriptions: 1-second coalescing window
   - PLUS / BRAND_ONLY: 30-second coalescing window
   - FREE / LOCKED: **no notification sent** — RNF is never triggered for these screens
4. Dispatches a `GenerateMessage` (orgId or screenId) to JMS destination `RNF_GENERATE`, or `ScreenUpdateMessage` to `PLAYER_SCREEN_CONTENT_PENDING`.

**JMS publish is deferred until DB transaction commits** via `TransactionSynchronizationManager`. The message is not sent inline during the request; it is queued for post-commit dispatch to avoid notifying downstream services of changes that may be rolled back.

Also after a content change: `ScreenPlayService.resetPlans(screenId)` and `AdCampaignScreenSlotService.recalculateSlotsForScreen(screen)` are called synchronously.

**Synchronous Feign call to State Service** for screen validation before acting.

**Data leaving N1:**

| Destination | JMS topic | Message type | Fields |
|---|---|---|---|
| RNF | `RNF_MEDIA_PROCESSING` | `MediaProcessingMessage` | `operation` (VIDEO_TRANSCODE or PDF_TO_IMAGE), `contentId`, `ContentStore` |
| RNF | `RNF_GENERATE` | `GenerateMessage` | `orgId` or `screenId` |
| RNF | `PLAYER_SCREEN_CONTENT_PENDING` | `ScreenUpdateMessage` | `screenId` |

Legacy: fmcom-api may still publish `TranscodeMessage` to `RNF_TRANSCODE_DESTINATION` (shim queue in RNF; scheduled for removal). Both are handled.

**Data arriving at N1 (from N2):**

| Source | JMS topic | Message type | Purpose |
|---|---|---|---|
| RNF | `API_CONTENT_ADD` | `ContentAddMessage` | Signals transcoding complete; fmcom-api's `ContentMessageHandlers` adds the content to a default screen |

The `ContentAddMessage` carries `contentId`, optional `organizationId`, optional `screenId`, and `ContentStore`. fmcom-api consumes this via `ContentMessageHandlers` (gated by `@ConditionalOnProperty`).

**Important:** `API_CONTENT_ADD` can be published by both RNF (on transcode completion) and fmcom-api itself (for non-transcoding content events). The consumer in `ContentMessageHandlers` must handle idempotent delivery.

---

### N2 — RNF media processing (transcoding pipeline)

**What RNF does:**

1. `MediaProcessingHandlers` receives `MediaProcessingMessage` from `RNF_MEDIA_PROCESSING`.
2. Routes to `MediaPipelineOrchestrator` → `VideoTranscodePipeline` → `UnifiedVideoPipeline`.
3. `UnifiedVideoPipeline` executes four pipeline stages, each in a separate thread pool:
   - **Download**: pulls raw media from S3 to shared EFS mount (`/mnt/efs`).
   - **Transcode**: FFmpeg normalization to canonical h264 MP4; color normalization (HDR tonemap, wide-gamut SDR, or passthrough depending on source).
   - **Tier variants**: generates standalone MP4 tiers (720p, 540p, etc.).
   - **HLS ladder**: generates HLS master playlist + rung playlists + `.ts` segments; uploads all artifacts to S3.
4. On completion, uploads results to S3 and invalidates CloudFront cache.
5. Publishes two messages:
   - `PLAYER_CONTENT_TRANSCODED` to JMS (per-item; only for `TriggerMode.MESSAGE` flows — i.e., fresh upload or per-id REST dispatch).
   - `API_CONTENT_ADD` to JMS → consumed by fmcom-api (N1).

For admin bulk re-transcodes (`TriggerMode.REST_BULK`), `PLAYER_CONTENT_TRANSCODED` is suppressed and instead `PLAYER_CONTENTS_TRANSCODED_BATCH` is published once per completed bulk job.

**Back-pressure and deduplication:**
- `UnifiedVideoPipeline` uses a bounded `LinkedBlockingQueue` (`pipelineDownloadAheadLimit = 10` in prod) between download and transcode stages.
- JVM-level dedup via `inPipeline` set prevents the same content from entering the pipeline twice concurrently.

**Data leaving N2:**

| Destination | JMS topic | Message type | Fields | Condition |
|---|---|---|---|---|
| Amazon MQ → player-api | `PLAYER_CONTENT_TRANSCODED` | `ContentTranscodedMessage` | `contentId` | `TriggerMode.MESSAGE` only |
| Amazon MQ → player-api | `PLAYER_CONTENTS_TRANSCODED_BATCH` | `ContentsTranscodedBatchMessage` | `List<contentId>` | `TriggerMode.REST_BULK` only |
| Amazon MQ → fmcom-api | `API_CONTENT_ADD` | `ContentAddMessage` | `contentId`, `organizationId?`, `screenId?`, `ContentStore` | `TriggerMode.MESSAGE` only |

**Pipeline version stamp:** every produced artifact carries `TranscodePipelineVersion` (currently `7`). Bulk sweeps use this to skip already-current content.

---

### N3 — RNF playlist generation

Triggered by:
- `RNF_GENERATE` or `PLAYER_SCREEN_CONTENT_PENDING` from fmcom-api (playlist modification flow, Flow B).
- Indirectly from Flow A: after fmcom-api receives `API_CONTENT_ADD` and adds content to a screen, it presumably triggers a regeneration (the exact mechanism connecting N2 completion to `RNF_GENERATE` for Flow A is not fully visible in the spikes; may be driven by fmcom-api's `ContentMessageHandlers` or by a daily scheduled sweep).
- Daily sweep: `GenerateDailyPlaylistJob` runs via XXL-Job and regenerates all eligible screens.

**What RNF does:**

1. `MessageHandlers` receives `GenerateMessage` (orgId or screenId).
2. Calls `PlaylistGenerationService.generateOrg` or `generateScreen`.
3. `PlaylistGeneratorServiceImpl` resolves SOV rules:
   - Reads `ElasticAdCampaignScreenSlot` from Elasticsearch (SOV percentages per brand, per screen).
   - For paid screens: reads `MySqlScreenStripeSubscription` for `customPercentage`.
4. Loads content via `ContentServiceExt`.
5. Assembles `ContentContainer` (SOV-aware in-memory content pool).
6. Iterates open-hours periods (`PeriodContainer`) and traffic slots (`TrafficLevel: HIGH/LOW`) to fill a time-indexed slot sequence.
7. Writes result to `ElasticPlaylistSchedule` and `ElasticPlayCurrent` in Elasticsearch.
8. Per-screen mutual exclusion via Redis (`SyncOpService`).
9. Publishes:
   - `PLAYER_ORGANIZATION_CONTENT_UPDATED` (orgId) after org-level generation.
   - `PLAYER_SCREEN_CONTENT_UPDATED` (screenId) after screen-level generation.

**Timeouts (silent on miss):**
- Per-org: 30 minutes (`TIMEOUT_EXECUTION_ORG_MS`).
- Per-screen: 5 minutes (`TIMEOUT_EXECUTION_SCREEN_MS`).
- A timeout returns the default value silently; no message is published, no error is raised to callers.

**Data leaving N3:**

| Destination | JMS topic | Message type | Fields |
|---|---|---|---|
| Amazon MQ → player-api | `PLAYER_ORGANIZATION_CONTENT_UPDATED` | `OrganizationUpdateMessage` | `orgId` |
| Amazon MQ → player-api | `PLAYER_SCREEN_CONTENT_UPDATED` | `ScreenUpdateMessage` | `screenId` |

**Data written to Elasticsearch:**
- `ElasticPlaylistSchedule`: full time-indexed content sequence for each screen.
- `ElasticPlayCurrent`: the live "now playing" index.

---

### N4 — Message bus (Amazon MQ / State Service broker)

RNF publishes `PLAYER_*` messages to Amazon MQ using Spring JMS (`MessagingService.send`). All destinations are namespaced by a `BROKER_PREFIX` environment variable.

**State Service broker note:** The State Service implements an in-process JMS-like broker (backed by `ConcurrentHashMap` + `ConcurrentLinkedQueue`). fmcom-player-api connects to it via HTTP long-poll (`POST /broker/consume`, up to 22s hold per request) rather than directly to Amazon MQ for certain message flows. Based on the spikes, it is not fully resolved whether `PLAYER_*` notifications from RNF transit through Amazon MQ directly to player-api or are routed through the State Service broker. The State Service spike documents that player-api uses the broker for coordination and routing; the player-api spike documents direct Amazon MQ subscriptions to `PLAYER_*` topics. Both mechanisms may coexist: Amazon MQ for bulk notifications, State Service broker for per-device routing.

**State Service as screen registry:** All services that need screen data call State Service rather than querying MySQL directly. State Service holds every `ScreenDto` in a JVM-resident `ConcurrentHashMap`. Reads return from memory in microseconds; writes flush to MySQL on a 1-minute schedule.

**Delivery characteristics of the State Service broker:** at-most-once delivery; messages are lost on State Service restart or OOM-kill. Clients missing a 5-minute inactivity window are evicted and miss messages during that gap silently.

---

### N5 — fmcom-player-api (notification routing)

**Handler methods** (`MessageHandlers.java`, `@PostConstruct` JMS subscriptions):

| Message received | Handler method | Action |
|---|---|---|
| `PLAYER_ORGANIZATION_CONTENT_UPDATED` | `handleOrganizationContentUpdated()` | Calls `broadcastOrganizationMessage(orgId, screenNotificationService::contentChanged)` |
| `PLAYER_CONTENT_TRANSCODED` | `handleContentTranscoded()` | Calls `quarantineRestoreService.restoreAllForContent(contentId)` — clears quarantine flags in Redis |
| `PLAYER_CONTENTS_TRANSCODED_BATCH` | `handleContentsTranscodedBatch()` | Same as above, async via `CompletableFuture` for each id in batch |
| `PLAYER_SCREEN_CONTENT_UPDATED` | `handleScreenContentUpdated()` | Calls `screenNotificationService::contentChanged` for the specific screen |

**Org-wide fanout — `broadcastOrganizationMessage`:**

```java
private void broadcastOrganizationMessage(Long orgId, Consumer<String> action) {
    List<String> macs = screenStateClient.selectMacsByEnabledIsTrueAndOrganizationId(orgId);
    macs.forEach(action);  // contentChanged(mac) called for EVERY enabled screen in the org
}
```

`PLAYER_ORGANIZATION_CONTENT_UPDATED` triggers `contentChanged(mac)` for **every enabled screen in the org**, not just the screen whose content changed. A single admin action on one screen causes all devices in the org to receive `CONTENT_CHANGED`, blank immediately, and reload their playlist. There is no filtering by which screenId was actually affected.

**`contentChanged(mac)` — `ScreenNotificationServiceImpl.java`:**

Sends two messages per device on every call:
1. Modern: `WebSocketMessageDto { type: CONTENT_CHANGED }` 
2. Legacy: `WebSocketLegacyMessageDto` with `GET_DATA`, `GET_PLAYLIST`, `GET_BRAND_PLAYLIST` (backward compatibility for older player versions)

**WebSocket delivery (`WebSocketMessagingServiceImpl.send`):**
- `WsSessionHolder.get(mac)` → retrieves `ConcurrentWebSocketSessionDecorator` for the device.
- If session is open: sends `TextMessage` immediately (5-second send timeout, 512KB buffer per session).
- If session is null or closed: `UnsentNoticeService.registerUnsentNotice(mac, group, message)` — queues for reconnect delivery (in-memory only, **30-second TTL**, cleaned up every 10 seconds).

**Session architecture constraint:** Sessions and WebSocket connections are held in `ConcurrentHashMap` instances local to each JVM instance. There is no distributed session replication across ECS tasks. A device's WebSocket connection is on one node; a notification arriving on a different node cannot deliver directly. Cross-node delivery falls to `UnsentNoticeService` rather than live push.

**Playlist serving (on device request):** When the device requests a fresh playlist (`GET player/playlist/current`), player-api calls RNF at `GET /playlist/current/{screenId}`, which reads from `ElasticPlaylistSchedule`. Player-api then:
1. Checks if the organization is end-of-life → returns EOL content.
2. Checks if the screen is locked or doesn't meet brand requirements → returns brick-mode content.
3. Otherwise calls `PlaylistCurrentServiceImpl.getCurrentPlaylist(screenId, offset, length)` (from `fm-common` → queries Elasticsearch).
4. Rewrites all content URLs with CloudFront-signed URLs via `ContentUtils.updatePlaylistUrls()`.
5. Applies per-screen quality cap (Redis) and per-(screen, content) escalation state (Redis) — up to 30–60 synchronous Redis reads per request on large playlists.

**Data sent to html5core (WebSocket):**

| WebSocket message type | When sent | Payload |
|---|---|---|
| `CONTENT_CHANGED` | On `PLAYER_ORGANIZATION_CONTENT_UPDATED` or `PLAYER_SCREEN_CONTENT_UPDATED` | No payload; signal only |
| `CONFIG` | On org/screen config changes (e.g. `contentType` change) | Updated config blob |
| `DISCONNECT` | On server-side disconnect event | Triggers `window.location.reload()` on device |
| `HEARTBEAT` | Periodic | Requires heartbeat response; no playlist action |

Message envelope: `WebSocketMessageDto` (type: `WebSocketMessageType`, payload: Object, ack token).

---

### N6 — html5core player (content reload)

**WebSocket handler** (`src/store/websocket.ts`):

```
case MessageType.CONTENT_CHANGED:
    usePlaylists().reloadCurrentPlaylist()
```

No payload inspection — the message type alone triggers a full playlist reload. The WebSocket connection is tied to the app lifecycle (`PlayerScreen.vue` mount), not to playlist playback: it is always open as long as the app is running, including during consultation mode and settings views. Other messages that also trigger a reload: `CONFIG` (if `contentType` changes → calls both `loadPlaylists()` and `reloadCurrentPlaylist()`); `DISCONNECT` → `window.location.reload()`.

**WebSocket connection details:** URL includes device MAC, platform, model, display resolution, and SHA-1 cryptographic signature. Heartbeat every 30 seconds. Auto-reconnects after 1000ms on disconnect.

---

### N6a — `reloadCurrentPlaylist()` (`src/store/playlists.ts`)

**Guard checks — silently skip if:**
- `playbackController.isConsults === true` — consultation mode active; do not interrupt the consult session.
- `__currentPlaylistLoading === true` — a concurrent reload is already in progress; second call is dropped.

**Immediate state reset (before network fetch):**
```
__currentPlaylistLoading = true
playbackController.setPlaylist([])   ← old playlist cleared immediately; screen goes blank
```

`setPlaylist([])` is called **before** the HTTP fetch begins. The screen goes blank at this point and stays blank until `setPlaylist(newPlaylist)` is called after the fetch completes. If the fetch fails, `apiRequest()` returns `{}`, `_parsePlaylist` produces an empty array, and `setPlaylist([])` is called again — the screen stays blank until the watchdog fires at 20s.

Each screen has exactly one content assignment at any given time. `GET player/playlist/current` always returns whatever the screen is currently configured to show. Nothing is cached on the device; every reload is a fresh server fetch.

**Mode determination:**

| Condition | Mode | Fetch path |
|---|---|---|
| `overridePlaybackMode === Shuffle` | SOV | Path A |
| `overridePlaybackMode === SelectedPlaylist` | Combined | Path B |
| `config.contentType === Free \| Paid` | SOV | Path A |
| `config.contentType === Playlist` | Combined | Path B |

---

### N6b — Path A: SOV Playlist (`__loadSovPlaylist`)

1. `GET player/playlist/current?from=[ISO8601_DATETIME]`
2. Response shape: `{ content: _Content1[], screenId, organizationId, timestamp, ... }`
3. Calls `_parsePlaylist(data)`.

---

### N6c — Path B: Combined/Custom Playlist (`__loadCombinedPlaylist`)

1. `GET player/custom-playlist/all` → list of all available playlists for the screen.
2. Determines which playlist IDs to load (selected or all).
3. For each playlist ID: `GET player/custom-playlist/{playlistId}`.
4. Merges content arrays.
5. For DYNAMIC slots (brand content): `GET player/custom-playlist/brand/{brandId}?size={count}`.
6. Filters out unfilled dynamic slots: `playlist = playlist.filter(c => c?.content?.contentType)`.
7. Calls `_parsePlaylist(data)`.

---

### N6d — Playlist Parsing (`_parsePlaylist`)

For each content item, based on `contentType`:

| Type | Result |
|---|---|
| VIDEO | `VideoContent { url, duration, subtitleUrl, qrLink, ctaText }` |
| ALBUM | Expands each picture into `PictureContent { url, duration: albumDuration/pictureCount }` |
| YOUTUBE | `YoutubeContent { videoId, embedUrl }` |
| Unknown | Warning logged; item skipped silently |

**Final step:**
```
playbackController.setPlaylist(newPlaylist)
  → __playlist = newPlaylist
  → setContentIndex(0)            ← resets to item 0
  → playlistLastUpdated = new Date()
```

`autoUpdate.ts` fetches `/build.json` on every playlist reload and calls `window.location.reload()` if the build hash differs (opportunistic update — only applies when playlist naturally reloads).

---

### N7 — Playback (`VideoPlayer.vue`, `PicturePlayer.vue`, `YoutubePlayer.vue`)

**Video playback** (most common path):
- **No HLS/DASH.** html5core uses HTTP progressive download via CloudFront CDN. The browser fetches a direct MP4 URL and begins playing as bytes arrive. No adaptive bitrate streaming, no manifest file, no specialized streaming player library.
- `videoTag.load()` → `videoTag.play()`
- Subtitles: separate `fetch(subtitleUrl)` → parse VTT → create blob URL → attach via `<track>` element.

**On content change** (`contentChanged()` in `VideoPlayer.vue`):
1. `stop()` — pauses playback, clears subtitle tracks.
2. `stateChanged(PlaybackState.None)` — resets state to None.
3. `play()` — loads new URL and starts playback.
4. `reportState()` — sends state to watchdog.

**Picture:** displayed for calculated duration, then advances to next item.

**YouTube:** loaded in iframe with `autoplay=1` via `@vue-youtube/core`.

---

### N8 — Playback watchdog (`src/store/playbackWatchdog.ts`)

Runs on a **500ms** heartbeat (not 1 second).

| Threshold | Action |
|---|---|
| 5 seconds no state change | `playerStuck = true` |
| 10 seconds | `pressNext()` — skip to next content item |
| 20 seconds | `resetPlaylist()` → calls `reloadCurrentPlaylist()` — re-fetch from server |
| 30 seconds | `resetApp()` → `window.location.reload()` — full page reload |

**Reset condition:** watchdog resets its counter when the state hash changes: `"${state}/${type}/${title}/${time}/${duration}"`. If the hash stays the same across ticks, the counter increments.

**Buffering behavior:** while in `Buffering` state, the watchdog timer **keeps counting** — buffering does not suppress the counter. This means a device stuck buffering will hit the 10s skip / 20s reload / 30s page reload thresholds just like a frozen video.

**Paused behavior:** the watchdog does **not** trigger if `state === Paused`.

**Integration with playlist reload** (`PlayerScreen.vue`):
```js
watchEffect(() => {
  if (playbackWatchdog.playlistResetRequired && playbackController.isDefault) {
    playlists.reloadCurrentPlaylist()
  }
})
```

---

## Conditional Paths

### Screen tier is FREE or LOCKED (N1)

fmcom-api's `ContentUpdateNotificationServiceImpl` applies subscription-based throttling before dispatching JMS:
- FREE / LOCKED: no notification sent at all. The JMS message to RNF is never published.
- RNF is never triggered; no playlist regeneration occurs; no device receives `CONTENT_CHANGED`.
- Device only updates on the next daily XXL-Job sweep.

### Throttle window active (N1)

- PLUS / BRAND_ONLY: notifications are coalesced within a 30-second window.
- If multiple admin actions happen within the window, only one JMS dispatch fires at the end.
- Device receives the update with up to 30 seconds of delay.

### Transcoding failure (N2)

If `UnifiedVideoPipeline` fails at any stage (download error, FFmpeg crash, S3 upload failure):
- The claimed content row is marked `FAILED`; `inPipeline` dedup set is cleared.
- `PLAYER_CONTENT_TRANSCODED` is **not** published.
- `API_CONTENT_ADD` is **not** published.
- No downstream notification reaches N5 or N6.
- The content remains in its previous `TranscodingStatus` state in MySQL; no automatic retry unless the stuck-recovery sweep (`executeTranscoding` XXL-Job) re-dispatches the row.
- On RNF JVM restart, the shutdown hook marks all in-flight claimed rows as `FAILED`.

### State Service hard-exit killing RNF (N2/N3)

RNF's `FeignConfig.connectionCheck()` pings State Service every minute. If the ping fails:
- `System.exit(-1)` is called immediately — no backoff, no retry.
- All in-flight transcoding stages are interrupted.
- ECS restarts the container; all in-progress pipeline work is lost.
- Any `PLAYER_*` messages that were about to be published are not sent.

### Playlist generation timeout (N3)

If `PlaylistGenerationServiceImpl` exceeds 30 minutes (org) or 5 minutes (screen):
- `waitForCompletion` returns the default value silently.
- No `PLAYER_ORGANIZATION_CONTENT_UPDATED` or `PLAYER_SCREEN_CONTENT_UPDATED` is published.
- No notification reaches N5 or N6.
- The device continues playing its current playlist until the next successful generation.
- No error log triggers an alert; the only signal is the `detectLongRunningTask` logger call.

### Device WebSocket disconnected (N5 → N6)

If the device's WebSocket is closed when player-api attempts to send `CONTENT_CHANGED`:
- `UnsentNoticeService.registerUnsentNotice(mac, group, message)` queues the message.
- **30-second TTL**: if the device does not reconnect within 30 seconds, the message is discarded.
- On reconnect, queued unsent notices are delivered via the next `register()` call.
- html5core auto-reconnects after 1000ms; if the reconnect succeeds within 30s, the `CONTENT_CHANGED` is delivered and the reload proceeds normally.
- If the device is offline longer than 30s, the watchdog's `resetPlaylist()` at 20s or page reload at 30s provides a recovery path independently.

### Notification on wrong player-api node (N5)

Because sessions are node-local (no distributed replication), a `PLAYER_SCREEN_CONTENT_UPDATED` arriving on node A for a device whose WebSocket is connected to node B will:
- Fail to find the session in `WsSessionHolder` on node A.
- Fall to `UnsentNoticeService` on node A (30-second TTL).
- Not reach the device until the Amazon MQ fan-out puts the message on node B, or until the device reconnects.

### API fetch fails (N6a / N6b)

If the playlist HTTP request fails:
- `apiRequest()` returns `{}`.
- `_parsePlaylist` receives empty data and produces an empty array.
- `setPlaylist([])` is called again — the screen stays blank.
- `__currentPlaylistLoading` is reset to `false`.
- No error is surfaced to the user; screen remains blank until watchdog fires at 20s (`resetPlaylist`) or 30s (page reload).

### Content type unknown during parsing (N6d)

If `_parsePlaylist` encounters an item with an unrecognized `contentType`:
- A warning is logged.
- The item is skipped silently.
- If all items in the response are unknown, `setPlaylist([])` is effectively the result — screen stays blank.

### Video fails to play (N7)

If the `<video>` element fires an `@error` event:
- `stateChanged(PlaybackState.Error)` is called.
- The watchdog observes the state hash not advancing past Error.
- At 10s: `pressNext()` — skips to the next content item.
- If all items in the playlist fail, the watchdog escalates to 20s reload → 30s page reload.

### Device in consultation mode (N6)

`reloadCurrentPlaylist()` guards on `playbackController.isConsults === true` and returns early without fetching or updating the playlist. The `CONTENT_CHANGED` signal is silently dropped. The device continues the consultation flow uninterrupted. The updated playlist is not applied until the consultation ends and the player returns to default mode.

### Concurrent reload already in progress (N6)

If a second `CONTENT_CHANGED` arrives while `__currentPlaylistLoading === true`:
- `reloadCurrentPlaylist()` returns immediately without action.
- The second reload is silently dropped.
- The first reload's result (success or failure) applies to both.

### Content URL rewriting failure (N5)

Player-api rewrites every content URL with a CloudFront-signed URL before returning the playlist:
- Up to 30–60 synchronous Redis reads per playlist request (escalation state per content item, quality cap per screen).
- A CloudFront key operation per URL.
- If Redis is degraded, playlist delivery to the device is delayed or fails.

### RNF feature flags disabled (N1/N3)

- `rnf.jms.handlers.generate=false`: `RNF_GENERATE` messages are received but not processed; only the daily XXL-Job sweep regenerates playlists.
- `rnf.jms.enabled=false`: all six JMS listeners in RNF are disabled simultaneously (media processing + playlist generation + open-hours + recently-activated). All content update processing in RNF stops.

---

## Data Flowing Between Nodes — Summary

| From | To | Channel | Message / Data | Key Fields |
|---|---|---|---|---|
| Admin | fmcom-api | HTTP REST | Upload + playlist mutation | contentId, playlistId, orgId |
| fmcom-api | S3 | AWS SDK | Raw media file | S3 key |
| fmcom-api | RNF | JMS `RNF_MEDIA_PROCESSING` | `MediaProcessingMessage` | operation, contentId, ContentStore |
| fmcom-api | RNF | JMS `RNF_GENERATE` | `GenerateMessage` | orgId or screenId |
| fmcom-api | RNF | JMS `PLAYER_SCREEN_CONTENT_PENDING` | `ScreenUpdateMessage` | screenId |
| RNF | S3 | AWS SDK (v1+v2) | Transcoded artifacts (MP4 tiers, HLS ladder) | S3 keys per tier |
| RNF | fmcom-api | JMS `API_CONTENT_ADD` | `ContentAddMessage` | contentId, organizationId?, screenId?, ContentStore |
| RNF | player-api | JMS `PLAYER_CONTENT_TRANSCODED` | `ContentTranscodedMessage` | contentId |
| RNF | player-api | JMS `PLAYER_CONTENTS_TRANSCODED_BATCH` | `ContentsTranscodedBatchMessage` | List\<contentId\> |
| RNF | player-api | JMS `PLAYER_ORGANIZATION_CONTENT_UPDATED` | `OrganizationUpdateMessage` | orgId |
| RNF | player-api | JMS `PLAYER_SCREEN_CONTENT_UPDATED` | `ScreenUpdateMessage` | screenId |
| RNF | Elasticsearch | Spring Data ES | `ElasticPlaylistSchedule`, `ElasticPlayCurrent` | screenId, time-indexed slots |
| player-api | html5core | WebSocket | `WebSocketMessageDto` (type=CONTENT_CHANGED) | ack token |
| player-api | html5core | WebSocket | `WebSocketLegacyMessageDto` (GET_DATA, GET_PLAYLIST, GET_BRAND_PLAYLIST) | — |
| html5core | player-api | HTTP GET | `player/playlist/current?from=...` | screenId (from session) |
| html5core | player-api | HTTP GET | `player/custom-playlist/all`, `/custom-playlist/{id}`, `/custom-playlist/brand/{id}` | playlistId, brandId |
| player-api | RNF | HTTP GET | `/playlist/current/{screenId}` | screenId |
| RNF | player-api | HTTP response | `PlaylistCurrentDto` | screen/orgId, date, PlaylistEntryDto[] |
| player-api | html5core | HTTP response | Playlist with CF-signed URLs, quality-capped | Content[], CloudFront-signed src URLs |

---

## Key Architectural Constraints

1. **Org-wide fanout on every content update.** `PLAYER_ORGANIZATION_CONTENT_UPDATED` triggers `contentChanged(mac)` for every enabled screen in the org — not just the affected screen. All devices in the org blank simultaneously and reload their playlists. This is by design (org-level message granularity) but introduces unnecessary blank screen risk on each update.

2. **`setPlaylist([])` fires before the network fetch.** html5core clears the current playlist immediately on `CONTENT_CHANGED`, before the HTTP response arrives. The blank period lasts from the moment the WebSocket message is received until the fetch completes. If the fetch fails, the screen stays blank until the watchdog recovers at 20s.

3. **RNF exits hard on State Service loss.** Any transient State Service outage kills all in-flight transcoding work in RNF with `System.exit(-1)`.

4. **Playlist generation timeouts are silent.** A screen can silently receive no playlist update if generation takes too long, with no observable signal at N5 or N6.

5. **Player-api sessions are node-local.** Cross-node notification delivery is not guaranteed in real-time; unsent notices have a 30-second TTL before being discarded.

6. **FREE/LOCKED screens are never notified.** fmcom-api suppresses all JMS dispatch for these tiers; devices only update on the daily sweep.

7. **Telemetry is best-effort.** player-api's `TelemetryController` swallows all exceptions; `TelemetryEventAnalyzerService` runs fire-and-forget. Loss is silent.

8. **`sendIssue()` in html5core is dead code.** `src/store/serverLogger.ts` has an unconditional `return` on line 38 making the entire server-side issue-reporting feature a no-op.

9. **Telemetry buffer in html5core has no size cap.** If WebSocket is offline for an extended period, `localStorage` accumulates telemetry without bound; older entries are never evicted.