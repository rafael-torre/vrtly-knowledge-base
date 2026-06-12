---
title: "Telemetry 80% Coverage — Evaluation"
owner: "Tech Lead"
status: in_progress
last_updated: 2026-06-12
relates_to:
  - layers/layer-3-architecture/intermediate/telemetry-analysis-html5core.md
  - layers/layer-3-architecture/intermediate/telemetry-feasibility-assessment-html5core.md
  - layers/layer-3-architecture/intermediate/playlist-update-flow-html5core.md
  - layers/layer-3-architecture/intermediate/blank-screen-scenarios.md
---

# Telemetry 80% Coverage — Evaluation

**Audit question:** Map what specifically needs to be built to get to 80% telemetry coverage, and whether that is realistic given where things stand today.

**Scope:** html5core fleet. Roku and Android are out of scope for this evaluation; they will require equivalent analysis once their repos are available.

---

## Current state: ~0% diagnostic coverage

Today, when a device goes blank, there is no telemetry signal that identifies why. The only observable event in most cases is the PlaybackWatchdog firing 20 seconds after the blank has already occurred — a recovery mechanism, not a diagnostic one. It does not distinguish between a normal reload, a failed fetch, a dropped CONTENT_CHANGED, or a reload loop. All blank screen incidents look identical in the current telemetry.

This is not primarily a gap in volume of logs. It is a gap in the right signals at the right moments. Across 10 kill zones and 11 instrumentation gaps identified in the technical analysis, two structural problems dominate:

1. **`sendIssue()` in html5core is dead code.** `src/store/serverLogger.ts:38` has an unconditional `return` that makes the entire server-side error reporting channel a no-op. This is the single highest-leverage finding: restoring it is a one-line fix that re-enables a purpose-built channel designed for exactly this use case.

2. **The player blanks the screen before it knows what to show next.** `setPlaylist([])` is called before the HTTP fetch begins on every reload. The blank window — from the moment CONTENT_CHANGED arrives until the new playlist loads — produces no telemetry signal. This happens on every successful reload too, not just failed ones. On an org-wide fanout (one admin action causing all devices in the org to reload simultaneously), this blank window is multiplied across the entire fleet with zero visibility.

---

## What needs to be built

### The minimum to reach 80%

All of the work required for 80% coverage of the common blank screen scenarios is in html5core. No backend infrastructure changes are needed to reach this threshold.

**Fix first (prerequisite — no new instrumentation works without this):**

| Change | File | What it does |
|---|---|---|
| Restore `sendIssue()` | `src/store/serverLogger.ts:38` | Re-enables the error reporting channel. One-line fix. |
| Verify telemetry backend persists events | fmcom-player-api `TelemetryController` | Confirm events emitted by the device are received and stored before writing new ones. |

**Instrument the blank screen window (highest frequency scenarios):**

| Signal | Where | What it covers |
|---|---|---|
| `content_changed_received` | N6 — WebSocket handler | Confirms the device received the update signal |
| `playlist_cleared` + `playlist_loaded` | N6a — before/after fetch | Makes the blank window visible; enables duration measurement |
| `playlist_fetch_failed` with HTTP status | N6a/N6b — at moment of failure | Replaces the 20s watchdog as the first signal on fetch failure |
| `content_changed_dropped_consults` | N6a — consultation guard | Covers the consultation mode silent drop |
| `content_changed_dropped_concurrent` | N6a — concurrent guard | Covers the concurrent reload silent drop |

**Fill remaining gaps (less frequent but currently invisible):**

| Signal | Where | What it covers |
|---|---|---|
| `unknown_content_type` per discarded item | N6d — `_parsePlaylist` | Detects silent blank from unrecognized content type |
| Filter removal event in combined playlist | N6c | Detects silent blank from unfilled dynamic slots |
| `cause` field in WATCHDOG payload | N8 | Distinguishes watchdog triggers: empty playlist, fetch failed, frozen content |
| `consecutive_resets` field + server-side alarm | N8 | Detects destructive reload loops |

**Fix the telemetry buffer (prevents signal loss during connectivity gaps):**

| Change | What it does |
|---|---|
| FIFO cap on localStorage buffer + priority flush on WebSocket reconnect | Prevents unbounded accumulation and eviction of telemetry during extended offline periods |

### What does not reach 80% in 1 month

Eight backend kill zones remain unaddressed in this scope. They affect less frequent but severe failure modes:

| Scenario | Required fix | Why it's out of 1-month scope |
|---|---|---|
| fmcom-api crash between DB commit and JMS send | Outbox pattern in MySQL | Backend infrastructure change |
| State Service OOM-kill loses PLAYER_* messages in flight | Persistent Amazon MQ for PLAYER_* | Infrastructure change |
| Device client eviction by State Service broker | Persistent offset in Redis | Backend change |
| Device offline >30s, UnsentNotice TTL expires | UnsentNotice persistence in Redis | Backend change |
| RNF generation timeout — silent | CloudWatch metric + alarm | Infrastructure change |
| Transcoding failure — no TRANSCODE_FAILED event | Dead-letter queue + publish on failure path | Backend change |
| FREE/LOCKED tier suppression — no log | INFO log on suppression in fmcom-api | Backend change |
| Phantom reload from ES write failure | Gate PLAYER_*_UPDATED on ES write success | Backend change |

These are candidates for a phase 2 of instrumentation work.

---

## Is 1 month realistic?

**Yes — with two hard conditions.**

### Condition 1: The 80% is measured against device-side scenarios

The common blank screen scenarios — fetch failure, consultation drop, concurrent drop, unknown content type, org-wide fanout blank window — all originate in html5core and are covered by the instrumentation plan above. If the 80% target includes backend kill zones, the achievable number in 1 month is 50–60%, because those require infrastructure changes across multiple services.

**Unvalidated assumption — requires data before this condition is defensible:** This condition rests on the claim that device-side scenarios represent the majority of blank screen incidents. That proportion has never been quantified with production data. If backend kill zones (RNF timeout, State Service OOM-kill, cross-node ECS failures) account for more than 20% of incidents, the 80% target cannot be reached with html5core changes alone. A breakdown of observed incidents by origin type (device-side vs. backend-originated) is needed to confirm this condition holds before committing to the 1-month scope.

### Condition 2: The deployment cycle works without staging

There is no reliable staging environment. Every player change ships to production. With 1 QA person, the bottleneck is not writing the code — it is verifying in real devices that events are emitted, that they arrive at the telemetry backend, and that they contain the right context. Estimated development time is 2 weeks. The remaining 2 weeks must be budgeted for verified releases.

If QA can validate a batch of changes every 3–4 days, 3–4 releases are feasible in the month. That is enough to ship all the changes above if they are grouped well. If the release cycle is slower, the month fills with deployment overhead before the instrumentation is complete.

### What would make the estimate fail

- The telemetry backend (`TelemetryController`) discards events silently — instrumenting html5core would produce no observable coverage gain.
- QA capacity is consumed by unrelated work, reducing available release slots.
- The `sendIssue()` fix is delayed — it is the prerequisite for the error channel that powers the highest-value events.
- Scope expands to include Roku or Android, which have no existing analysis.

---

## Summary

| Question | Answer |
|---|---|
| What % of blank screen failures are covered today? | ~0% at time of blank. The watchdog fires at 20s but does not identify the cause. |
| What needs to be built to reach 80%? | 1 one-line fix (KZ-1), 9 telemetry events in html5core, 1 buffer cap. All device-side. |
| Is 1 month realistic? | Yes, if 80% is scoped to device-side scenarios and the deployment cycle can support 3–4 verified releases. |
| What is the main constraint? | Not the code — the deployment cycle without staging and with 1 QA person. |
| What stays out of scope? | 8 backend kill zones requiring infrastructure changes. Phase 2. |