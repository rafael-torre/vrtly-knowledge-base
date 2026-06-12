# Blank Screen Causes — html5core Player

**Scope:** html5core player only. Roku and Android out of scope.
**Purpose:** Consolidated reference of known and suspected causes of blank screens or unnecessary playback interruptions on html5core devices. Sourced from architecture discovery, tech spikes, the pre-existing risk register, and flow analysis.
**Related:** `playlist-flow-map.md`, `pre-existing-risk-register.md`, `tech-spike-html5core-player.md`, `tech-spike-fmcom-player-api.md`

---

## How to read this document

Causes are grouped by where in the system they originate. Each cause includes:
- What triggers it
- How it manifests on the device
- Cross-references to the risk register where applicable

---

## Player Layer (html5core)

### B1 — Org-wide fanout: unnecessary reload for unaffected screens

**Trigger:** Any admin update to any screen in an organization.

**What happens:** `PLAYER_ORGANIZATION_CONTENT_UPDATED` is an org-level message. When fmcom-player-api receives it, it queries **all enabled screens in the org** and sends `CONTENT_CHANGED` to each one — regardless of whether a specific screen's content actually changed. Every screen reloads its playlist, clears its current content (`setPlaylist([])`), and resets to item 0.

**Manifestation:** Screens whose content was not updated still go blank, interrupt playback, and refetch the exact same content they were already playing. At scale — large orgs, frequent updates — this creates constant unnecessary disruption across all devices in the org.

**Note:** This is by design (org-level message granularity), not a bug. But it is a significant source of unnecessary blank screens.

---

### B2 — Clear-before-fetch gap

**Trigger:** Any `reloadCurrentPlaylist()` call — from `CONTENT_CHANGED`, from the watchdog, or from a `CONFIG` message.

**What happens:** The player immediately calls `setPlaylist([])` to clear the current playlist *before* making the network request to fetch the new one. The screen goes blank at that moment and stays blank until the server response arrives and `setPlaylist(newPlaylist)` is called.

```
setPlaylist([])        ← screen goes blank HERE
[network request]      ← blank during this entire window
setPlaylist(newList)   ← screen recovers here
```

**Manifestation:**
- Short blank (normal case): duration = network roundtrip time
- Long blank: if the server is slow or the device has poor connectivity
- Permanent blank (failure case): if the API fetch fails, `setPlaylist([])` was already called and nothing replaces it — screen stays blank until the watchdog fires at 20 seconds

**Source:** `playlists.ts` → `reloadCurrentPlaylist()` — `playbackController.setPlaylist([])` called before `__loadSovPlaylist()` / `__loadCombinedPlaylist()`

---

### B3 — Fetch failure results in empty playlist

**Trigger:** Network error or server error during `GET player/playlist/current` or `GET player/custom-playlist/*`.

**What happens:** `apiRequest()` returns `{}` on failure. `_parsePlaylist` receives empty data and produces an empty array. `setPlaylist([])` effectively gets called twice — the pre-fetch clear and then again with an empty result.

**Manifestation:** Blank screen with no error thrown. The watchdog is the only recovery mechanism: at 20 seconds it triggers another `reloadCurrentPlaylist()`, which starts the same cycle again.

---

### B4 — encodeURIComponent bug corrupts signed request URLs

**Trigger:** Any API request where a query parameter contains more than one reserved character (e.g., two `&` symbols, two `+` symbols, etc.).

**What happens:** The hand-rolled `encodeURIComponent` implementation in `src/utils/api.ts` only replaces the **first occurrence** of each reserved character. Subsequent occurrences are left unencoded. For signed requests (which use SHA-1 of the full URL), this produces a URL that doesn't match the signature — the server rejects it.

**Manifestation:** Playlist fetch fails silently → B3 applies → blank screen. The root cause is invisible without inspecting the network request.

**Source:** `src/utils/api.ts` (html5core)

---

### B5 — Consultation mode silently misses CONTENT_CHANGED

**Trigger:** `CONTENT_CHANGED` arrives while `playbackController.isConsults === true`.

**What happens:** `reloadCurrentPlaylist()` checks `isConsults` as its first guard and returns immediately. The update is lost — no retry is scheduled, no queuing happens.

**Manifestation:** After consultation ends, the screen continues playing the old playlist. Content changes made during consultation are never applied unless another `CONTENT_CHANGED` arrives or the watchdog triggers a reload.

---

### B6 — serverLogger is dead code — errors are invisible

**Trigger:** Any playback error that would have been reported to the server.

**What happens:** `serverLogger.ts` has an unconditional `return` on line 38 of `sendIssue()`. All server-side error logging is silently disabled. Errors occur, the function is called, and nothing is sent.

**Manifestation:** Not a direct blank screen cause — but it means blank screen events are not logged server-side, making them invisible in any observability tooling. Debugging requires client-side inspection only.

**Source:** `src/utils/serverLogger.ts` (html5core)

---

## Delivery Layer (fmcom-player-api)

### B7 — In-memory WebSocket sessions not safe for multi-node deployments

**Trigger:** `fmcom-player-api` running as multiple ECS task replicas without sticky sessions.

**What happens:** Device WebSocket sessions are stored in `WsSessionHolder` — an in-memory `ConcurrentHashMap`. When an HTTP request or message delivery lands on a node that does not hold the device's session, the push is silently queued in `UnsentNoticeService` rather than delivered.

**Manifestation:** Device never receives `CONTENT_CHANGED`. Content update is lost unless another notification arrives within the `UnsentNotice` TTL window (30 seconds), or the device reconnects.

**Risk register:** R2 — requires ALB sticky sessions or acceptance of silent message loss. OQ3 asks whether sticky sessions are configured in production.

---

### B8 — UnsentNotice 30-second TTL

**Trigger:** Device is offline or session is closed when `CONTENT_CHANGED` is sent.

**What happens:** The message is queued in `UnsentNoticeService` (in-memory, 30-second TTL, cleaned every 10 seconds). If the device does not reconnect and call `register()` within 30 seconds, the notice is discarded.

**Manifestation:** Device misses the update entirely. It will next sync only when the watchdog triggers a reload (20-second stall threshold) or when the next `CONTENT_CHANGED` arrives.

---

### B9 — Playback escalation ladder 30-minute grace window

**Trigger:** A content variant is quarantined and the system advances to a degraded fallback (e.g., `HLS_FULL → HLS_720 → SRC_ORIGINAL → ...`).

**What happens:** After each escalation step, a 30-minute "settle-grace" window prevents the system from detecting new failures on the new variant. If the new variant also fails, the device stays on a broken variant for up to 30 minutes before escalating further.

**Manifestation:** Persistent blank or error state on a specific content item for up to 30 minutes. The watchdog skips the item at 10 seconds, but the playlist will keep returning to it until the escalation ladder advances.

---

## Message Delivery Layer (State Service)

### B10 — At-most-once delivery: messages lost on restart

**Trigger:** State Service restart, crash, or OOM-kill while messages are in flight.

**What happens:** State Service holds messages in memory only. A restart wipes all undelivered messages. fmcom-player-api connects via HTTP long-poll with a 22-second hold — any messages in flight during a restart are gone.

**Manifestation:** RNF completes a playlist generation, publishes `PLAYER_ORGANIZATION_CONTENT_UPDATED`, but the message never reaches fmcom-player-api. No device receives `CONTENT_CHANGED`. Content update is silently lost.

---

### B11 — 5-minute inactivity eviction

**Trigger:** fmcom-player-api misses its long-poll for 5 minutes (e.g., network interruption, deployment).

**What happens:** State Service evicts the client. Messages published during the gap are lost.

**Manifestation:** Same as B10 — `CONTENT_CHANGED` never reaches any device until the next update cycle.

---

## Playlist Generation Layer (RNF)

### B12 — State Service unavailable kills RNF

**Trigger:** State Service is down when RNF performs its 1-minute ping check.

**What happens:** RNF calls `System.exit(-1)`, killing the JVM and all in-flight playlist generations.

**Manifestation:** All active playlist generation jobs are lost. No `PLAYER_ORGANIZATION_CONTENT_UPDATED` is published. No devices update until RNF restarts and reprocesses.

**Risk register:** A3 — RNF is a critical dependency; its failure behavior cascades to all devices.

---

### B13 — RNF generation timeout

**Trigger:** Playlist generation exceeds 5 minutes (per screen) or 30 minutes (per org).

**What happens:** RNF silently returns null. No message is published to State Service.

**Manifestation:** Device never receives `CONTENT_CHANGED`. The content update is silently dropped with no retry.

---

### B14 — FREE and LOCKED tiers never notified

**Trigger:** Admin updates content for a FREE or LOCKED screen.

**What happens:** fmcom-api applies subscription-based throttling and skips the notification entirely for FREE and LOCKED tiers. No JMS message is published to ActiveMQ. RNF never runs for that screen.

**Manifestation:** Device never receives `CONTENT_CHANGED`. This is intentional business logic, not a bug — but it can appear as a blank screen if the device has lost its last valid playlist (e.g., after a page reload with an empty server response).

---

## Summary Table

| ID | Layer | Cause | Recovery |
|---|---|---|---|
| B1 | Player | Org-wide fanout — all screens reload on any org update | N/A (by design) |
| B2 | Player | Clear-before-fetch gap (`setPlaylist([])` before network) | Watchdog at 20s |
| B3 | Player | Fetch failure returns empty playlist | Watchdog at 20s |
| B4 | Player | encodeURIComponent bug corrupts signed URLs | Watchdog at 20s |
| B5 | Player | Consultation mode silently drops CONTENT_CHANGED | Next update or watchdog |
| B6 | Player | serverLogger dead — errors invisible server-side | No recovery (observability gap) |
| B7 | Delivery | In-memory sessions not safe for multi-node ECS | Sticky sessions (OQ3) |
| B8 | Delivery | UnsentNotice 30s TTL — offline device misses update | Watchdog or next update |
| B9 | Delivery | Escalation ladder 30-min grace window | Auto-escalation after grace period |
| B10 | State Service | At-most-once delivery — restart loses messages | Next update cycle |
| B11 | State Service | 5-min eviction — client gap loses messages | Next update cycle |
| B12 | RNF | State Service unavailable kills RNF JVM | RNF restart |
| B13 | RNF | Generation timeout — null returned silently | Next update cycle |
| B14 | RNF | FREE/LOCKED tiers never notified | Intentional; no recovery |