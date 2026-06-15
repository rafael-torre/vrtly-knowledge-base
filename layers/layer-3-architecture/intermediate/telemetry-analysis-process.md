---
title: "Process: Telemetry Analysis per Player"
owner: "Sofia Collazzi"
status: draft
last_updated: 2026-06-15
relates_to: []
---

# Process: Telemetry Analysis per Player

Reusable guide for evaluating telemetry coverage feasibility for a given player (html5core, Roku, Android). Documented from the process followed with html5core.

## Scope and Key Definitions

- **"Player use case"** refers to the device type being analyzed (e.g., html5core), not just the player repo. The analysis covers the full system stack involved in that use case: backend (fmcom-api, RNF, state-service), intermediate APIs (fmcom-player-api), and the player itself.
- **80% coverage** means: the blank screen moment is logged in 80% of blank-screen scenarios, and that logged data is sufficient to diagnose the incident without physical device inspection. This is the operative test — a finding is "covered" when an operator can identify what happened and why from telemetry alone. Implementing the findings from Step 1 is the means; blank-moment logging and diagnosability is the goal.

  Architectural findings (those requiring structural redesign, not just instrumentation) count toward the total but are not implementable within a one-month horizon; their distribution matters because they are not evenly spread — they tend to concentrate on the content delivery path.

  **Stale-content scenarios:** some scenarios do not produce a device-side blank screen. The device continues playing old content because an update never arrived (e.g., broker OOM-kill, UnsentNotice TTL expiry, JMS message loss). There is no blank moment to log on the device for these scenarios. They are **not part of the blank-screen coverage denominator**.

  These scenarios are covered by a separate metric — **content delivery coverage** — tracked via server-side signals: delivery confirmation (did the backend receive acknowledgment that the device applied the update?), absence alerts (a device that should have received an update but did not confirm it), and UnsentNotice expiry counters. This metric is operationally important because stale content can become unplayable (removed video, quarantined item), causing a blank screen later whose causal origin is no longer visible without this signal.

  The fixes for content delivery coverage are backend instrumentation findings — they do not require player changes and can be deployed independently. Present them as a separate coverage section in the synthesis document, not mixed with blank-screen coverage.
- **`blank-screen-scenarios.md`** is one input for identifying failure points and mapping them to nodes in the system with no telemetry or where the signal does not survive. The scenarios are hypothetical — developed during investigation as a working model of what can go wrong — not confirmed failure causes in production. They are not the denominator for the 80% target.
- **Language:** all output documents must be written in English.

---

## Backend analysis and subsequent players

The full backend analysis (fmcom-api, RNF, state-service, fmcom-player-api) is performed once, during the first player analysis (html5core). When analyzing a subsequent player (Roku, Android), **do not repeat the backend analysis**. Instead, in Step 1, check only whether the new player's specific behavior has any impact on backend telemetry already analyzed — for example: a different WebSocket mechanism, a different content format, a different long-poll interval, or a player-side behavior that changes what the backend can observe. If an impact is found, document it as a delta, not as a full re-analysis.

---

## Prerequisite: Tech Spikes

Tech spikes for all relevant repos must exist before starting:

| Repo | Type |
|---|---|
| Player (html5core / Roku / Android) | Player — primary source |
| fmcom-api | Backend |
| fmcom-player-api | Backend |
| rnf | Backend |
| state-service | Backend |
| fm-common | Backend |
| component-library | Frontend shared |
| cordova-player | Player wrapper |

> The player's tech spike is the primary source for any questions about playback behavior, telemetry flush, WebSocket, or content logic on the device. The others apply when the analysis touches that specific component.

> **General rule — spikes and repos:** In any step, if the tech spike does not cover what is needed, go directly to the local repo. Spikes are the first source; the repo is the fallback.

> `tech-spike-vrtly-fe-monorepo.md` is excluded — it covers the CMS web, not device telemetry.

---

## Step 0A — General Playback Lifecycle Flow

**Goal:** Map the player's lifecycle from boot to steady-state playback, with no content update in progress. This flow covers nodes that the update flow does not: initial boot, playlist fetch from fmcom-player-api, WebSocket setup, playback loop, item transitions, reconnection, and playback error recovery.

**Reference flow to validate and complete:**
```
Device boots
  → Player initializes
  → Player fetches initial playlist from fmcom-player-api
  → Player establishes WebSocket connection to fmcom-player-api
  → Player loads content (video/image items), begins playback
  → Steady-state: loops through playlist items, handles transitions
  → WebSocket idle (no pending updates)
  → [Reconnection: WebSocket drop and recovery]
  → [Error path: item fails to load, player recovery behavior]
```

**Sources (read in order):**
1. `layers/layer-3-architecture/intermediate/tech-spike-{player}.md` — primary source: boot, initial fetch, WebSocket, PlaybackState, localStorage, loop logic
2. `layers/layer-3-architecture/intermediate/tech-spike-fmcom-player-api.md` — for the initial fetch endpoint and WebSocket setup
3. `layers/layer-3-architecture/intermediate/tech-spike-state-service.md` — for connection handling during idle
4. Local repos to go deeper where spikes are insufficient

**Output:** Document with the flow steps, data traveling between components, each node's decisions, and conditional paths (what happens if the initial fetch fails, what happens if the WebSocket drops during idle, what happens if a playlist item fails to load).

**Output file:** `layers/layer-3-architecture/intermediate/{player}-playlist-playback-flow.md`
_(html5core example: `layers/layer-3-architecture/intermediate/html5core-playlist-playback-flow.md`)_

Complete the frontmatter when creating the document; `relates_to` must reference everything consulted during execution.

**Done when:** The document describes step-by-step the player lifecycle from boot to steady-state, including conditional error and reconnection paths — with no logging analysis yet.

---

## Step 0B — Playlist Update Flow

**Goal:** Map the end-to-end flow of what happens when an admin updates content: from the change in VAM/VPM to the device loading and playing the new content. No logging analysis yet — just what each component does and how they connect.

The API/backend portion is largely reusable across players; what changes is the player-side behavior.

**Reference flow:**
```
Admin updates content in VAM/VPM
  → fmcom-api processes the change
  → fmcom-api publishes JMS (RNF_GENERATE / RNF_MEDIA_PROCESSING)
  → RNF generates playlist and transcodes content
  → RNF publishes JMS (PLAYER_CONTENT_TRANSCODED / PLAYER_CONTENTS_TRANSCODED_BATCH)
  → State Service broker distributes messages
  → fmcom-player-api receives via long-poll (22s)
  → fmcom-player-api notifies device via WebSocket
  → Player receives CONTENT_CHANGED, reloads content, plays
```

**Sources (read in order):**
1. `layers/layer-3-architecture/intermediate/tech-spike-fmcom-api.md`
2. `layers/layer-3-architecture/intermediate/tech-spike-rnf.md`
3. `layers/layer-3-architecture/intermediate/tech-spike-state-service.md`
4. `layers/layer-3-architecture/intermediate/tech-spike-fmcom-player-api.md`
5. `layers/layer-3-architecture/intermediate/tech-spike-{player}.md`
6. Local repos to go deeper where spikes are insufficient

**Output file:** `layers/layer-3-architecture/intermediate/{player}-playlist-update-flow.md`
_(html5core example: `layers/layer-3-architecture/intermediate/html5core-playlist-update-flow.md`)_

**Done when:** The document describes step-by-step what each component does, the data flowing between them, and the most relevant conditional paths — with no logging analysis yet.

> **Note for subsequent players (Roku, Android):** The backend portion of this flow (fmcom-api → RNF → state-service → fmcom-player-api) does not need to be re-documented unless the new player's behavior changes something in that path. Focus on the player-side nodes and note any backend delta if found.

---

## Step 1 — `/investigate`: Kill Zones and Instrumentation Gaps

**Goal:** For each node across both flows (playback lifecycle + content update), identify what information is definitively lost on failure and whether it can be recovered or approximated with instrumentation changes. The analysis covers the full stack — backend and player — for the use case being evaluated.

**Central question:**
> For each node in the general playback flow and the content update flow for the `{player}` use case, what information is definitively lost on failure — and can it be recovered or approximated with instrumentation changes?

**Sources (read in order):**
1. `layers/layer-3-architecture/intermediate/{player}-playlist-playback-flow.md` — nodes of the general lifecycle
2. `layers/layer-3-architecture/intermediate/{player}-playlist-update-flow.md` — nodes of the content update path
3. `layers/layer-3-architecture/intermediate/blank-screen-scenarios.md` — read the "Missing" section of each scenario and map it to the node where it occurs (playback flow or update flow, as appropriate). Use as evidence per node, not as the organizing structure.
4. `layers/layer-3-architecture/intermediate/tech-spike-{player}.md` — for any detail on flush behavior, WebSocket, PlaybackState, playback logic

> **Note for subsequent players (Roku, Android):** Do not re-analyze backend telemetry. Instead, check whether this player's specific behavior introduces any delta in what the backend can observe (e.g., different WebSocket protocol, different content handling, different reconnection behavior). Document any backend delta found; otherwise focus the investigation on player-side nodes.

**Two dimensions to analyze per node:**

- **Kill zones:** the code attempts to log but the signal does not survive (OOM pre-flush of localStorage buffer, WebSocket closed during flush, crash before drain).
- **Uninstrumented paths:** the code never attempts to log because that path is not modeled as a failure (the problem exists but nobody tries to log it).

**Expected output:**

1. Table per node (both flows): `Flow | Node | Signal attempted today | Survives? | Reason | Fixable? | Alternative signal`
2. Separate section: blank screen paths with no signal at all
3. Coverage table per scenario: was the moment of blank logged? / was the recovery logged? / was causal context preserved?
4. Responsibility distribution table: total findings by category (kill zones / instrumentation gaps), how many are fixable, and of those how many require changes in the player vs. in the backend. This makes the workload distribution explicit before the roundtable.

**Output files:**
- Case file: `layers/layer-3-architecture/intermediate/investigation/{player}-telemetry-investigation.md`
  _(html5core example: `layers/layer-3-architecture/intermediate/investigation/html5core-telemetry-investigation.md`)_
- Canonical document: `layers/layer-3-architecture/intermediate/{player}-telemetry-analysis.md`
  _(html5core example: `layers/layer-3-architecture/intermediate/html5core-telemetry-analysis.md`)_

Complete the frontmatter in both documents; `relates_to` must reference both flow docs, blank-screen-scenarios, and the tech spikes consulted.

**Done when:** Analysis covers all nodes from both flows with both dimensions separated, the section on paths with no signal is present, the per-scenario coverage table is complete with three evaluation columns, the responsibility distribution table is present, and `{player}-telemetry-analysis.md` exists with the full node table including the `Flow` column.

---

## Step 2 — `/roundtable`: 80% Feasibility Evaluation

> **Note:** the 80% is measured against the findings inventory from Step 1 (kill zones + gaps identified), not against the scenario list in `blank-screen-scenarios.md`. See definition in Scope and Key Definitions.

**Participants:** Winston (architect) + Amelia (dev), moderated by John (PM).

**Central question:**
> Based on the kill zones and instrumentation gaps analysis from Step 1 (covering both flows and the full system stack), is it viable to reach 80% telemetry coverage across the full system for the `{player}` use case? In how long? And if viable, what team is needed to execute it in 1-2 months?

The roundtable must consider that 80% means much more than adding logs. The analysis identified two types of obstacles:
- **Kill zones:** signals that do not survive — require structural changes (flush strategy, heartbeat, server-side proxy).
- **Gaps:** paths not modeled as failures — require new instrumentation or flow refactoring.

**Questions to answer:**
1. Given the kill zone map across both flows, what percentage of blank screen failures are structurally loggable? How many require architectural changes in the backend vs. in the player?
2. Given the gap map across both flows, how covered are the known failure paths? How many gaps are simple to instrument vs. how many require refactoring?
3. What realistic combination of signals (device-side + server-side + heartbeat absence) can reach 80% across the full system, given team constraints and no reliable staging environment?
4. What limits the 80% most: kill zones, gaps, or the team's capacity to execute the structural changes required?
5. If 80% is viable, what team profile is needed (roles, headcount) to execute it in 1-2 months? What conditions would change that estimate?

**Input sources:**
- `layers/layer-3-architecture/intermediate/{player}-telemetry-analysis.md`
- `layers/layer-3-architecture/intermediate/{player}-playlist-playback-flow.md`
- `layers/layer-3-architecture/intermediate/{player}-playlist-update-flow.md`
- `layers/layer-3-architecture/intermediate/blank-screen-scenarios.md`
- Tech spikes as needed, especially `tech-spike-{player}.md`

**Output file:** `layers/layer-3-architecture/intermediate/{player}-telemetry-feasibility-assessment.md`
_(html5core example: `layers/layer-3-architecture/intermediate/html5core-telemetry-feasibility-assessment.md`)_

---

## Step 3 — Synthesis

Consolidate all outputs into a single document that directly answers the audit question:

> "Map what specifically needs to be built to get there, and whether that is realistic given where things stand today."

**Inputs:**
- `layers/layer-3-architecture/intermediate/{player}-telemetry-analysis.md`
- `layers/layer-3-architecture/intermediate/{player}-telemetry-feasibility-assessment.md`

**Output file:** `layers/layer-1-product/intermediate/audit/{player}-telemetry-80pct-evaluation.md`
_(html5core example: `layers/layer-1-product/intermediate/audit/html5core-telemetry-80pct-evaluation.md`)_

**Two coverage metrics — treat separately:**

The synthesis document must distinguish between:

1. **Blank-screen coverage (80% target):** was the blank moment logged? The denominator is scenarios where the device actually goes blank. Stale-content scenarios are excluded from this denominator because no device-side blank event occurs as a direct result of those failures.

2. **Content delivery coverage (complementary metric):** did the backend register that it did not receive confirmation the device applied the update? Stale-content scenarios belong here. This metric matters because stale content can become unplayable (removed or quarantined item), producing a blank screen later whose root cause is no longer traceable without this signal.

Present each metric with its own denominator, its own finding count, and its own timeline. Do not merge them into a single percentage.

---

## Summary

| Step | Tool | Output |
|---|---|---|
| 0A | Tech spikes + repos: map general player lifecycle | `layer-3-architecture/intermediate/{player}-playlist-playback-flow.md` |
| 0B | Tech spikes + repos: map content update flow | `layer-3-architecture/intermediate/{player}-playlist-update-flow.md` |
| 1 | `/investigate` (both flows, full stack) | `layer-3-architecture/intermediate/investigation/{player}-telemetry-investigation.md` → `layer-3-architecture/intermediate/{player}-telemetry-analysis.md` |
| 2 | `/roundtable` (Winston + Amelia + John) | `layer-3-architecture/intermediate/{player}-telemetry-feasibility-assessment.md` |
| 3 | Direct synthesis | `layer-1-product/intermediate/audit/{player}-telemetry-80pct-evaluation.md` |

Optional skills: `/review-adversarial` to stress-test the timeline claim, `/elicitation` to go deeper on any step.

---

## Extension: Combined Analysis (html5core + Roku + Android)

Once all three players are analyzed individually:

1. **Consolidate** a total feasibility assessment integrating the three player-level assessments.
2. **Contextualize the time target:** the 80% in 1-2 months goal is a working hypothesis, not a commitment. The synthesis should propose a realistic timeline per player and in aggregate, and the team profile needed to execute it.
3. Backend telemetry analysis is shared across players — it is done once (html5core) and extended only where a subsequent player introduces a delta.

**Completion criteria per player:** (1) what % of failures are covered today across the full system, (2) what needs to be built in which components to reach 80%, (3) whether the proposed timeline is viable and what team is needed — or what conditions would change the answer.