# Telemetry & Observability Survivability Analysis — html5core Player

**Scope:** html5core player and the delivery chain that supports it. Roku and Android out of scope.
**Purpose:** Assess what telemetry exists, how it is transported, and where it fails to survive — with specific focus on blank screen scenarios.
**Related:** `possible-blank-screen-causes.md`, `playlist-flow-map.md`, `tech-spike-html5core-player.md`

---

## What telemetry exists

The html5core player has a structured telemetry system (`src/store/telemetry/`). Events are typed and queued locally before being sent to the backend via WebSocket.

### Event types

| Type | What it captures |
|---|---|
| `DEVICE_INFO` | Device ID, platform, model, app version, resolution, user agent |
| `INTERACTION` | User actions: play, pause, next, previous, captions, playlist selection |
| `PLAYBACK` | Playback state changes with contentId, contentType, timeSinceStartPlay, contentTime |
| `WATCHDOG` | Watchdog interventions: `SKIP_NEXT`, `RESET_PLAYLIST`, `RESET_APP` |
| `CONNECTION_STATE` | Network and WebSocket events: errors, disconnects, reconnects |
| `Application` | **Not implemented.** `//todo: implement` placeholder in source — dead. |

### Transport mechanism

1. Events are serialized and stored in `localStorage` under key `telemetryQueue`
2. Flush is triggered when: queue has **>30 events** AND device is **online** AND **WebSocket is open**
3. A 5-minute interval also attempts to flush — same online + WS open conditions required
4. Playback events use a separate `localStorage` key (`telemetryPlaybackQueue`), batched per contentId/contentType, flushed on content change

**Transport dependency:** All telemetry delivery requires an open WebSocket session. If the WebSocket is closed, events accumulate in localStorage but are never sent until reconnection.

---

## Where telemetry survives

Under normal conditions — player online, WebSocket open, content playing — the telemetry system works:

- Every playback state change emits a `PLAYBACK` event
- Watchdog interventions emit `WATCHDOG` events
- Connection events (socket drop, reconnect) emit `CONNECTION_STATE` events
- localStorage acts as a buffer across short connectivity gaps; events survive page reloads and reconnect when WS is restored

---

## Where telemetry does not survive

### Gap 1 — `PlaybackState.None` is deliberately filtered out

`sendPlaybackTelemetry()` has an explicit filter:

```ts
if (newState != PlaybackState.None) {
    // emit PLAYBACK telemetry
}
```

`PlaybackState.None` is the state the player enters immediately when `setPlaylist([])` is called — the moment the blank screen begins. This state was treated as "uninitialized / not interesting" and excluded from telemetry.

**Consequence:** No telemetry event fires at the exact moment the screen goes blank. The blank is invisible to the telemetry system.

This affects: **B2** (clear-before-fetch gap), **B3** (fetch failure leaves empty playlist).

---

### Gap 2 — No telemetry covers playlist lifecycle events

There is no telemetry type for:
- `reloadCurrentPlaylist()` triggered (what caused it: CONTENT_CHANGED, watchdog, CONFIG?)
- `setPlaylist([])` called (blank screen starts)
- API fetch result (success / failure / empty response)
- `setPlaylist(newPlaylist)` called (blank screen ends)
- fetch failure details (HTTP status, URL, error type)

The system knows **what content is playing** but has no record of **the reload cycle** that precedes each content load. Blank screens live entirely in this unobserved window.

---

### Gap 3 — API fetch failures are silently swallowed

`apiRequest()` returns `{}` on any error — network error, HTTP 4xx/5xx, malformed response. No exception is thrown. No `CONNECTION_STATE` event or error telemetry is emitted.

**Consequence:** A playlist fetch failure leaves no trace. The blank screen persists, the watchdog fires at 20s, and the `WATCHDOG: RESET_PLAYLIST` event is emitted — but it carries only `contentId`, not the reason the reload was triggered in the first place. The causal chain is broken.

This affects: **B3** (fetch failure), **B4** (encodeURIComponent bug corrupts URL — server rejects silently).

---

### Gap 4 — `serverLogger` is dead code

`serverLogger.ts` (`sendIssue()`) has an unconditional `return` on line 38. All server-side error reporting from the player is disabled. If any code path calls `serverLogger.sendIssue()`, the call is accepted and silently discarded.

**Consequence:** Even if a future code change attempted to log a blank screen event server-side, it would not be delivered. This must be fixed before any server-side observability is meaningful.

---

### Gap 5 — CONTENT_CHANGED dropped during consultation is not telemetered

When `reloadCurrentPlaylist()` is called with `isConsults === true`, it returns immediately. No telemetry event records that an update was silently discarded. After consultation ends, the screen continues playing stale content with no observable signal.

This affects: **B5** (consultation mode silently drops CONTENT_CHANGED).

---

### Gap 6 — Telemetry queue blocked when WebSocket is closed

If the WebSocket is closed (device disconnected, B7 session miss, B8 TTL expiry), telemetry accumulates in localStorage but is never flushed. During the exact window when a blank screen is most likely (connectivity issues, missed CONTENT_CHANGED), telemetry delivery is also degraded.

The queue does persist across page reloads — so `WATCHDOG: RESET_APP` triggering a full page reload does not lose previously queued events. But those events still require WS reconnect to send.

---

## The core structural problem

The telemetry system was designed to answer: **"what content is this device playing, and for how long?"**

It was not designed to answer: **"why is this device showing a blank screen?"**

The blank screen occurs in the gap between `setPlaylist([])` and `setPlaylist(newPlaylist)`. This gap is:
- Not a recognized error state (`PlaybackState.None` is filtered)
- Not covered by any telemetry type
- Not recoverable from `WATCHDOG` events alone (which fire after the gap, with no causal context)

By the time any observable signal exists (`WATCHDOG: RESET_PLAYLIST` at 20s, or `WATCHDOG: RESET_APP` at 30s), the information that would explain the blank — what triggered the reload, what the fetch returned, whether the URL was valid — is already gone.

---

## Summary: telemetry coverage by blank screen cause

| Cause | Blank moment logged? | Recovery moment logged? | Causal context preserved? |
|---|---|---|---|
| B2 — Clear-before-fetch gap | No (PlaybackState.None filtered) | WATCHDOG at 20s | No |
| B3 — Fetch failure → empty playlist | No | WATCHDOG at 20s | No |
| B4 — encodeURIComponent bug | No | WATCHDOG at 20s | No — corrupt URL not logged |
| B5 — Consultation mode drops update | No | No | No |
| B6 — serverLogger dead | — | — | All server-side logging disabled |
| B7 — Multi-node session miss | CONNECTION_STATE on reconnect | Partial | No — missed push not logged |
| B8 — UnsentNotice TTL expiry | CONNECTION_STATE on reconnect | Partial | No — expired notice not logged |
| B1 — Org-wide fanout | No (same gap as B2) | WATCHDOG if blank persists | No |

---

## What telemetry DOES give us (and what it doesn't)

**Available today:**
- Confirmation that a watchdog fired and at what threshold (`WATCHDOG` events)
- What content was playing before the incident (`PLAYBACK` events)
- Whether the WebSocket dropped around the time of the incident (`CONNECTION_STATE`)
- Device identity and version context (`DEVICE_INFO`)

**Not available today:**
- When and why `reloadCurrentPlaylist()` was triggered
- Whether the playlist fetch succeeded or failed
- Duration of the blank screen (no start event, no end event)
- Whether a CONTENT_CHANGED was received and ignored (consultation) or never received
- Any server-side error log from the player (`serverLogger` dead)