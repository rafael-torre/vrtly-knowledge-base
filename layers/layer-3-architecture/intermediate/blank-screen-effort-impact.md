---
title: "Blank Screen Scenarios — Effort vs Impact Prioritization"
owner: "Tech Lead"
status: in_progress
last_updated: 2026-06-12
relates_to:
  - layers/layer-3-architecture/intermediate/blank-screen-scenarios.md
  - layers/layer-3-architecture/intermediate/html5core-telemetry-feasibility-assessment.md
  - layers/layer-3-architecture/intermediate/html5core-telemetry-analysis.md
---

# Blank Screen Scenarios — Effort vs Impact Prioritization

This document scores each of the 25 blank-screen scenarios from the risk register against two axes — **impact** and **effort** — to produce a prioritized list and identify the clearest first action.

---

## Scoring Method

| Axis | Low | Medium | High |
|---|---|---|---|
| **Impact** | Rare / few screens / stale content | Moderate frequency or some screens blank | Frequent / all-org blast radius / persistent blank |
| **Effort** | 1 repo, targeted code change, no infra | 2–3 repos or moderate refactor | Multi-repo + infra or architectural change |

---

## Prioritization Matrix

| ID | Name | Impact | Effort | Priority |
|---|---|---|---|---|
| **S-20** | Clear-before-fetch gap blanks screen on every reload | 🔴 HIGH | 🟢 LOW | **#1** |
| **S-21** | `encodeURIComponent` bug corrupts signed URLs | 🟠 MED-HIGH | 🟢 LOW | **#2** |
| **S-1** | RNF crash via State Service ping loss | 🔴 HIGH | 🟡 MED | **#3** |
| **S-19** | Org-wide fanout causes unnecessary reload for all screens | 🔴 HIGH | 🟡 MED | **#4** |
| **S-11** | `fm-common` version skew causes silent ES quota corruption | 🟠 MED-HIGH | 🟡 MED | **#5** |
| **S-22** | Consultation mode silently drops `CONTENT_CHANGED` | 🟡 MED | 🟢 LOW | **#6** |
| **S-12** | Device re-registration loop after watchdog reload | 🟡 MED | 🟢 LOW | **#7** |
| **S-14** | Redis escalation state permanent (no TTL) | 🟡 MED | 🟢 LOW | **#8** |
| **S-3** | Playback watchdog reload loop on dead playlist endpoint | 🔴 HIGH | 🟡 MED | **#9** |
| **S-8** | Generation timeout produces no schedule (silent) | 🟡 MED | 🟡 MED | **#10** |
| **S-24** | `UnsentNotice` 30s TTL drops `CONTENT_CHANGED` for offline devices | 🟡 MED | 🟡 MED | **#11** |
| **S-2** | ABR escalation reaches QUARANTINE with no recovery path | 🟡 MED | 🟡 MED | **#12** |
| **S-6** | State Service outage cascades to ES quota fallback | 🔴 HIGH | 🔴 HIGH | **#13** |
| **S-16** | XXL-Job admin outage stops all playlist generation | 🔴 HIGH | 🔴 HIGH | **#14** |
| **S-10** | Daily sweep silently skips screens under ES throttle | 🟡 MED | 🟡 MED | **#15** |
| **S-15** | ES write failure leaves playlist schedule stale | 🟡 MED | 🟡 MED | **#16** |
| **S-23** | In-memory WebSocket sessions lost across multi-node ECS | 🟡 MED | 🟡 MED | **#17** |
| **S-25** | FREE/LOCKED tiers never receive push notifications | 🟢 LOW | 🔴 HIGH | **#18** |
| **S-5** | State Service cold-start cache miss floods MySQL | 🟡 MED | 🔴 HIGH | **#19** |
| **S-4** | Transcoding failure — no playable content | 🟢 LOW | 🟡 MED | **#20** |
| **S-7** | JMS message loss prevents playlist regeneration | 🟡 MED | 🔴 HIGH | **#21** |
| **S-9** | EFS mount unavailability halts transcoding | 🟡 MED | 🔴 HIGH | **#22** |
| **S-13** | Bad content manifest triggers quarantine | 🟢 LOW | 🟡 MED | **#23** |
| **S-17** | In-process broker loses messages on OOM-kill | 🟡 MED | 🔴 HIGH | **#24** |
| **S-18** | Deployment write storm saturates SyncOpService lock | 🟡 MED | 🔴 HIGH | **#25** |

---

## Rationale by Priority Tier

### 🔴 Tier 1 — Do First (High Impact, Low Effort)

**S-20 and S-21 are pure code fixes in `html5core-player` with no backend or infra coordination.**

**S-20 — Clear-before-fetch (#1)**
Every call to `reloadCurrentPlaylist()` fires `setPlaylist([])` before the network request begins. This is guaranteed by design — the blank window is not conditional on a failure. It fires on every `CONTENT_CHANGED` WebSocket push, every 20s watchdog threshold, and every `CONFIG` message. When the fetch succeeds, the blank window equals the network roundtrip. When it fails (for any reason — S-1, S-6, S-19, the fetch times out), the screen stays blank for 20 more seconds until the next watchdog cycle. Fixing this one pattern reduces the observable severity of at least eight other scenarios.

Fix: fetch-then-swap. Issue `GET /player/playlist/current`, and only call `setPlaylist(newPlaylist)` on success. On failure, keep the current playlist; let the watchdog handle genuine stalls via `pressNext`.

**S-21 — `encodeURIComponent` bug (#2)**
The hand-rolled encoder in `src/utils/api.ts` replaces only the *first* occurrence of each reserved character. When a query parameter value contains the same character twice (e.g., two `+`, two `&`), the encoded URL does not match the SHA-1 signature and the server rejects the request. The device then enters the S-20 failure path — blank screen, watchdog loop, no self-recovery. This may be latent today, but it is a ticking-clock defect requiring a one-line native replacement.

Fix: replace hand-rolled encoder with `window.encodeURIComponent` in `src/utils/api.ts`.

---

### 🟠 Tier 2 — Next Sprint (High Impact, Medium Effort)

**S-1 — RNF crash on State Service ping loss (#3)**
`FeignConfig.connectionCheck()` in `reach-n-freq` calls `System.exit(-1)` with no retry or backoff on the first ping failure. Any transient State Service hiccup — restart, network blip, health-check flap — terminates the RNF JVM and leaves all playlist delivery broken until ECS restarts the container. Fix is scoped to `reach-n-freq`: replace `System.exit(-1)` with a retry + exponential backoff; only exit after N consecutive failures.

**S-19 — Org-wide fanout (#4)**
`PLAYER_ORGANIZATION_CONTENT_UPDATED` triggers `CONTENT_CHANGED` to *every* screen in the org, not only the affected one. In a large organization, a single admin content change creates a simultaneous blank window across all connected devices. After S-20 is fixed, this is less catastrophic (screens show stale content during fetch rather than going blank), but the unnecessary disruption remains. Fix in `fmcom-player-api`: per-screen content-hash diffing to suppress `CONTENT_CHANGED` when the fetched playlist would be identical to the current one.

**S-11 — `fm-common` version skew (#5)**
State Service runs `fm-common` 8.7.8 while all other services run 8.9.x. The 8.9.x series introduced typed `JmsDestination<T>` with new DTO fields. Jackson's default `FAIL_ON_UNKNOWN_PROPERTIES = false` means State Service silently drops new fields from 8.9.x payloads, producing wrong Elasticsearch quota allocations fleet-wide. Fix: bump `fm-common` in `state-service` to 8.9.x and run regression tests on ES quota coordination.

---

### 🟡 Tier 3 — Batch as Improvements (Medium Impact, Low-Medium Effort)

**S-22 (#6)** — Deferred `CONTENT_CHANGED` delivery when `isConsults === true`: queue the update, deliver on consultation exit.

**S-12 (#7)** — Add circuit breaker to `ScreenStateClient` in `fm-common`: prevents registration blocking indefinitely on State Service latency.

**S-14 (#8)** — Add TTL to Redis escalation keys in `fmcom-player-api`: a 7–14 day TTL lets transient-network-induced escalations recover automatically.

**S-3 (#9)** — Smarter watchdog backoff + local content cache in `html5core-player`: this is non-trivial (IndexedDB or localStorage playlist store), but S-20 reduces the frequency of watchdog-triggered reload loops first.

**S-8 (#10)** — Emit a metric (not just a log line) on generation timeout in `reach-n-freq`, and add a retry pass for timed-out screens.

**S-24 (#11)** — Extend `UnsentNotice` TTL from 30s and add per-device playlist version tracking for reconnect scenarios.

**S-2 (#12)** — Alert when a screen's playlist shrinks to zero; add auto-retranscode trigger on quarantine.

---

### ⚠️ High Impact but Architecturally Expensive

**S-6 (#13)** and **S-16 (#14)** have high impact but require State Service architectural work (SPOF for ES quota) and XXL-Job redundancy (SPOF for all scheduled tasks). These should be scoped as separate architectural initiatives, not quick fixes.

---

### 🔵 Tier 4 — Defer or Verify First

**S-23 (#17)**: Verify whether ALB sticky sessions are already configured (open question OQ3 in the risk register) before building cross-node session sharing.

**S-25 (#18)**: Intentional business logic — tier-based throttling is by design. Only requires mitigation if FREE/LOCKED screens have frequent unplayable content in their daily window.

**S-5, S-7, S-9, S-17, S-18 (#19–25)**: Infrastructure-level or architectural-level changes with medium-to-low probability of directly causing blank screens in isolation. Address after Tier 1–3 are complete.

---

## Summary: First Action

> **Fix S-20 in `html5core-player`.**
>
> Change `reloadCurrentPlaylist()` in `src/store/playlists.ts` to fetch first, then swap the playlist only on a non-empty successful response. This eliminates the guaranteed blank-screen window on every single reload and reduces the severity of at least eight other documented scenarios. It requires no backend changes, no infrastructure coordination, and carries minimal regression risk.
>
> Batch with S-21 and S-22 in the same `html5core-player` PR.