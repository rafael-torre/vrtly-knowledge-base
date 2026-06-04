# Vrtly Engineering Vendor Brief
*May 2026 — Confidential*

---

## How the platform works

Practices and brands manage content through two web portals — **VPM** for practices, **VAM** for brands — built on a Vue 3 / TypeScript monorepo. The backend is Java/Spring across four services:

- **player-api** — handles device connections and content streaming
- **reach-n-freq** — owns playlist generation and video transcoding
- **api** — main monolith covering billing and content upload
- **fm-common** — shared library across all of them

MySQL on RDS is system of record. Elasticsearch holds 100M+ telemetry and analytics events.

**Content flow:** practice uploads an mp4 → FFmpeg transcodes to HLS → S3 → CloudFront → device. Playlists are generated daily per screen, pushed over WebSocket, and cached locally. Screens play from cache — not a live stream.

Six device runtimes in production. **html5core-player** covers Samsung Tizen, LG WebOS, Fire TV, and iOS WebView in one codebase — roughly 50% of the fleet and the highest-leverage target. Roku and Android/ExoPlayer have bespoke players. Apple TV runs a native Swift app. The other ~50% is legacy external hardware being phased out over the next 6 months.

---

## Where things stand

No proactive alarming on blank screens. We hear about problems when customers call, or we don't hear at all because they churn and turn the screen off. We've catalogued ~47 distinct failure causes across content encoding, network delivery, device hardware, app code, and platform OS behavior. Telemetry today correctly classifies about **4%** of them.

There is an active reliability firefight in progress **(VT-5083)** spanning player-api, reach-n-freq, and fm-common — m3u8 fixes, quarantine logic, quality tier-fall, GOP duration changes mid-rollout. The same fixes are being committed twice within days. Roku telemetry has been off since March. Credentials were found committed in two repos this week and not yet fully rotated.

No canary deploys. No circuit breakers on the playback watchdog. No server-side rate limiting on WebSocket reconnects. No external alerting. A bad merge to the html5core prod branch poisons the entire Samsung/LG/FireTV fleet within 15 minutes with no rollback path.

---

## What the bug backlog says

The last 100 bugs tell a clear story. **Blank and black screens** are the single largest category — roughly 20 bugs, multiple customer-named incidents across Fire TV, Samsung, LG, Roku, iOS, and HTML5, most of them still open. Fire Stick alone accounts for at least 6 bugs filed in the last 30 days: choppy video, content skipping before finishing, blank screen with audio, app not loading, playback controls missing.

**Consultations and Info Packs** have ~10 open bugs: QR codes not rendering, PDFs broken, emails not sending, skip behavior broken on the public page. **Social media content integration** has its own cluster — wrong content types, expired credentials not deactivating, duration not counting toward playlist length. **Content upload** has two separate bugs for images and videos rotating 90 degrees after upload — almost certainly the same root cause, filed independently.

The ratio of open to resolved in this list is roughly 55/45. The backlog is growing faster than it is being cleared, and no single area of the product is clean.

---

## The mitigation plan

Two phases. **Phase 1** closes the telemetry gap — correctly detecting and classifying ≥80% of known failure causes within a month, verified by a synthetic QA test suite run against physical devices. **Phase 2** uses that data to drive blank screen rate below 0.1% within two quarters. Phase 2 doesn't start until Phase 1 is trustworthy.

Three parallel workstreams: html5core-player, Roku, and Android/ExoPlayer, all feeding the same standardized event envelope into Elasticsearch. Roku telemetry re-enabling is the first unlock — it's the one platform we're completely blind on today.

Success is defined by four KPIs:
- Blank screen rate below threshold
- Telemetry coverage above 80%
- Zero production incidents per week
- Specific features shipped

---

## Exploring Mux

We're evaluating **Mux Video** to replace our FFmpeg/HLS transcoding pipeline, which has multiple silent failure modes — content can finish "transcoded" with missing variants and nothing downstream notices. Mux Video replaces that with a managed pipeline with reliable encoding, storage, and multi-CDN delivery. Migration tooling pulls directly from our S3 library. At ~40k videos averaging 60 seconds, storage cost is roughly **$220/month**.

**Mux Data** has SDKs for every runtime we run — HLS.js, ExoPlayer, AVPlayer, Roku, Tizen — and supports custom dimensions to pass `screen_id` and `org_id` alongside standard QoE metrics.

The pricing problem: Mux charges per video view, and in a signage context where content loops all day that's ~36M views/month at current scale. We're in conversation with them about device-based pricing before committing to Data. **Video is a straightforward yes.**
