# Playlist Update Flow Map — html5core

**Scope:** html5core player only. Roku and Android out of scope.
**Purpose:** Neutral end-to-end map of what happens when an admin updates a playlist or adds content, from API call to device playback. No logging analysis — that is Paso 0B.
**Sources:** Tech spikes (rnf, state-service, fmcom-api, fmcom-player-api, html5core-player) + repo analysis.

---

## Overview

```
Admin action (VAM/VPM)
  → fmcom-api: validates, persists, throttles, publishes JMS
  → ActiveMQ broker
  → RNF: generates playlist, transcodes media
  → State Service broker (in-memory JMS)
  → fmcom-player-api: receives message, pushes to device
  → WebSocket → html5core player
  → Player clears playlist, fetches new one from server, loads content, plays
```

---

## Step 1 — Admin triggers a content change (fmcom-api)

**Entry points** (fmcom-api controllers):
- Add/update/delete content: `ModernContentController` → `POST/PUT/DELETE /cms/content`
- Add content to screen: `ScreenContentController` → `POST /cms/screenContent/addContentToScreen`
- Create/update custom playlist: `CustomPlaylistController` → `POST /cms/custom-playlist`
- Assign playlist to screen: `CustomPlaylistController` → `POST /cms/custom-playlist/assign`

**What fmcom-api does internally:**
1. Persists the change to MySQL
2. Calls `ContentUpdateNotificationServiceImpl.contentChange(screen)` for each affected screen
3. **Applies subscription-based throttling before publishing:**
   - PRO subscriptions: 1-second coalescing window
   - PLUS / BRAND_ONLY: 30-second coalescing window
   - FREE / LOCKED: no notification sent
4. **Publishes JMS messages to ActiveMQ:**
   - `PLAYER_SCREEN_CONTENT_PENDING` (ScreenUpdateMessage) → consumed by RNF
   - `RNF_MEDIA_PROCESSING` (MediaProcessingMessage) → consumed by RNF for video transcode / PDF-to-image
   - Deferred until DB transaction commits via `TransactionSynchronizationManager`
5. Calls `ScreenPlayService.resetPlans(screenId)` and `AdCampaignScreenSlotService.recalculateSlotsForScreen(screen)`
6. Synchronous Feign calls to State Service to validate screen ownership before acting

**What flows downstream:** A JMS message with screen ID and update type. No playlist content at this stage — RNF does the resolution.

---

## Step 2 — RNF generates playlist and transcodes media

**RNF receives from ActiveMQ:**
- `PLAYER_SCREEN_CONTENT_PENDING` / `RNF_GENERATE` → triggers playlist generation
- `RNF_MEDIA_PROCESSING` → triggers video transcode or PDF-to-image conversion

**Playlist generation:**
1. Resolves which content belongs on the screen (SOV rules, custom playlists, brand slots)
2. Writes `ElasticPlaylistSchedule` to Elasticsearch
3. Hard timeouts: 30 minutes per organization, 5 minutes per screen
4. On completion, publishes to State Service broker:
   - `PLAYER_ORGANIZATION_CONTENT_UPDATED` (OrganizationUpdateMessage) — triggers notification to all screens in org
   - `PLAYER_CONTENT_TRANSCODED` (ContentTranscodedMessage) — per content ID after transcode
   - `PLAYER_CONTENTS_TRANSCODED_BATCH` (ContentsTranscodedBatchMessage) — batch variant

**Media transcode:**
1. FFmpeg processes video on EFS
2. Output uploaded to S3 / CloudFront
3. On completion, publishes `PLAYER_CONTENT_TRANSCODED` / `PLAYER_CONTENTS_TRANSCODED_BATCH`
4. Also publishes `API_CONTENT_ADD` back to fmcom-api (to distribute new content to screens)

**Key decision points:**
- If the screen is in a `LOCKED` or `FREE` tier, fmcom-api never sends the notification — RNF never runs for that screen.
- If the State Service is unavailable, RNF calls `System.exit(-1)` on its next 1-minute ping check, killing all in-flight work.

---

## Step 3 — State Service broker distributes messages

**State Service role here:** In-memory JMS broker. It is the message bus between RNF, fmcom-api, and fmcom-player-api.

**Message routing:**
- RNF publishes `PLAYER_ORGANIZATION_CONTENT_UPDATED` → State Service delivers to fmcom-player-api
- RNF publishes `PLAYER_CONTENT_TRANSCODED` / `PLAYER_CONTENTS_TRANSCODED_BATCH` → State Service delivers to fmcom-player-api
- State Service also coordinates Elasticsearch quota allocation (`ElasticsearchLimitsAllocated`) to all services

**Delivery mechanism:**
- fmcom-player-api connects via HTTP long-poll with 22-second hold
- Messages are delivered at-most-once; undelivered messages lost on State Service restart or OOM-kill
- Clients missing a 5-minute inactivity window are evicted and miss messages during that gap

---

## Step 4 — fmcom-player-api receives and pushes to device

**fmcom-player-api JMS handlers** (`MessageHandlers.java`):

| Message received | Handler | Action |
|---|---|---|
| `PLAYER_ORGANIZATION_CONTENT_UPDATED` | `handleOrganizationContentUpdated()` | Queries all enabled screens for org → calls `contentChanged(mac)` for each |
| `PLAYER_CONTENT_TRANSCODED` | `handleContentTranscoded()` | Calls `quarantineRestoreService.restoreAllForContent(contentId)` — clears quarantine flags in Redis |
| `PLAYER_CONTENTS_TRANSCODED_BATCH` | `handleContentsTranscodedBatch()` | Same as above, async via `CompletableFuture` for batch |

**`contentChanged(mac)` — WebSocket push to device** (`ScreenNotificationServiceImpl.java`):
1. Sends `WebSocketMessageDto { type: CONTENT_CHANGED }` via `WebSocketMessagingService.send(mac, group, supplier)`
2. Also sends legacy message for backward compatibility: `WebSocketLegacyMessageDto` with `GET_DATA`, `GET_PLAYLIST`, `GET_BRAND_PLAYLIST`

**Session lookup and send:**
1. `WsSessionHolder.get(mac)` → retrieves the active `ConcurrentWebSocketSessionDecorator` for the device
2. If session exists and open: sends `TextMessage` immediately
3. If session is null or closed: `UnsentNoticeService.registerUnsentNotice(mac, group, message)` — queues for reconnect
   - In-memory only, 30-second TTL
   - Cleaned up every 10 seconds
   - Delivered on next `register()` call when device reconnects

**When device is connected:**
- Session tracked in `WsSessionHolder` (in-memory `ConcurrentHashMap<MAC, WebSocketSession>`)
- Sessions expire after configurable inactivity timeout (checked every 10 minutes)
- WebSocket send: 5-second send timeout, 512KB buffer per session

> **Org-wide fanout:** `PLAYER_ORGANIZATION_CONTENT_UPDATED` triggers `contentChanged(mac)` for **every enabled screen in the org**, not just the screen whose content changed. fmcom-player-api queries all enabled screens for the org and sends `CONTENT_CHANGED` to each. Screens whose content did not change still reload, blank, and reset to item 0. This is by design (org-level message granularity) but introduces unnecessary blank screen risk across all devices in the org on every update. See `blank-screen-causes.md` B1.

---

## Step 5 — html5core player receives CONTENT_CHANGED

**WebSocket handler** (`websocket.ts`):
```
case MessageType.CONTENT_CHANGED:
    usePlaylists().reloadCurrentPlaylist()
```

No payload inspection needed — the message type alone triggers a full playlist reload.

> **Note:** The WebSocket connection is tied to the app lifecycle (`PlayerScreen.vue` mount), not to playlist playback. It is always open as long as the app is running — including during consultation mode, settings views, or any other state. `reloadCurrentPlaylist()` runs in most app states; the only guards are consultation mode (`isConsults`) and a concurrent reload already in progress (`__currentPlaylistLoading`). The screen does not need to be actively playing for the reload to execute.

**Other message types that also trigger a reload:**
- `CONFIG` — if `contentType` changes (e.g. FREE→PAID), both `loadPlaylists()` and `reloadCurrentPlaylist()` are called
- `DISCONNECT` — triggers `window.location.reload()` (full page reload)
- `HEARTBEAT` — requires heartbeat response; no playlist action

**WebSocket connection details:**
- Initiated on component mount (`PlayerScreen.vue` → `websocket.start()`)
- URL includes: device MAC, platform, model, display resolution, cryptographic signature (SHA-1)
- Heartbeat every 30 seconds
- Auto-reconnects after 1000ms on disconnect

---

## Step 6 — Player reloads playlist (reloadCurrentPlaylist)

**Entry: `usePlaylists().reloadCurrentPlaylist()`** (`playlists.ts`):

**Guard checks (skip if):**
- `playbackController.isConsults === true` — consultation mode active; don't interrupt
- `__currentPlaylistLoading === true` — concurrent load already in progress; silently skip

**Immediate state reset (before fetch):**
```
__currentPlaylistLoading = true
playbackController.setPlaylist([])   ← old playlist cleared immediately
```

> **Blank screen risk:** `setPlaylist([])` is called before the network fetch completes. The screen goes blank immediately and stays blank until the new playlist arrives. If the fetch fails, `apiRequest()` returns `{}`, `_parsePlaylist` produces an empty array, and the screen remains blank until the watchdog fires at 20 seconds. See `blank-screen-causes.md` B2, B3.

> **One content assignment per screen:** Each screen has exactly one content assignment at any given time. `GET player/playlist/current` (SOV) and `GET player/custom-playlist/all` (combined) always return whatever the screen is currently configured to show — there is no concept of "wrong playlist." Nothing is cached on the device; every reload is a fresh server fetch.

**Mode determination (from config):**
- `overridePlaybackMode === Shuffle` → `__loadSovPlaylist()`
- `overridePlaybackMode === SelectedPlaylist` → `__loadCombinedPlaylist()`
- `config.contentType === Free | Paid` → `__loadSovPlaylist()`
- `config.contentType === Playlist` → `__loadCombinedPlaylist()`

---

### Path A — SOV Playlist (`__loadSovPlaylist`)

1. `GET player/playlist/current?from=[ISO8601_DATETIME]` — fetches current SOV schedule from fmcom-player-api
2. Receives `{ content: _Content1[], screenId, organizationId, timestamp, ... }`
3. Calls `_parsePlaylist(data)`

**What fmcom-player-api does with this request** (`PlaylistServiceImpl.getCurrentForScreen`):
1. Checks if organization is end-of-life → returns EOL content
2. Checks if screen is locked or doesn't meet brand requirements → returns brick-mode content
3. Otherwise: calls `PlaylistCurrentServiceImpl.getCurrentPlaylist(screenId, offset, length)` (from fm-common → queries Elasticsearch)
4. Rewrites content URLs via `ContentUtils.updatePlaylistUrls()`

---

### Path B — Combined/Custom Playlist (`__loadCombinedPlaylist`)

1. `GET player/custom-playlist/all` → list of all available playlists
2. Determines which playlist IDs to load (selected or all)
3. For each playlist ID: `GET player/custom-playlist/{playlistId}`
4. Merges content arrays
5. For DYNAMIC slots (brand content): `GET player/custom-playlist/brand/{brandId}?size={count}`
6. Filters out unfilled dynamic slots: `playlist = playlist.filter(c => c?.content?.contentType)`
7. Calls `_parsePlaylist(data)`

---

### Playlist Parsing (`_parsePlaylist`)

For each content item, based on `contentType`:

| Type | Action |
|---|---|
| VIDEO | Creates `VideoContent { url, duration, subtitleUrl, qrLink, ctaText }` |
| ALBUM | Expands each picture into `PictureContent { url, duration: albumDuration/count }` |
| YOUTUBE | Creates `YoutubeContent { videoId, embedUrl }` |
| Unknown | Logged as warning, item skipped |

**Final step:**
```
playbackController.setPlaylist(newPlaylist)
  → __playlist = newPlaylist
  → setContentIndex(0)            ← resets to first item
  → playlistLastUpdated = new Date()
```

---

## Step 7 — Player loads and plays content

**Content rendering:**
- Video: native HTML5 `<video>` element, direct MP4 URL
  - `videoTag.load()` → `videoTag.play()`
  - **No HLS/DASH:** the player uses HTTP progressive download via CloudFront CDN. The browser fetches the MP4 and begins playing as bytes arrive over standard HTTP. There is no adaptive bitrate streaming, no manifest file, and no specialized streaming player library required. A standard web developer can work on video playback in this codebase.
  - Subtitles: separate `fetch(subtitleUrl)` → parse as VTT → create blob → attach via `<track>`
- Picture: displayed for calculated duration, then next item
- YouTube: loaded in iframe with `autoplay=1`

**On content change** (`VideoPlayer.vue`, `contentChanged()`):
1. `stop()` — pauses, clears subtitle tracks
2. `stateChanged(PlaybackState.None)` — resets state
3. `play()` — loads new URL and plays
4. `reportState()` — sends state to watchdog

---

## Step 8 — Watchdog monitors playback

**`playbackWatchdog.ts`** runs a heartbeat every 500ms:

| Threshold | Action |
|---|---|
| 5 seconds no state change | `playerStuck = true` |
| 10 seconds | `pressNext()` — skip to next content item |
| 20 seconds | `resetPlaylist()` → `reloadCurrentPlaylist()` — refetch from server |
| 30 seconds | `resetApp()` → full page reload (`window.location.reload()`) |

**Watchdog reset condition:** Video player reports a state change hash `"${state}/${type}/${title}/${time}/${duration}"` that differs from the previous tick. If the hash stays the same (video truly frozen), the watchdog advances its counter.

**Buffering suppression:** While in Buffering state, the watchdog timer does NOT reset — it keeps counting. But the watchdog does not trigger if `state === Paused`.

**Watchdog and playlist reload integration** (`PlayerScreen.vue`):
```js
watchEffect(() => {
  if (playbackWatchdog.playlistResetRequired && playbackController.isDefault) {
    playlists.reloadCurrentPlaylist()  // Step 6 again
  }
})
```

---

## Complete Flow Diagram

```
Admin action (VAM/VPM API)
  │
  ▼
fmcom-api
  ├─ Persist to MySQL
  ├─ Apply throttle (PRO=1s, PLUS=30s, FREE=skip)
  ├─ Feign call to State Service (screen validation)
  └─ Publish to ActiveMQ:
       PLAYER_SCREEN_CONTENT_PENDING ──────────────────────────┐
       RNF_MEDIA_PROCESSING ─────────────────────────────────┐ │
                                                             │ │
  ▼                                                         │ │
ActiveMQ broker ◄────────────────────────────────────────────┘─┘
  │
  ▼
RNF (reach-n-freq)
  ├─ Generates playlist (timeout: 30min org / 5min screen)
  ├─ Transcodes video via FFmpeg → S3/CloudFront
  └─ Publishes to State Service broker:
       PLAYER_ORGANIZATION_CONTENT_UPDATED ──────────────────┐
       PLAYER_CONTENT_TRANSCODED ────────────────────────────┤
       PLAYER_CONTENTS_TRANSCODED_BATCH ────────────────────┐│
       API_CONTENT_ADD → back to fmcom-api ────────────────┘││
                                                            ││
  ▼                                                        ││
State Service (in-memory JMS broker)  ◄─────────────────────┘┘
  │  at-most-once delivery, 22s long-poll, lost on restart
  │
  ▼
fmcom-player-api
  ├─ PLAYER_ORGANIZATION_CONTENT_UPDATED
  │    └─ Query all screens for org
  │    └─ Send CONTENT_CHANGED via WebSocket to each screen
  ├─ PLAYER_CONTENT_TRANSCODED
  │    └─ Clear quarantine flags in Redis for content
  └─ PLAYER_CONTENTS_TRANSCODED_BATCH
       └─ Same as above, async batch
         │
         │ If device online: WebSocket CONTENT_CHANGED message
         │ If device offline: UnsentNoticeService (in-memory, 30s TTL)
         │
  ▼
html5core player (device)
  ├─ Receives CONTENT_CHANGED via WebSocket
  ├─ reloadCurrentPlaylist()
  │    ├─ Clear current playlist immediately (setPlaylist([]))
  │    ├─ Determine mode (SOV or Combined)
  │    ├─ Fetch from server:
  │    │    SOV: GET player/playlist/current
  │    │    Combined: GET player/custom-playlist/all + /brand/{id}
  │    └─ Parse and set new playlist (setPlaylist, setContentIndex(0))
  ├─ Load content (HTML5 video.load() / video.play())
  └─ Watchdog monitors (5s→skip, 20s→reload playlist, 30s→page reload)
```

---

## Conditional Paths That Alter the Happy Path

| Condition | What changes |
|---|---|
| Screen tier is FREE or LOCKED | fmcom-api skips notification entirely; device never receives CONTENT_CHANGED |
| Throttle window active (30s for PLUS) | Notification deferred; device gets update later |
| State Service unavailable | RNF JVM exits on next ping; all in-flight playlist generations lost |
| RNF generation timeout | Returns null silently; device never gets the update |
| Device offline > 30s | Unsent notice expires; device misses CONTENT_CHANGED; will next sync on reconnect or watchdog reload |
| Device in consultation mode | `reloadCurrentPlaylist()` silently skipped until consultation ends |
| Another reload already in progress | Second call silently skipped (`__currentPlaylistLoading` guard) |
| API fetch fails (network error) | `apiRequest()` returns `{}`; `_parsePlaylist` receives empty data; `setPlaylist([])` called again (empty stays empty) |
| Content type unknown | Item skipped silently during `_parsePlaylist`; no error thrown |
| Video fails to play | `@error` event → `PlaybackState.Error`; watchdog triggers skip after 10s |
| Player frozen (watchdog) | 10s→skip, 20s→full playlist reload, 30s→page reload |
