# Vrtly — Product Demo + Q&A Session Prep

**Purpose:** Preparation guide for the product demo and Q&A session with Joe and David.
**Context:** We have access to the vendor brief, the May 26 call transcript, pre-call Q&A answers, the Q1 2025 investor pitch deck, and the 2026 brand partnerships deck. This document maps what we already know, what the demo should surface, and what to ask in the Q&A.

**Key stakeholders likely in the room:**

- **Joe Schooler** — CPO/CTO (background: Apple, Amazon, Google). Wrote the Netflix-based QoE strategy doc. Primary technical and product contact. Will assess peer-level thinking.
- **David Perez** — Principal Designer (background: Apple, Zoom). Raised QA state and activation funnel concerns on the May 26 call.
- **Sergei Vareyko** — Principal Engineer (background: Altir, Nuance Comms, Gulf Relay). May be present for the technical portion.

---

## Section 1 — Product Demo

The demo is not a courtesy walkthrough. It is the first real access we get to the system as a user and an operator. Use it to observe specific things rather than just watching.

### What to ask Joe to show

**Device lifecycle — from activation to playback:**

- The full activation flow for a new screen: 
  - Walk us through what happens when a new practice comes on board — from the moment they're added to the system, through picking which brands they want to show and building out a playlist, all the way to content actually playing on a physical screen. What does that full flow look like?
- What does the screen look like during normal playback — what's shown, is there anything running in the background?
- What happens when a playlist finishes, does it loop?

**Failure simulation:**

- Go into the dev menu and trigger a simulated failure — any kind: network drop, stalled playback, corrupt asset
- Show what happens on the device side and what, if anything, appears in the Kibana dashboard at that moment
- Ask explicitly: *does triggering a failure here produce any event in telemetry?*

**Telemetry dashboard:**

- Open the Kibana dashboard that CS uses — the one Joe described as "incomplete and hard to use"
- What does a healthy device look like in that dashboard?
- What does a device that just had a WebSocket drop look like?
- Is there any way to see, from this dashboard, that a screen has been blank for 10 minutes?

**CS tooling:**

- Show us what CS sees when a practice calls in about a blank screen
- What data is available to CS at that moment without escalating to engineering?
- Is there any device-level status (last heartbeat, last event, current playlist) visible to CS?
- *(New flag from brand partnerships deck)* The 2026 brand-facing Ad Manager deck lists "Operational Health — Uptime and screen performance across the network" as one of six analytics dimensions brands can see. Is this the same dashboard CS uses? Does it show real-time device uptime, or is it aggregated/delayed reporting? Is it the same Kibana view, or a separate data feed? **This is important: if this capability is being sold to brands today, we need to know whether it actually works or whether it is aspirational.**

**Content upload and transcoding flow:**

- Upload a short test video through VPM and walk through what happens: FFmpeg transcoding → S3 → CloudFront → how long until it appears on a device?
- Is there any feedback to the user (or to operations) if transcoding fails silently?

### What to capture / note during the demo

- Exact screen of the Kibana dashboard — what fields are shown, what's missing
- What the dev menu exposes and what it does not
- Whether any blank-screen or crash event is visible in telemetry when a failure is triggered manually
- The latency between a content upload and when it's available on device
- Whether the CS view and the engineering view are the same dashboard or different

---

## Section 2 — Q&A Questions

Organized by audit category. For each question: what we already know is marked in *italics*, what we are trying to confirm or deepen is the question itself.

---

### A. Active firefight — VT-5083

*We know:* VT-5083 is running across player-api, reach-n-freq, and fm-common. M3u8 fixes, quarantine logic, quality tier-fall, GOP duration changes are all mid-rollout. The same fixes were committed twice within days.

1. What is the current status of VT-5083 — is it resolved, contained, or still active?
2. How was this issue first detected? Customer report, or something internal?
3. Why were the same fixes committed twice within a few days — is there a code review process in place?
4. Has this firefight changed what's currently deployed on any of the three active workstreams (html5core, Roku, Android)?
5. Does this need to fully settle before Phase 1 work can start cleanly, or can they run in parallel?

---

### B. Telemetry — current state and coverage

*We know:* Events go via WebSocket to Elasticsearch. Kibana for visualization. No Grafana, no structured alerting. ~4% of ~47–50 known failure mechanisms are classified. Roku telemetry has been off since March. WebSocket close = visibility ends. The 2026 brand-facing deck markets "Operational Health — Uptime and screen performance across the network" as a live analytics dimension for brands — this creates a visible tension: either that dashboard is real and CS should be able to use it (so why can't they?), or it is being sold to brands before it actually works. The answer to this tension will change how we scope Phase 1.

1. Can you walk us through the current event envelope — what fields are in a standard telemetry event today? *(We need to see the schema, not just hear a description.)*
2. What events, specifically, does the html5core player emit today? What about Roku and Android?
3. Why has Roku telemetry been off since March — what happened and what would it take to re-enable it?
4. Is there any event emitted when a WebSocket connection closes unexpectedly? Or does it just go silent?
5. Is there any alerting — even a basic one — on WebSocket drop rate or error spikes in Elasticsearch today?
6. Joe mentioned a technical doc based on Netflix's QoE research blog — can you share that? *(This would let us understand Joe's mental model for the 80% target and anchor the Phase 1 work on the same taxonomy.)*

11b. *(New — from brand partnerships deck)* The 2026 brand-facing materials list "Operational Health — Uptime and screen performance across the network" as one of six analytics dimensions brands can see. What is the data source for this? Is it a live Kibana view, aggregated reporting from Elasticsearch, or something else? Who sees it — brands, CS, or engineering only?

---

### C. Release process

*We know:* No canary deploys formally, but Joe confirmed server-side switching exists and could support them. No rollback path. A bad merge to html5core hits Samsung/LG/FireTV within 15 minutes. The deck framed this as a risk to assess before assuming what can be improved.

1. Walk us through a typical release for html5core — what happens from a merged PR to when it's live on production screens?
2. Who validates a release before it goes out? Is there a staging environment that runs real content on real or emulated devices?
3. Joe mentioned you can modulate which server the app pulls from — is this actually used today before a full rollout, or is it available but not used?
4. If something breaks after a release, what is the rollback action today? Who initiates it and how long does it take?
5. Is the release process the same across html5core, Roku, and Android, or does each platform have its own flow?

---

### D. QA

*We know:* One QA person, not senior. QA involved early but test cases written late. Testing doesn't complete before shipping. No reliable staging for blank-screen reproduction. David confirmed: most issues are fixed without being reproducible, and the team waits for the next customer report.

1. What does QA actually test today — what's in the test suite, if anything is written down?
2. Is any of it automated, or is it all manual?
3. What physical devices does QA have access to for testing?
4. Has QA ever successfully reproduced a blank screen in a controlled environment? If yes, how?
5. What is a realistic QA cycle time for a release today — from build to cleared-to-ship?

---

### E. Fleet and device landscape

*We know:* 3,000+ active screens, ~2,000 practices. html5core covers ~50% of fleet (Samsung Tizen, LG WebOS, Fire TV). ~600 different device types in production. Device classification via Haiku at 96–98% accuracy. Older Android hardware and Samsung TVs are anecdotally most problematic. Legacy hardware being phased out over 6 months. Screen growth is +67% YoY with a target of 3 screens per practice by 2026. The network serves 30M monthly impressions at $20–$30 CPM — meaning unmonitored blank screens are directly eroding that inventory. Average revenue per practice is $350/month, 90% from brand ad campaigns.

1. What are the top 10 device types by volume today? *(Even a rough Kibana query would surface this.)*
2. What percentage of the current 3,000 screens is legacy hardware that will be phased out? Is that timeline firm?
3. Among the three active workstreams, which has the highest incident rate — html5core, Roku, or Android?
4. Are there any device types or OS versions that are known to be unreliable but not yet officially deprecated?
5. For the Roku platform specifically: how many screens, and what's the current state of that codebase?

---

### F. Adaptive bitrate streaming (HLS.js)

*We know:* HLS.js is in use. Joe flagged that he doesn't know if the ABR implementation is healthy, what triggers level switches, or whether it's been validated. This is a named unknown from Joe himself.

1. What version of HLS.js is currently deployed in html5core?
2. What are the ABR configuration thresholds — at what buffer level or bandwidth drop does it trigger a level switch?
3. Is there any logging or telemetry around level switch events today?
4. When was the ABR behavior last intentionally tested under degraded network conditions?
5. Has a level switch down ever been confirmed as a contributing factor to a blank screen? Or is this still hypothetical?

---

### G. Mux evaluation

*We know:* Mux Video is being evaluated to replace the FFmpeg/HLS transcoding pipeline, which has silent failure modes. Mux Data has SDKs for all runtimes including HLS.js, ExoPlayer, AVPlayer, Roku, and Tizen. Pricing concern: per-view model may be prohibitive at ~36M views/month in a signage loop context. Video is considered a "yes" — Data is pending the pricing conversation.

1. Where is the Mux decision right now — is Video actively moving forward, or is everything paused pending the Data pricing resolution?
2. Has the Mux Data SDK been prototyped or tested in any of the runtimes yet?
3. If Mux Data resolves the pricing question, does that change the Phase 1 telemetry plan — i.e., does Mux Data replace or complement the Elasticsearch + WebSocket approach?
4. For the existing ~40k videos in S3: what would migration look like, and is the migration tooling already tested?

---

### H. Phase 1 feasibility — the 80% target

*We know:* Joe Schooler (CPO, background Apple/Amazon/Google) wrote the mitigation plan and set the 80% target. He referenced Netflix QoE research as the basis and wrote a technical doc modeling that work. The 80% is scoped to the 50% of the fleet that stays, not all devices. It's meant to cover the standard QoE failure event taxonomy, not 80% of device models. The 2026 financial projections target a run rate of $15.26M with EBITDA turning positive at 12% — Phase 1 telemetry coverage is directly on the critical path to that milestone. Joe's background (Apple, Amazon, Google) gives the 80% target significant credibility, but it is still unconfirmed whether the engineering team was involved in scoping it or whether it was Joe's unilateral estimate.

1. What was the basis for the "80% coverage in one month" timeline — is that Joe's estimate, or was it scoped with the engineering team?
2. Who on the Vrtly engineering side owns Phase 1 implementation? How many engineers are assigned to it?
3. What is the current sprint allocation — is Phase 1 work actively running, or is the firefight consuming all capacity right now?
4. What does "80% coverage" mean in concrete terms — is there a list of the ~47 failure mechanisms somewhere, and which ones get you to 80%?
5. Are there any external dependencies (platform SDK access, device lab hardware, partner API access) that could block Phase 1 from starting?

---

### I. Operational questions — from the original deck (slide 3)

These were the questions we prepared for the call. Some were partially answered. Revisit any that weren't fully addressed.

1. Has there been an incident where you identified the complete root cause end-to-end? How long did that take? *(Partially answered — anecdotal evidence exists but no structured post-mortems.)*
2. When something breaks after a release, where does the problem typically come from — html5core, a backend service, content encoding, or something else?
3. Can you walk us through one or two recent incidents you'd consider representative of the most common failure pattern?
4. When a screen goes down today, how does the team find out — and what happens in the first 30 minutes?
5. Is there any pre-production environment where releases are validated before they go to the full fleet?

---

## Section 3 — Questions answered by new information (June 3 update)

*Sources reviewed: Q1 2025 investor pitch deck (synthesized June 1) and 2026 brand partnerships sales deck (synthesized June 2). Both are outward-facing commercial documents.*

### Directly answered: None

None of Q1–Q45 are answered by the new sources. The pitch deck and brand partnerships deck do not address the state of VT-5083, event schemas, release processes, QA, HLS.js configuration, Mux decision status, or Phase 1 sprint allocation. Those questions all remain open for the session.

### Context significantly enriched


| Question                                         | How it changed                                                                                                                                                                                                                          |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Q36 (Basis for 80% target)                       | Joe Schooler's background (Apple, Amazon, Google) adds credibility to the estimate, but the question of whether it was scoped with the engineering team is still open.                                                                  |
| Q37 (Who owns Phase 1)                           | Sergei Vareyko (Principal Engineer) is now a named, confirmed team member. May be the implementation owner — worth asking directly.                                                                                                     |
| Q44 (How does team find out about a down screen) | The brand-facing deck markets "Operational Health" as a live analytics dimension to brands — adds urgency to understanding whether this is real or aspirational.                                                                        |
| Demo — CS tooling                                | "Operational Health — Uptime and screen performance" is being marketed to brands as a current capability. This must be shown in the demo to verify it exists and works.                                                                 |
| All sections                                     | Business stakes are now fully quantified: 30M impressions/month at $20–$30 CPM, $350/practice/month average revenue, $15.26M 2026 run-rate target. These numbers can anchor any discussion about why Phase 1 urgency is non-negotiable. |


### New due-diligence item (not a session question)

- **Hydrafacial case study discrepancy**: Q1 2025 pitch deck cites n=500 practices for the +83% treatment increase. The 2026 brand partnerships deck cites n=256 for the same outcome. The sample size discrepancy should be resolved before Vrtly uses this externally. Not for the session — flag internally.

---

## Section 4 — Priorities for the session

Not all of these can be covered in one session. Below is a suggested priority order based on audit criticality.

**Must cover during demo:**

- Kibana/telemetry dashboard live view (questions 10, B-general)
- Dev menu failure simulation + what shows up in telemetry (demo section)
- CS tooling — what they can see about a specific device (demo section)
- *(New — June 3)* "Operational Health" analytics dimension: show us what brands actually see for device uptime in the Ad Manager. Is it real data or placeholder? Is it the same view CS uses? (question 11b and demo — CS tooling section)

**Must cover in Q&A (week 1 critical path):**

- VT-5083 current status (question 1)
- Current event envelope / what's actually in Elasticsearch (questions 6, 7)
- Roku telemetry status and re-enable path (question 8)
- Release process for html5core — from PR to production (question 12)
- Joe's Netflix QoE doc (question 11)
- Phase 1 ownership and current sprint allocation — ask about Sergei Vareyko specifically (questions 37, 38)

**Important but can go async / Slack:**

- Fleet top-10 device breakdown (question 22)
- HLS.js version and ABR configuration (questions 27, 28)
- Mux decision status (question 32)
- QA device access and test suite (questions 18, 19)
- Credentials rotation status (not listed above — add: are the two credential exposures from the vendor brief fully rotated?)

