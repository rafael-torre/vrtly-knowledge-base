---
title: "General Playback Lifecycle — html5core (boot → steady-state)"
owner: "Tech Lead"
status: in_progress
last_updated: 2026-06-15
relates_to:
  - layers/layer-3-architecture/intermediate/tech-spike-html5core-player.md
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-player-api.md
  - layers/layer-3-architecture/intermediate/tech-spike-state-service.md
  - layers/layer-3-architecture/intermediate/html5core-playlist-update-flow.md
---

# General Playback Lifecycle — html5core (boot → steady-state)

Neutral end-to-end map of the html5core player lifecycle from device boot through to steady-state looping playback, with no content update in transit. Covers boot, registration, initial playlist fetch, WebSocket establishment, content rendering, the watchdog loop, and the conditional paths for reconnection and item failure.

This document does not analyze logging coverage. It describes what each component does and how they connect, including the data that travels between them and the conditional paths that matter most.

Scope: html5core fleet. Roku and Android are out of scope.

---

## Overview

```
Device boots
  → Cordova shell loads html5core app bundle from S3/CloudFront
  → App.vue initializes: device detection → activation check → config fetch
  → Player fetches initial playlist from fmcom-player-api
  → Player establishes WebSocket connection to fmcom-player-api
  → Player loads and plays first content item
  → Steady-state: loops through playlist, watchdog monitors, telemetry flushes
  → WebSocket idle — server sends only periodic HEARTBEAT
  → [Conditional] WebSocket drop → auto-reconnect after 1000ms
  → [Conditional] Item fails to load → watchdog skips after 10s
```

---

## N0 — Device boot

The physical device (FireTV/Cordova, webOS, Tizen, iOS, or browser) boots its OS. For the primary html5core target — Amazon FireTV — the Cordova shell (`cordova-player` repo) starts and loads the html5core app bundle from its configured S3/CloudFront origin.

The shell provides the WebView runtime. Before delegating to the Vue app, the platform-specific home page stub in `public/` (one per platform: FireTV, webOS, Tizen, iOS, web) loads the platform SDK (Cordova bridge, webOS SDK, Tizen SDK, or iOS WKWebView bridge). The Cordova bridge exposes `window._cordovaNative`, which the device store uses later to read device UUID, model, platform, and shell version.

**Data leaving N0:** control transfers to the Vue app entry point.

---

## N1 — App initialization (main.ts)

`src/main.ts` is the Vue app entry point:

1. Creates the Vue application and registers Pinia as the global state manager
2. Registers `vue-youtube` (YouTube player manager)
3. Registers the `v-grid-item` directive (D-pad navigation)
4. Registers `GlobalFocusPlugin` (remote-control focus management)
5. Mounts `App.vue` as the root component

**No network calls at this point.** Pinia stores initialize lazily on first access.

---

## N2 — Device detection (device.ts)

`src/store/device.ts` implements a strategy pattern: it probes for the available platform SDK in order and selects the matching `DeviceImpl`:

| Probe | DeviceImpl selected |
|---|---|
| `window._cordovaNative` present | `CordovaDevice` (FireTV) |
| `window.webkit.messageHandlers` present | `iOSDevice` |
| `window.tizen` present (hosted) | `TizenHostedDevice` |
| `window.tizen` present | `TizenDevice` |
| `webOSTV.js` SDK available | `webOSDevice` |
| None of the above | `BrowserDevice` |

Each implementation provides: device serial number (UUID), model name, platform string, OS version, and shell/app version. These values are included in every subsequent API request signature.

**Data produced:** `deviceSerial`, `deviceModel`, `platform`, `osVersion`, `shellVersion` — held in Pinia state.

---

## N3 — Server environment selection (currentApiServer.ts)

`src/store/currentApiServer.ts` reads from localStorage to determine which environment (PROD / ALPHA / DEV / QA) the app should connect to. On a production FireTV device this is always PROD; the environment is determined at deploy time from which S3 bucket served the app bundle (`html5core` vs `html5core-beta`, detected from `window.location.href`).

This store provides the URL roots used by all subsequent network calls: `http`, `ws`, `wss`, `api`, `qr`, `app`.

**Data produced:** base URLs for all subsequent API and WebSocket calls. Persisted across page reloads via localStorage.

---

## N4 — Activation check / Registration (checkActivation.ts → fmcom-player-api)

`src/store/checkActivation.ts` polls `POST player/registerDevice` every 3 seconds until registration is confirmed.

**Request parameters** (from `src/utils/api.ts` `apiRequest()`):
- `X-Serial` header: device serial number
- `timestamp` query param: current epoch ms
- `signature` query param: `SHA-1(serialNumber + timestamp)` (lexicographic sort of the two strings before concatenation)

**Server-side handling** (fmcom-player-api `RegistrationServiceImpl`):
- Interceptor chain: `RateLimitInterceptor` → `SecurityInterceptor` (validates SHA-1 signature, 300s expiry window) → `SessionInterceptor` → `ScreenInterceptor`
- If device MAC is unknown in MySQL: generates and returns a pairing code → App.vue shows Activation screen with QR code and waits
- If device MAC is known and enabled: returns `{ secret, config }` — session secret for subsequent requests + initial config payload

**App state machine (App.vue):**
- Before activation: `ActivationScreen` (shows pairing QR code)
- After activation code scanned by admin and device registered: next poll returns secret → transitions to `WelcomeScreen` briefly, then `ConnectedScreen`
- Activation loops every 3s until confirmed; no timeout or giveup implemented

**Data produced:** `sessionSecret` (stored in Pinia memory only, not persisted to localStorage — lost on page reload), `config` payload.

**Conditional — device is already registered (normal boot):**
First poll immediately returns secret + config. State machine transitions directly past the activation screens to Connected.

---

## N5 — Config fetch (config.ts → fmcom-player-api)

`src/store/config.ts` fetches `GET player/config`:

**What config contains:**
- `contentType`: `Free | Paid | Playlist` — determines which playlist loading path is used
- `overridePlaybackMode`: `Shuffle | SelectedPlaylist` — overrides contentType for mode selection
- Organization and screen metadata

**Server-side:** `PlayerController.getConfig()` returns org/screen config from MySQL (via state-service lookup).

This store also watches `contentType` — if it changes (e.g., subscription upgrade received via WebSocket `CONFIG` message later), it triggers a fresh `loadPlaylists()` call.

**Data produced:** `config` object in Pinia, specifically `contentType` and `overridePlaybackMode` which control the next step.

---

## N6 — Initial playlist fetch (playlists.ts → fmcom-player-api)

`src/store/playlists.ts` selects the load path based on config:

| Condition | Method |
|---|---|
| `overridePlaybackMode === Shuffle` | `__loadSovPlaylist()` |
| `overridePlaybackMode === SelectedPlaylist` | `__loadCombinedPlaylist()` |
| `config.contentType === Free` or `Paid` | `__loadSovPlaylist()` |
| `config.contentType === Playlist` | `__loadCombinedPlaylist()` |

### Path A — SOV Playlist (`__loadSovPlaylist`)

1. `GET player/playlist/current?from=[ISO8601_DATETIME]`
2. Receives `{ content: _Content1[], screenId, organizationId, timestamp, ... }`
3. Calls `_parsePlaylist(data)`

**Server-side** (`PlaylistCurrentServiceLocal`):
1. Checks if org is end-of-life → returns EOL content
2. Checks if screen is locked or doesn't meet brand requirements → returns brick-mode content
3. Otherwise: calls `PlaylistCurrentServiceImpl` from fm-common → queries Elasticsearch for the scheduled playlist
4. Rewrites all content URLs via `ContentUtils.updatePlaylistUrls()` (CloudFront signing, quality cap application, escalation stage routing)

### Path B — Combined/Custom Playlist (`__loadCombinedPlaylist`)

1. `GET player/custom-playlist/all` → list of all playlists for the screen
2. Determines which playlist IDs to load (selected or all, based on `overridePlaylistId`)
3. For each playlist ID: `GET player/custom-playlist/{playlistId}`
4. Merges content arrays from all playlists
5. For DYNAMIC slots (brand content): `GET player/custom-playlist/brand/{brandId}?size={count}`
6. Filters out unfilled dynamic slots: `playlist = playlist.filter(c => c?.content?.contentType)`
7. Calls `_parsePlaylist(data)`

### Playlist Parsing (`_parsePlaylist`)

Converts raw server response into typed content objects:

| `contentType` | Output type | Key fields |
|---|---|---|
| `VIDEO` | `VideoContent` | `url` (CloudFront signed MP4), `duration`, `subtitleUrl`, `qrLink`, `ctaText` |
| `ALBUM` | `PictureContent[]` | One item per picture; `duration = albumDuration / pictureCount` |
| `YOUTUBE` | `YoutubeContent` | `videoId`, `embedUrl` |
| Unknown | — | Item silently skipped; warning logged |

**Final step:**
```
playbackController.setPlaylist(newPlaylist)
  → __playlist = newPlaylist
  → setContentIndex(0)          ← always starts at first item
  → playlistLastUpdated = new Date()
```

**Data produced:** `__playlist: Content[]` in `playbackController`, ready for rendering.

**Blank screen risk — N6:** `setPlaylist([])` is called immediately before the fetch begins (clears old playlist). The screen goes blank and stays blank until `setPlaylist(newPlaylist)` completes. If the fetch fails, `apiRequest()` returns `{}`, `_parsePlaylist` produces an empty array, and `setPlaylist([])` is called again — screen remains blank.

---

## N7 — WebSocket establishment (websocket.ts → fmcom-player-api)

WebSocket connection is initiated when `PlayerScreen.vue` mounts (i.e., after the app transitions into the Player screen state, which requires N4–N6 to have succeeded).

**Connection initiation:**
```
websocket.start()
  → new WebSocket(`wss://{server}/ws?mac={mac}&platform={platform}&model={model}&resolution={w}x{h}&signature={sha1}&timestamp={ts}`)
```

**Server-side interceptor chain on handshake:**
1. `WsSessionCapInterceptor` — rate limiting on WebSocket connections
2. `WsRateLimitInterceptor` — per-device connection rate limit
3. `WsSecurityInterceptor` — validates SHA-1 signature from query params
4. `WsSessionInterceptor` — loads or creates device session from `SessionHolder`
5. `WsScreenInterceptor` — resolves screen record from state-service

On successful handshake: `BaseWebSocketHandler` registers the session via `WebSocketMgmtService`. The session is stored in `WsSessionHolder` (`ConcurrentHashMap<MAC, ConcurrentWebSocketSessionDecorator>`) on the node that accepted the connection.

**Note — node locality:** fmcom-player-api runs on ECS with multiple replicas. `WsSessionHolder` is in-memory and node-local. There is no distributed session replication. The device's WebSocket connection is tied to one specific ECS node. HTTP requests from the same device may land on a different node — cross-node sends fall back to `UnsentNoticeService`.

**Steady-state WebSocket heartbeat:**
- Device sends `HEARTBEAT` message every 30 seconds; server responds
- If server does not receive a heartbeat within the session inactivity timeout, it closes the connection
- Sessions checked every 10 minutes for inactivity

**Data produced:** `WebSocketSession` registered in `WsSessionHolder` on one player-api node. Device is now reachable for server-push commands (`CONTENT_CHANGED`, `CONFIG`, `HEARTBEAT`, `REPORT`, `DISCONNECT`).

---

## N8 — First content item loads and plays

`playbackController.ts` holds `__playlist` and `__contentIndex`. The active component (`PlayerScreen.vue`) renders the appropriate content player based on `currentContent.type`:

### VIDEO path

`VideoPlayer.vue`:
1. Receives `VideoContent { url, duration, subtitleUrl }`
2. `videoTag.load()` — browser initiates HTTP progressive download of MP4 from CloudFront
3. `videoTag.play()` — playback starts as bytes arrive (no HLS/DASH; no manifest; no specialized player library)
4. If `subtitleUrl` present: `fetch(subtitleUrl)` → parse as VTT → create blob URL → attach via `<track>` element
5. On play: `stateChanged(PlaybackState.Playing)` → `reportState()` (notifies watchdog)
6. On buffer: `stateChanged(PlaybackState.Buffering)` → watchdog timer does NOT reset
7. On end (`@ended`): `stateChanged(PlaybackState.None)` → playbackController advances to next item

### PICTURE path

`PicturePlayer.vue`:
1. Receives `PictureContent { url, duration }`
2. Displays image for `duration` milliseconds via a countdown timer
3. On timer expiry: playbackController advances to next item

### YOUTUBE path

`YoutubePlayer.vue`:
1. Receives `YoutubeContent { videoId, embedUrl }`
2. Renders YouTube iframe with `autoplay=1` via `@vue-youtube/core`
3. Duration controlled by YouTube player events

---

## N9 — Steady-state: playlist loop

After the first item plays, `playbackController` advances to the next item via `setContentIndex(currentIndex + 1)`. At the end of the playlist it wraps to index 0. This loop continues indefinitely.

**What happens on each item transition:**

| Action | Store | Mechanism |
|---|---|---|
| Advance content index | `playbackController` | `setContentIndex(n)` → reactive update triggers content player swap |
| Report upcoming schedule | `plan.ts` | `GET player/plan` — sends next 10 items as `PlanElement[]` to server on every index change |
| Watchdog state hash reset | `playbackWatchdog` | Content player calls `reportState()` with new hash; watchdog counter resets to 0 |
| Telemetry event queued | `telemetryQueue` | `Playback` telemetry event written to localStorage buffer |
| Content start recorded | `playedContentReport` | `HistoryElement` written to localStorage |

**Telemetry flush (telemetryQueue):**
- Buffer: localStorage, batched
- Flush triggers: batch size reaches 30 items OR 5-minute timer fires
- Transport: WebSocket send (if open)
- If WebSocket is closed: buffer accumulates without bound — no size cap, no TTL

**Content report flush (playedContentReport):**
- Transport: `POST report/content` HTTP endpoint
- Flush triggers: 7-minute timer OR WebSocket `REPORT` command from server
- Buffer: localStorage

**Auto-update check (autoUpdate.ts):**
- On every playlist reload (not on a timer), fetches `GET /build.json`
- Compares `build_hash` against the current bundle's hash
- If different: `window.location.reload()` — applies the new app version opportunistically

---

## N10 — Watchdog monitoring (playbackWatchdog.ts)

`playbackWatchdog.ts` runs a heartbeat loop every **500ms**. It computes a state hash:
```
hash = `${state}/${type}/${title}/${time}/${duration}`
```
If the hash is unchanged from the previous tick, a stall counter increments.

| Stall duration | Action |
|---|---|
| 5 seconds | Sets `playerStuck = true` (observable flag only) |
| 10 seconds | `pressNext()` — advances to next content item |
| 20 seconds | `resetPlaylist()` → `reloadCurrentPlaylist()` — full playlist refetch from server |
| 30 seconds | `resetApp()` → `window.location.reload()` — full page reload |

**Suppression rules:**
- If `state === Paused`: watchdog counter does NOT increment (intentional pause is not a stall)
- If `state === Buffering`: watchdog counter DOES increment (buffering can lead to a stall)

**Integration with playlist reload:**
```js
// PlayerScreen.vue
watchEffect(() => {
  if (playbackWatchdog.playlistResetRequired && playbackController.isDefault) {
    playlists.reloadCurrentPlaylist()
  }
})
```

When watchdog triggers a playlist reload (20s threshold), this re-enters the flow at N6.

---

## N11 — WebSocket idle (no pending update)

During steady-state playback with no admin-triggered content change:

- State-service broker has no messages queued for fmcom-player-api instances
- player-api's long-poll on the state-service broker (`POST /broker/consume`, 22s hold) returns empty
- player-api sends no commands to the device beyond HEARTBEAT responses
- Device sends HEARTBEAT every 30 seconds; server responds
- The only traffic on the WebSocket is the HEARTBEAT ping/response cycle

This is the baseline: the connection stays open and alive, no playlist changes are triggered.

---

## Conditional Path A — WebSocket drop and reconnection

**Trigger:** Network interruption, server-side session timeout, player-api node restart, or DISCONNECT message.

**Device side (websocket.ts):**
1. `@close` or `@error` event fires on the WebSocket object
2. `websocket.ts` schedules a reconnect after **1000ms**
3. After 1000ms: re-enters N7 (new WebSocket connection attempt with fresh handshake)
4. On successful reconnect: session re-registered in `WsSessionHolder`

**Server side (player-api) — during the gap:**
- Previous `WsSessionHolder` entry for the device MAC is stale (session closed)
- Any `CONTENT_CHANGED` message pushed to this device during the gap:
  - `WebSocketMessagingService.send()` finds no open session → falls through to `UnsentNoticeService.registerUnsentNotice(mac, group, message)`
  - `UnsentNoticeService` holds the message in memory with a **30-second TTL**
  - Cleaned up every 10 seconds

**On reconnect delivery:**
- New `register()` call at handshake → `UnsentNoticeService` delivers any pending messages
- If the device was offline for more than 30 seconds: the unsent notice has expired; device misses the `CONTENT_CHANGED` entirely
- The device will only pick up the content change on the next watchdog-triggered reload (20s or 30s thresholds) or on the next admin-triggered update

**Telemetry during disconnect:**
- Telemetry events continue accumulating in localStorage
- No flush occurs until WebSocket reconnects
- No size cap on the localStorage buffer — extended outages accumulate without bound

---

## Conditional Path B — Item fails to load

**Trigger:** Video `@error` event (network error, corrupted file, CloudFront URL expiry, decode failure).

**Device side:**
1. `VideoPlayer.vue` `@error` handler fires
2. `stop()` — pauses and clears subtitle tracks
3. `stateChanged(PlaybackState.Error)` — reports error state to watchdog
4. `reportState()` — state hash sent to watchdog; hash includes `PlaybackState.Error`

**Watchdog response:**
- State hash is stable (Error state, no progress) → counter increments at 500ms ticks
- At 10 seconds: `pressNext()` — advances to the next item in the playlist
- Next item begins loading; watchdog counter resets on state change

**If all items fail:**
- Watchdog `pressNext()` fires every 10s per item
- Each item that also errors repeats the cycle
- At 20 seconds of a stalled state: `resetPlaylist()` → `reloadCurrentPlaylist()` — fetches fresh playlist from server (re-enters N6)
- At 30 seconds: `window.location.reload()` — full page reload (re-enters N0)

**Server side — escalation:**
Decode failures are reported via telemetry (`ContentPlaybackEscalationRule` in player-api). After a configurable threshold of failures on a specific `(screen, content)` pair, player-api advances the escalation ladder:
```
HLS_FULL → HLS_720 → SRC_ORIGINAL → SRC_720 → SRC_540 → QUARANTINE
```
On the next playlist fetch (triggered by watchdog), `ContentUtils.updatePlaylistUrls()` will return a different variant URL for that content item. The player transparently receives the downgraded URL — it never negotiates this itself.

---

## Conditional Path C — Initial playlist fetch fails

**Trigger:** Network unavailable at boot, player-api unreachable, or API returns error.

**Device side (playlists.ts):**
1. `setPlaylist([])` is called immediately before the fetch (clears any prior playlist)
2. `apiRequest()` fails → returns `{}`
3. `_parsePlaylist({})` → produces empty `Content[]`
4. `playbackController.setPlaylist([])` → blank screen

**Watchdog response:**
- With an empty playlist, playbackController has no items to advance
- State hash is `None/undefined/undefined/0/0` — unchanged at every tick
- At 20 seconds: `resetPlaylist()` → `reloadCurrentPlaylist()` — re-enters N6 (another fetch attempt)
- At 30 seconds: `resetApp()` → `window.location.reload()` — re-enters N0

The device loops through this until it can reach player-api and fetch a non-empty playlist.

---

## Complete Flow Diagram

```
Device boots (FireTV, webOS, Tizen, iOS, Browser)
  │
  ▼ N0
Cordova shell → loads html5core app bundle from S3/CloudFront
  │
  ▼ N1
main.ts → Pinia init → App.vue mounts
  │
  ▼ N2
device.ts → platform probe → selects DeviceImpl (Cordova/iOS/Tizen/webOS/Browser)
  │           reads: serial, model, platform, osVersion
  ▼ N3
currentApiServer.ts → reads localStorage → selects PROD/ALPHA/DEV/QA base URLs
  │
  ▼ N4
checkActivation.ts → POST player/registerDevice (every 3s)
  ├─ UNKNOWN device: returns pairing code → show Activation QR → wait for admin
  └─ KNOWN device: returns { secret, config } → proceed
         │
         │ security:         SHA-1(serialNumber + timestamp), 300s window
         │ interceptors:     RateLimit → Security → Session → Screen
         ▼ N5
config.ts → GET player/config → { contentType, overridePlaybackMode, orgMeta }
  │
  ▼ N6
playlists.ts → initial playlist fetch
  ├─ setPlaylist([])  ← blank screen starts here
  ├─ SOV: GET player/playlist/current → server: Elasticsearch → URL rewrite → CloudFront signing
  ├─ Combined: GET player/custom-playlist/all → per-playlist → merge → brand slots
  ├─ _parsePlaylist() → Content[] (VIDEO / PICTURE / YOUTUBE)
  └─ setPlaylist(newPlaylist), setContentIndex(0)
  │
  ▼ N7
websocket.ts → PlayerScreen.vue mounts
  → new WebSocket(wss://player.vrtly.ai/ws?mac=&platform=&model=&resolution=&signature=&timestamp=)
  │   server: WsSessionCap → WsRateLimit → WsSecurity → WsSession → WsScreen → WsSessionHolder
  │
  ▼ N8
playbackController → renders first content item
  ├─ VIDEO: videoTag.load() → videoTag.play() → HTTP progressive download from CloudFront
  ├─ PICTURE: display image for duration ms
  └─ YOUTUBE: iframe autoplay=1
  │
  ▼ N9
Steady-state loop: item ends → setContentIndex(n+1) → wrap at end → repeat
  ├─ plan.ts: POST player/plan (next 10 items) on every index change
  ├─ telemetryQueue: Playback event → localStorage buffer → flush @30 items or 5min via WebSocket
  ├─ playedContentReport: HistoryElement → localStorage → POST report/content @7min or REPORT command
  ├─ autoUpdate.ts: GET /build.json on every playlist reload → reload if hash differs
  └─ HEARTBEAT every 30s: device → server → response
  │
  ▼ N10/N11
Watchdog (500ms ticks) + WebSocket idle
  ├─ Hash unchanged 10s → pressNext()
  ├─ Hash unchanged 20s → reloadCurrentPlaylist() [re-enters N6]
  ├─ Hash unchanged 30s → window.location.reload() [re-enters N0]
  └─ WebSocket: HEARTBEAT only; state-service broker has no queued messages for this device

[Conditional A — WebSocket drop]
  ├─ @close/@error → 1000ms → reconnect (re-enters N7)
  ├─ During gap: UnsentNoticeService holds CONTENT_CHANGED for 30s
  └─ If gap > 30s: unsent notice expires; device misses update

[Conditional B — Item fails to load]
  ├─ @error → PlaybackState.Error → watchdog 10s → pressNext()
  └─ If all fail: 20s → reloadCurrentPlaylist(), 30s → page reload

[Conditional C — Initial playlist fetch fails]
  ├─ apiRequest() returns {} → setPlaylist([]) → blank screen
  └─ Watchdog 20s → reloadCurrentPlaylist(), 30s → page reload
```

---

## Conditional Paths Summary

| Condition | What changes |
|---|---|
| Device not yet registered (first boot) | checkActivation returns pairing code; app shows QR; loops until admin registers device |
| Device session secret lost (page reload) | Must re-register; secret is in-memory only (Pinia), not persisted — but known device re-registers immediately |
| Initial config fetch fails | App likely stays in Connected/loading state; no playlist attempt |
| Initial playlist fetch fails | Screen blank; watchdog fires at 20s (reload playlist) and 30s (page reload) |
| Playlist returns empty content | Same as fetch failure; screen stays blank until watchdog |
| Unknown content type in playlist | Item silently skipped; no error thrown |
| WebSocket handshake fails | No WS connection; device receives no server-push commands; content still loops from last playlist |
| WebSocket drops, back online < 30s | Reconnects; unsent CONTENT_CHANGED delivered on register |
| WebSocket drops, offline > 30s | Unsent notice expired; device misses CONTENT_CHANGED; next sync on watchdog reload |
| Video fails to play | PlaybackState.Error → watchdog skips at 10s → next item |
| All items fail repeatedly | Watchdog cycles through skip (10s) → playlist reload (20s) → page reload (30s) |
| Buffering stalls indefinitely | Watchdog counts buffering as stall → same 10s/20s/30s progression |
| Consultation mode active | `reloadCurrentPlaylist()` skipped until consultation ends; playlist updates missed during consult |
| Auto-update detects new build | `window.location.reload()` on next playlist reload — re-enters N0 |
| player-api node serving WebSocket goes down | WebSocket drops → Conditional Path A; if reconnect lands on different node, WsSessionHolder is fresh (no prior state on new node) |