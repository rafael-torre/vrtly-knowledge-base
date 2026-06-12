---
title: "System Map — Vrtly Platform"
last_updated: 2026-06-10
---

# System Map: Vrtly Platform

## Platform Overview

Vrtly is a digital-signage SaaS platform connecting two sides of a marketplace: healthcare practices (providers) and pharmaceutical/healthcare brands (sponsors). Providers manage waiting-room display screens; brands create advertising campaigns and educational content that play on those screens. The platform orchestrates content lifecycle from upload and transcoding through to real-time playlist delivery on physical display devices, with telemetry and analytics flowing back to both sides via a web-based management portal.

At a system level, the platform comprises eight analyzed services — a management web frontend (monorepo), a central backend API, a device-facing player API, an HTML5 player app, a reach-and-frequency / playlist resolution engine (`rnf`), a screen state service (`state`), the internal shared library (`fm-common`), and a shared UI design system (`@vrtly/component-library`) — plus several unanalyzed integrated services (YouTube downloader, Cordova shell, Roku player, Android TV player, my.vrtly.app portal) and shared infrastructure (Amazon MQ, Redis ElastiCache, MySQL RDS, Elasticsearch, S3, CloudFront, XXL-Job). The web frontend and HTML5 player app are static SPAs deployed to S3/CloudFront; the four backend services (`fmcom-api`, `fmcom-player-api`, `rnf`, `state`) are containerized Spring Boot services running on AWS ECS (EC2 launch type). All four backend services share a single MySQL RDS database (`fm_store`) and a single Elasticsearch cluster. `state-service` is a critical platform-wide dependency: its outage cascades to screen lookup failures, ES quota fallback, and `rnf` container restart.

---

## Service Inventory

| Service | Role | Stack |
|---|---|---|
| `fmcom-vrtly-fe-monorepo` | CMS web frontend — four SPAs (vrtly-home, VPM provider portal, VAM advertiser portal, onboarding) | Vue 3, Pinia, TypeScript, Vite, Element Plus, `@vrtly/component-library`, Axios; deployed to S3/CloudFront |
| `fmcom-api` | Central backend — CMS operations, content lifecycle, billing, device management, social sync, admin | Spring Boot 3.2 / Java 17, MySQL, Redis, Elasticsearch, Amazon MQ (JMS), AWS SDK v1+v2, Stripe, `fm-common` 8.9.0 |
| `fmcom-player-api` | Device-facing backend — device registration, playlist delivery, WebSocket channel, ABR mitigation, telemetry ingestion | Spring Boot 3.2 / Java 17, MySQL, Redis, Elasticsearch, Amazon MQ (JMS), WebSocket, AWS SDK v1+v2, `fm-common` 8.8.9 |
| `html5core` | HTML5 player app — runs in WebView on FireTV, webOS, Tizen, iOS, browser; displays playlists and consults | Vue 3, Pinia, TypeScript, Vite, crypto-js; deployed to S3/CloudFront |
| `rnf` (`reach-n-freq`) | Playlist resolution and SOV engine; media transcoding pipeline; analytics and reporting background jobs | Spring Boot 3.2.0 / Java 17, MySQL (`fm_store`, pool 10), Redis (DB 4 dev / DB 2 prod), Elasticsearch (via `fm-common` 20+ modules), Amazon MQ (JMS), AWS S3 (download + upload), AWS EFS (`/mnt/efs` transcode temp), AWS CloudFront (cache invalidation), XXL-Job (executor port 9996, 18 handlers), Feign (Salesforce, OutScraper, state-service), `fm-common` 8.9.1 |
| `state` (state-service) | Authoritative screen registry (JVM-resident `ConcurrentHashMap` of all `ScreenDto`); in-process HTTP long-poll message broker; auth token management; Elasticsearch concurrency governor | Spring Boot 3.3.2 / Java 17, MySQL (`fm_store`, pool 10), Redis (DB 4 dev / DB 2 prod), Elasticsearch (broker state snapshots, screen status, ES throttle stats), Amazon MQ (JMS — ES-limit coordination topics only), `fm-common` 8.7.8; port 9092; reachable at `state.dev.vrtly.app` / `state.prod.vrtly.app` |
| `youtube-downloader` (gap) | YouTube video download worker | Not analyzed — receives JMS dispatch from `fmcom-api`; calls `/internal/youtube-downloads/**` to report progress |
| `fm-common` | Internal shared library (JAR) — single source of truth for all cross-service domain knowledge: typed JMS destination constants (`JmsDestination<T>`, 31 destinations), Redis key namespaces (`TelemetryRedisKeys`, `RedisChannels`, `CacheConstant`), Elasticsearch index names (`ElasticsearchIndex`), 60+ MySQL JPA entity + repository modules, Feign clients for state-service (`ScreenStateClient`, `InstanceStateClient`, `AuthServiceClient`, `BrokerStateClient`), shared service implementations (`TelemetryService`, `ContentQuarantineService`, `SovRuleService`, `AuthService`, `ContentService`, `PlaylistCurrentService`, `MessagingService`), ES throttle system (`ThrottledElasticsearchTransport`, `ElasticsearchLimitClient`) | Java 17 / Spring Boot 3.2.0 parent BOM; no auto-configuration (all activation via explicit `@Import`); published to AWS CodeArtifact (`com.friendmedia:fm-common`); current source at 8.9.1; `fmcom-api` pins 8.9.0, `fmcom-player-api` pins 8.8.9, `rnf` pins 8.9.1, `state` pins 8.7.8 — four different versions in production |
| `cordova-player` (gap) | FireTV native shell wrapping `html5core` in a WebView | Not analyzed — referenced in `html5core` README; provides device UUID, model, and version via `window._cordovaNative` |
| `roku-player` (gap) | Roku player app | Not analyzed — referenced in `fmcom-player-api` (`RokuMacMigrationService`, `RokuCertOverrideService`); communicates with `fmcom-player-api` |
| `android-player` (gap) | Android TV player app | Not analyzed — implied by `fmcom-player-api` device types |
| `@vrtly/component-library` | Design system / shared UI component library — 41 named Vue 3 components, 111 icons (raw SVG strings + compiled Vue component wrappers), and a distributable SCSS token system; theming via aggressive Element Plus CSS variable overrides | Vue 3 / TypeScript / Vite; ESM-only output (`dist/component-library.mjs`); Element Plus `^2.9.11` peer (but bundled, not externalized — risk of double-bundling in consumers); SCSS token system with light/dark themes; Manrope typeface; published to AWS CodeArtifact npm; current version `0.8.20`; consumed by `fmcom-vrtly-fe-monorepo` at `^0.8.20`; Storybook deployed to `vrtly-storybook` S3 bucket |
| `xxl-job-admin` (gap) | Distributed scheduled-job admin server | Not analyzed — `fmcom-api` registers 15+ jobs, `fmcom-player-api` registers telemetry cleanup, `rnf` registers 18 handlers (executor port 9996); admin at `https://jobs.prod.vrtly.app/job-admin/` |
| `my.vrtly.app` public portal (gap) | Patient-facing info-pack landing page (QR code target) | Not analyzed — referenced by `fmcom-vrtly-fe-monorepo` as `VITE_INFOPACK_URL`; info-pack QR URLs are encrypted server-side before embedding |

---

## Interaction Diagram

See [System Overview Diagram](./system-overview-diagram.md) for the full four-view breakdown:

- **View 1 — System Context**: actors (Provider, Sponsor, Device Admin), system areas, and external integrations
- **View 2 — CMS Frontend + fmcom-api**: CMS portals, routing, fmcom-api internals, and owned infrastructure
- **View 3 — Device + fmcom-player-api**: device layer, html5core, player API, ABR escalation, and shared infra
- **View 4 — Async + Gap Services**: Amazon MQ event bus, XXL-Job scheduler, rnf (now analyzed), state-service (now analyzed), and youtube-downloader (still gap)

---

## Data Flow Narrative

### 1. Device registration and activation

1. A new display device (e.g., FireTV) loads the Cordova shell (`cordova-player`), which launches the `html5core` Vue SPA from S3/CloudFront.
2. `html5core` enters an activation polling loop, calling `POST /player/registerDevice` on `fmcom-player-api` every 3 seconds.
3. `fmcom-player-api` checks the device MAC in MySQL (via `fm-common` screen repositories). If unregistered, it returns an activation pairing code displayed as a QR code on screen.
4. A practice administrator scans the QR code or enters the pairing code in VPM (the provider portal in `fmcom-vrtly-fe-monorepo`), calling `fmcom-api` to associate the screen with an organization.
5. On the next poll, `fmcom-player-api` sees the screen is now associated, returns a session secret and config payload. `html5core` stores the session key in memory (Pinia state).

### 2. Content upload and transcoding

1. A provider uploads a video via VPM → `POST /cms/dashboard/content` → `fmcom-api`.
2. `fmcom-api` stores the file on S3 (via AWS SDK / EFS), creates a `Content` entity in MySQL with `transcodingStatus: PENDING`, and dispatches a JMS message to Amazon MQ (`RNF_MEDIA_PROCESSING` destination).
3. `rnf` picks up the `RNF_MEDIA_PROCESSING` JMS message in `MediaProcessingHandlers`, routes it through `MediaPipelineOrchestrator` to `UnifiedVideoPipeline`. The pipeline runs four stages: download source from S3 → FFmpeg normalization to canonical h264 MP4 → standalone tier variants → HLS ABR ladder. Completed artifacts are uploaded back to S3. On completion, `UnifiedVideoPipeline.onComplete()` publishes `ContentAddMessage` to `API_CONTENT_ADD` on JMS (for `TriggerMode.MESSAGE` flows only; admin bulk re-transcodes via `TriggerMode.REST_BULK` suppress this notification). **C3 resolved: `rnf` is the publisher of `API_CONTENT_ADD` for the content transcoding lifecycle.** `fmcom-api` also publishes to `API_CONTENT_ADD` independently for non-transcoding content events — the destination has two independent publishers and the consumer (`ContentMessageHandlers`) must handle idempotent delivery. The platform does not use AWS Elastic Transcoder — all transcoding is performed by FFmpeg running inside `rnf`'s own container.
4. `fmcom-api` receives the `API_CONTENT_ADD` completion event via its JMS `ContentMessageHandlers`, updates the `Content` entity to `COMPLETE`, adds the content to a default screen, and triggers Elasticsearch post-commit sync. `rnf` also simultaneously publishes `PLAYER_CONTENT_TRANSCODED` (single item) to notify `fmcom-player-api`.
5. `fmcom-player-api` receives the `PLAYER_CONTENT_UPDATED` or `PLAYER_CONTENT_TRANSCODED_BATCH` JMS event, invalidates cached playlist state for affected screens, and pushes a `CONTENT_CHANGED` WebSocket message to connected devices.

### 3. Playlist delivery to a device

1. `html5core` opens a persistent WebSocket connection to `wss://player.vrtly.ai/ws` (`fmcom-player-api`).
2. On connection or `CONTENT_CHANGED` push, `html5core` calls `GET /player/playlist/current` on `fmcom-player-api`.
3. `fmcom-player-api` checks Redis for a cached playlist; on a miss it calls `rnf` via Feign (`GET /playlist/current/{screenId}`, served by `rnf`'s `PlaylistCurrentController`). `rnf` resolves the playlist from its `ElasticPlaylistSchedule` and `ElasticPlayCurrent` Elasticsearch indices — these were pre-built by the playlist generation pipeline, which runs SOV rules (share-of-voice, ad campaign screen slots, Stripe subscription tier), open-hours schedule, and Period-of-Day (POD) patient traffic patterns. `rnf` does not build playlists on demand at request time; it serves from pre-computed schedules. `PlaylistCurrentServiceLocal` in `fmcom-player-api` is confirmed as an alternate playlist assembly path (via `fm-common` `PlaylistCurrentServiceModule`), but whether it functions as a circuit-breaker fallback for `rnf` unavailability or as a separate flow (e.g., Consult mode) is not confirmed in either spike.
4. `fmcom-player-api` rewrites every content URL in the playlist: it applies per-screen quality caps (from Redis) and escalation stage overrides (per-screen, per-content state in Redis), then generates CloudFront signed URLs for each asset.
5. The signed playlist JSON is returned to `html5core`, which stores it in Pinia state and begins sequential playback.

### 4. Telemetry and ABR mitigation

1. During playback, `html5core` batches telemetry events (playback start/end, decode errors, ABR quality changes, heartbeats) in a localStorage queue and flushes them over WebSocket to `fmcom-player-api`.
2. `fmcom-player-api`'s `TelemetryEventAnalyzerService` dispatches each event asynchronously to registered `TelemetryDetectionRule` implementations.
3. `PlaybackQualityCapRule` writes a per-screen Redis entry (30 min TTL) when ABR bitrate events indicate network degradation, capping quality for all subsequent playlist fetches on that screen.
4. `ContentPlaybackEscalationRule` advances the per-(screen, content) escalation state machine in Redis when decode failures exceed a configurable threshold, stepping through `HLS_FULL → HLS_720 → SRC_ORIGINAL → SRC_720 → SRC_540 → QUARANTINE`.
5. `MITIGATION` telemetry events are written to Elasticsearch. A diagnostics dashboard (confirmed in `fmcom-player-api`'s spike; likely also in `fmcom-api`'s admin layer — exact service is unconfirmed) reads these events for operator visibility.
6. In parallel, `html5core` sends a separate HTTP `POST report/content` to `fmcom-player-api` every 7 minutes (or on a WebSocket `REPORT` command). This is a distinct played-content record used for analytics and billing — not the WebSocket telemetry stream.
7. Device telemetry events from Firebase are also forwarded to `fmcom-api` via GCP Pub/Sub inbound webhook (`POST /webhook/gcp/pubsub`), where they are decoded by `ExternalEventConverter` implementations and handed to `TelemetryService`.

### 5. CMS user session (provider/brand)

1. A user signs in at `https://my.vrtly.ai` via `vrtly-home`, which calls `POST /cms/auth/login` on `fmcom-api`.
2. `fmcom-api` validates credentials, stores the session token in Redis (key from `fm-common` auth module), and returns `access` + `secret` tokens.
3. The frontend stores both tokens in localStorage and injects them as raw HTTP headers on every subsequent request via the Axios interceptor in `packages/api/request/index.ts`.
4. `vrtly-home` reads `organization.type` from the locally persisted `organization` key in localStorage (populated at login) and routes `PROVIDER` users to VPM (`/provider`) and `SPONSOR` users to VAM (`/brands`). This routing is client-side only — if the localStorage value is stale (e.g., after a role change), the routing decision is wrong until the user forces a reload.
5. API calls from VPM and VAM flow to `fmcom-api`'s CMS controller layer (`/cms/**`), which uses Spring Security's `TokenBasedAuthenticationFilter` + Redis lookup to authenticate and authorize each request.

---

## Shared Infrastructure

| Resource | Used by | Notes |
|---|---|---|
| **MySQL RDS** (`fm_store`) | `fmcom-api` (primary domain DB, pool 10), `fmcom-player-api` (screens, sessions, consults, reports, pool 150), `rnf` (reads organization, screen, brand, ad-campaign, content, open-hours, Stripe subscription data via `fm-common` modules; writes organization hourly distribution, place validity, POD alpha; pool 10), `state` (authoritative screen writer; owns `user_token` table; reads ~15+ tables via `fm-common` modules; pool 10; JPA query timeout 15s, lock timeout 1s) | Shared single database with `organization_id` as multi-tenant discriminator. Liquibase manages schema; all four services run migrations independently — schema coordination risk across four independent migration paths. `state-service` is the authoritative screen writer at runtime (deferred 1-minute flush from in-memory cache), but `fmcom-api` also has direct JPA write access to the `screen` table via `MySqlScreenModule` — authority boundary ambiguity confirmed (see Open Question 1 / state-service spike). |
| **Redis ElastiCache** | `fmcom-api` (auth token cache, application cache, ShedLock distributed locks, feature flags), `fmcom-player-api` (session cache, per-screen quality caps, per-(screen,content) escalation state, WS dedup, quarantine ZSETs, lastFetchAt anchor), `rnf` (DB 4 dev / DB 2 prod; application caching, per-screen mutex via `SyncOpService`/Redis, `LongPollTaskServiceModule` coordination), `state` (DB 4 dev / DB 2 prod; `fm-common` `RedisServiceModule` for lock service and token/session cache) | Different logical Redis database indexes (fmcom-api: default; fmcom-player-api, rnf, state: DB 4 dev / DB 2 prod). Redis key namespaces confirmed in `fm-common`: `TelemetryRedisKeys` (`screen:playback:quality:cap:{screenId}`, `system:playback:quality:cap:max`, `content:bad_manifest:*`, `screen:mitigation:*`, `telemetry:dedup:*`, `screen:content:escalation:*`, `roku:cert:override:*`) and `RedisChannels` (`screen:current:play:content`, `screen:playlist`, `screen:plan`, `screen:plan:action`, `screen:recently:play:*`, `brand:*`, `activity:record:hash`, `s3:content`, `s3:photo`, `changed:screen:*`, `updated_screens:queue`, `updated_users:queue`, `updated_orgs:queue`, etc.). No technical keyspace isolation exists between services — isolation relies entirely on naming discipline. `fmcom-api` and `fmcom-player-api` share the same logical Redis DB and write to keys from the same `RedisChannels` namespace. |
| **Amazon MQ (ActiveMQ)** | `fmcom-api` (publishes: `RNF_MEDIA_PROCESSING`, `RNF_GENERATE`, `RNF_OPEN_HOURS_UPDATED`, `RNF_RECENTLY_ACTIVATED`, `RNF_PDF_TO_IMAGE_DESTINATION`, `RNF_TRANSCODE_DESTINATION` (legacy), `RNF_SALESFORCE_*` (3 topics), `YOUTUBE_DOWNLOAD_DESTINATION`, `API_CONTENT_ADD`, `API_CONSULT_EMAIL_SEND_DESTINATION`, `PLAYER_ORGANIZATION_CONTENT_UPDATED`, `PLAYER_ORGANIZATION_UPDATED`, `PLAYER_ORGANIZATION_ACTIVITY`, `PLAYER_SCREEN_CONTENT_PENDING`, `PLAYER_SCREEN_CONTENT_UPDATED`, `PLAYER_SCREEN_UPDATED`, `PLAYER_HISTORY_LOAD`; subscribes: `API_CONTENT_ADD`, `API_CONTENT_QUARANTINE`, `YOUTUBE_UPDATE_URL_DESTINATION`, `API_CONSULT_EMAIL_SEND_DESTINATION`, `ALL_USER_ACCESS_CHANGED`, `ALL_SYSTEM_PARAMS_CHANGED`, `ELASTICSEARCH_LIMITS_ALLOCATED`), `fmcom-player-api` (subscribes: `PLAYER_*` topics including `PLAYER_CONTENT_TRANSCODED`, `PLAYER_CONTENTS_TRANSCODED_BATCH`, `PLAYER_SCREEN_CONTENT_UPDATED`, `PLAYER_SCREEN_QUALITY_CAP_NOTIFY`, and others; publishes: `API_CONTENT_QUARANTINE`, `ELASTICSEARCH_INSTANCE_REGISTERED`, `ELASTICSEARCH_INSTANCE_UNREGISTERED`, `ELASTICSEARCH_QUOTA_REQUEST`, `ELASTICSEARCH_PERFORMANCE_FAILURE`), `rnf` (subscribes: `RNF_MEDIA_PROCESSING`, `RNF_GENERATE`, `RNF_OPEN_HOURS_UPDATED`, `RNF_RECENTLY_ACTIVATED`, `RNF_PDF_TO_IMAGE_DESTINATION`, `RNF_TRANSCODE_DESTINATION`, `RNF_SALESFORCE_*`; publishes: `API_CONTENT_ADD`, `PLAYER_ORGANIZATION_CONTENT_UPDATED`, `PLAYER_CONTENT_TRANSCODED`, `PLAYER_CONTENTS_TRANSCODED_BATCH`, `PLAYER_SCREEN_CONTENT_UPDATED`), `state` (subscribes: `ELASTICSEARCH_INSTANCE_REGISTERED`, `ELASTICSEARCH_INSTANCE_UNREGISTERED`, `ELASTICSEARCH_QUOTA_REQUEST`, `ELASTICSEARCH_PERFORMANCE_FAILURE`; publishes: `ALL_USER_ACCESS_CHANGED`, `ALL_SYSTEM_PARAMS_CHANGED`, `ELASTICSEARCH_LIMITS_ALLOCATED`), `youtube-downloader` (publishes: `YOUTUBE_UPDATE_URL_DESTINATION`; subscribes: `YOUTUBE_DOWNLOAD_DESTINATION`) | SSL broker at `ssl://b-451110d0-....mq.us-west-2.amazonaws.com:61617`. `BROKER_PREFIX` env var namespaces all destination names per environment. All 31 JMS destination constants defined in `fm-common` `Destinations` interface as typed `JmsDestination<T>` implementations. `API_CONTENT_ADD` is published by both `rnf` (after transcoding) and `fmcom-api` (for non-transcoding content events) — dual publishers; consumer (`ContentMessageHandlers`) must handle idempotent delivery. `BROKER_PREFIX` allows per-env isolation (dev prefix `"dev"`, prod empty). Dev/QA task definitions expose broker credentials as plaintext env vars (confirmed in both `rnf` and `state` spikes). |
| **Elasticsearch** | `fmcom-api` (25+ index modules via `fm-common`: analytics, ad campaign slots, played content, screen state logs, social content, impressions, orders), `fmcom-player-api` (telemetry events, mitigation events), `rnf` (reads: `ElasticAdCampaignScreenSlot`, `ElasticPlaylistSchedule`, `ElasticPlayCurrent`, `ElasticScreenStateLog`; writes: playlist schedules, impression reports, SOV reports, playback reports, proof-of-play reports, screen status reports; throttle `service-id: rnf`; requests quota increase for daily generation sweep via `ElasticsearchLimitClient`), `state` (writes: broker state snapshots to `ElasticBrokerMessages`, screen status to `ElasticScreenStatusReport`; reads: cluster node stats via `ElasticClusterMgmtRepository` for ES throttle governance; throttle `service-id: state`) | All four backend services share the same Elasticsearch cluster. Write throttling governed by `fm-common` `ThrottlingServiceModule` with per-service quotas allocated by the `state` service Elasticsearch coordinator over JMS. Index names namespaced per environment via `ES_PREFIX` env var in `fm-common` `ElasticsearchIndex` class. 40+ total index types across the platform (37 confirmed in `fm-common` spike). |
| **AWS S3** | `fmcom-api` (media upload, CloudFront signed URLs for CMS delivery, `friendmedia-cms` bucket), `fmcom-player-api` (content asset reads, fallback read bucket, `friendmedia-cms`), `html5core` (subtitle reads from `friendmedia-cms`), `fmcom-vrtly-fe-monorepo` (SPA bundle hosting), `html5core` (app bundle at `html5core` / `html5core-beta` buckets) | Multiple S3 buckets serve different purposes. The CMS media bucket (`friendmedia-cms`) is read by both backend services and directly by `html5core` for subtitles in production. |
| **AWS CloudFront** | `fmcom-api` (signed URL generation via CloudFront private key for CMS content delivery), `fmcom-player-api` (signed URL generation for every playlist content URL delivered to devices; domain `d1cgzt8pcd208o.cloudfront.net`), `fmcom-vrtly-fe-monorepo` (CDN for SPA bundles), `html5core` (CDN for player app bundle) | Both backend services independently sign CloudFront URLs using RSA private keys. `fmcom-player-api` has `private_key.pem` committed to source — critical security gap. |
| **AWS EFS** | `fmcom-api` (mounted at `/mnt/efs` for shared media file storage between container instances), `rnf` (mounted at `/mnt/efs`; used as transcode temp storage — download worker stages files here before the transcode worker processes them; `transcoding.temp-storage-path` config; shared across ECS instances of the same service) | EFS is the shared staging filesystem for the transcoding pipeline. Both `fmcom-api` and `rnf` use the same EFS volume for media staging. EFS unavailability directly halts all transcoding; no code-level error handling exists for filesystem unavailability beyond FFmpeg/S3 exceptions propagating up. |
| **AWS Elastic Transcoder** | Not confirmed in use. | `rnf` spike confirms all video transcoding is done by FFmpeg running inside `rnf`'s own container — not AWS Elastic Transcoder. The original system map assumption that fmcom-api dispatches to Elastic Transcoder is incorrect. The reference to Elastic Transcoder in the earlier spike should be treated as a gap note from before `rnf` was analyzed. |
| **AWS Transcribe** | `fmcom-api` (`TranscribeService`, `TranscribeJobTaskExecutor`) | Speech-to-text for subtitle generation. Long-running job polled by `TranscribeJobTaskExecutor`; result stored alongside the transcoded media. Used for subtitle delivery to `html5core` in production. |
| **XXL-Job Admin** | `fmcom-api` (executor port 9999; 15+ jobs: Stripe sync, social sync, ad slot generation, sponsor notifications, transcription repair), `fmcom-player-api` (executor port 9997; telemetry cleanup, failed report log parsing), `rnf` (executor port 9996; 18 handlers: daily playlist generation/cleanup, transcode sweep, Elasticsearch optimization, impression/SOV/screen-status/playback/proof-of-play reports, organization state/info/Salesforce sync, brand ranking, playlist shrink, InfoPack conversion, YouTube re-enqueue, above-1080p rewrite) | Shared XXL-Job admin server at `https://jobs.prod.vrtly.app/job-admin/`. Single point of failure for all scheduled tasks across three services. `rnf` also has a `prod-perf` ECS service variant (`reach-n-freq-perf`) with its own task definition, likely for bulk re-transcode sweeps without competing with live JMS traffic. |
| **State Service (shared platform service)** | `fmcom-api` (`ScreenStateClient`, `InstanceStateClient`, `AuthServiceClient` via `fm-common` `StateClientModule`), `fmcom-player-api` (`ScreenStateClient`, `InstanceStateClient`, `BrokerStateClient`), `rnf` (`InstanceStateClient` ping/heartbeat — hard `System.exit(-1)` on connection loss) | All three backend services depend on state-service for screen lookups and auth token operations. `rnf` has a hard JVM-exit dependency on state-service liveness (1-minute heartbeat; `System.exit(-1)` on failure). State-service outage cascades: screen lookups fail platform-wide, ES quota allocations fall back to `initial-limit` (1–3 queries/instance), and `rnf` containers begin cycling. No circuit-breaker on `ScreenStateClient`. The in-memory screen cache has no eviction policy — cold-start triggers full MySQL population into heap. |
| **AWS CodeArtifact** | `fmcom-api` and `fmcom-player-api` (runtime dependency: `fm-common` JAR), `rnf` (runtime dependency: `fm-common` 8.9.1 JAR), `state` (runtime dependency: `fm-common` 8.7.8 JAR), `fmcom-vrtly-fe-monorepo` (npm dependency: `@vrtly/component-library`) | Domain `vrtly`, account `515289352310`, region `us-west-2`. Both build-time and deployment-time credential dependency. |
| **AWS SSM Parameter Store** | `fmcom-player-api` (confirmed — all sensitive env vars injected via SSM ARNs in ECS task definitions), `fmcom-api` (env vars override application.yml defaults in ECS task definitions; SSM not explicitly confirmed but assumed same pattern) | Secrets management for DB credentials, Redis auth, MQ credentials, CloudFront keys, encryption keys. |
| **ABR (Adaptive Bitrate)** | `fmcom-player-api` (fully owned: quality cap rules, escalation state machine, HLS manifest rewriting), `html5core` (reports ABR events via telemetry; consumes rewritten HLS master manifest URLs) | ABR mitigation is entirely server-side in `fmcom-player-api`. The player app is a passive reporter of playback quality events. The escalation state machine spans Redis (state store) and MySQL (quarantine records). |

---

## Key Integration Points & Dependencies

### Frontend → fmcom-api (CMS surface)

- All web CMS calls (`fmcom-vrtly-fe-monorepo`) target `https://api.vrtly.app` under the `/cms/**` path.
- Authentication uses a bespoke `access`/`secret` dual-token scheme injected as raw HTTP headers. Tokens are stored in localStorage — non-standard pattern with XSS exposure.
- The shared Axios client lives in `packages/api/request/index.ts`; a legacy duplicate exists per-app in `src/utils/request.ts` for VPM. Both must be kept in sync.
- `fmcom-vrtly-fe-monorepo` also calls `GET /cms/encrypt` and `GET /cms/qr-code/generate-qr-code` on `fmcom-api` from within `html5core` (Info Pack QR generation) — this is the only cross-domain call from the player app to the CMS API.

### html5core → fmcom-player-api (device surface)

- All device lifecycle calls target `https://player.vrtly.ai` under the `/player/**` path.
- Request signing: `SHA-1(serialNumber + timestamp)` with a 300-second replay window. Cryptographically weak — SHA-1 is deprecated for authentication.
- Response encryption: AES-CBC using a server-provided key (itself double-encrypted); key is stored in Pinia memory only and lost on reload.
- WebSocket at `wss://player.vrtly.ai/ws` uses the same session mechanism. Real-time commands flow server → client; telemetry and heartbeats flow client → server.
- **Unauthenticated HLS streaming endpoint**: `/player/content/stream/{store}/{id}/{res}/{filename}.m3u8` is explicitly excluded from all security and session interceptors in `fmcom-player-api`. The endpoint is publicly reachable without credentials and carries a 24-hour `Cache-Control` header. CloudFront signed URL protection is absent on this path.
- **Horizontal scaling constraint**: `fmcom-player-api` holds HTTP sessions and WebSocket connections in node-local in-memory maps (`SessionHolder`, `WsSessionHolder`). Multiple ECS task replicas require ALB sticky sessions to ensure HTTP requests land on the node holding the device's WebSocket connection. Cross-node WebSocket pushes are silently queued in `unsentNotice` rather than delivered live.

### VPM / VAM → html5core (content preview)

- Both VPM and VAM embed the `html5core` player in an iframe or popup for content preview, using a browser-level `postMessage` protocol.
- Protocol: the CMS app sends `SEND_CONTENT`; the player responds with `READY` then `RECEIVE_CONTENT` on success.
- This browser-to-browser channel is independent of the backend APIs and requires the `postMessage` protocol to stay in sync across both repos. No server-side enforcement exists.

### fmcom-player-api → fmcom-api (internal API boundary)

- `fmcom-player-api` references `${SERVICE_DISCOVER_API}` for inter-service coordination. The exact endpoints called are not fully visible in the player-api spike but the env var is present in the ECS task definition.
- `fmcom-api` exposes `/internal/**` endpoints protected by an API key header (`InternalApiKeyAuthFilter`), used by peer microservices including the YouTube downloader.
- The two services share a MySQL database but each runs Liquibase independently — schema changes in one service can affect the other.

### fmcom-api / fmcom-player-api → rnf (playlist and media boundary)

- Both `fmcom-api` and `fmcom-player-api` hold separate Feign HTTP clients calling `GET /playlist/current/{screenId}` on `rnf` (`PlaylistCurrentController`). This is the synchronous read path for live playlist delivery.
- `fmcom-api` sends media processing work to `rnf` via JMS on `RNF_MEDIA_PROCESSING` (unified pipeline), and also via `RNF_GENERATE` (playlist generation triggers), `RNF_OPEN_HOURS_UPDATED`, `RNF_RECENTLY_ACTIVATED`, `RNF_PDF_TO_IMAGE_DESTINATION`, and `RNF_TRANSCODE_DESTINATION` (legacy shim, scheduled for removal). **C2 resolved: the JMS + Feign split is confirmed.** JMS is the asynchronous work-dispatch path (media, playlist generation triggers, org events); Feign HTTP is the synchronous playlist-fetch path.
- `rnf` publishes back to `fmcom-api` via JMS (`API_CONTENT_ADD` after transcoding completes) and to `fmcom-player-api` via JMS (`PLAYER_CONTENT_TRANSCODED`, `PLAYER_CONTENTS_TRANSCODED_BATCH`, `PLAYER_ORGANIZATION_CONTENT_UPDATED`, `PLAYER_SCREEN_CONTENT_UPDATED`).
- `rnf` serves pre-computed playlists from Elasticsearch — it does not resolve playlists on demand at the HTTP call. The SOV and scheduling work happens in background XXL-Job sweeps.
- `rnf` depends on `state-service` via `InstanceStateClient` (ping/heartbeat) with a hard `System.exit(-1)` on connection loss — this couples `rnf` availability directly to `state-service` availability.
- `PlaylistCurrentServiceLocal` in `fmcom-player-api` is an alternate playlist path (`fm-common` `PlaylistCurrentServiceModule` reading directly from Elasticsearch), but its role as a circuit-breaker fallback vs. a separate flow (e.g., Consult mode) is not confirmed in spike evidence. **C6 remains open.**
- `rnf` is a critical dependency for both services — its SLA directly affects playlist delivery latency and availability. The `prod-perf` ECS variant (`reach-n-freq-perf`) runs `TriggerMode.REST_BULK` operations without competing with live JMS message traffic.

### fm-common as shared contract layer

- `fm-common` (JAR) defines all JMS destination constants (31 typed `JmsDestination<T>` instances in the `Destinations` interface), Redis key namespaces (`TelemetryRedisKeys`, `RedisChannels`, `CacheConstant`), Elasticsearch index names (`ElasticsearchIndex` with `ES_PREFIX` env-var namespacing), domain model types (`ScreenDto`, `ContentDto`, `PlaylistCurrentDto`, `TelemetryDto`, and 100+ others), 80+ MySQL JPA entity and repository modules, shared service implementations (`TelemetryService`, `ContentQuarantineService`, `SovRuleService`, `AuthService`, `ContentService`, `PlaylistCurrentService`, `MessagingService`), and Feign clients for `state-service` (`ScreenStateClient`, `InstanceStateClient`, `AuthServiceClient`, `BrokerStateClient` in `StateClientModule`).
- Four production version skews exist: `fmcom-api` at 8.9.0, `fmcom-player-api` at 8.8.9, `rnf` at 8.9.1, `state` at 8.7.8. The 8.9.x line introduced significant additive capabilities: typed JMS destination system, `AuthModule`/`AuthServiceClient`, `BrokerStateClient`, `TelemetryRedisKeys` (authored 2026-04-03), `ContentQuarantineService` (authored 2026-03-30), `TelemetryService` (authored 2026-04-25), and the Elasticsearch throttle system. The 8.8.9 → 8.9.x delta is not cosmetic. State-service at 8.7.8 is the furthest behind and does not have the typed JMS destination system — DTO serialization compatibility with 8.9.x services is unverified.
- No CHANGELOG exists for `fm-common`. Version upgrade decisions require diffing source on Bitbucket. No automated cross-version integration test is visible in any service's pipeline.
- Redis keyspace isolation is naming-convention only — no Redisson namespace prefix, no separate Redis DB per service (`fmcom-api` and `fmcom-player-api` write to the same logical Redis database). `TelemetryRedisKeys` and `RedisChannels` are in separate classes with different naming conventions — no unified key registry.
- JMS destination names are unversioned bare strings in `Destinations.Key`. The typed `JmsDestination<T>` wrapper enforces payload types at compile time but provides no runtime schema enforcement. A destination rename in a new `fm-common` version silently partitions publishers and subscribers.
- All module activation is explicit `@Import` — no auto-configuration. Consuming services must explicitly import each module they use. Missing imports fail at startup with `NoSuchBeanDefinitionException`.

### fmcom-api / fmcom-player-api / rnf → state-service (screen state and auth boundary)

- All three backend services call `state-service` via Feign clients in `fm-common` `StateClientModule`: `ScreenStateClient` (50+ methods: screen CRUD, bulk updates, paginated queries, analytics queries), `InstanceStateClient` (liveness ping), and `AuthServiceClient` (token lifecycle).
- `state-service` holds the live snapshot of every `ScreenDto` in a JVM-resident `ConcurrentHashMap`. Reads return from memory in microseconds; MySQL is consulted only on first access. **Open Question 1 (system map) partially resolved**: `state-service` is the runtime source of truth for screen state, but `fmcom-api` also imports `MySqlScreenModule` directly and can write to the `screen` table without going through `state-service`. No write-path enforcement exists at the network or DB level — direct `fmcom-api` DB writes bypass the in-memory cache, creating a divergence window. The authority boundary is confirmed as ambiguous; no documented policy governs which writes legitimately bypass `state-service`.
- `state-service` also owns auth token issuance and verification (`AuthServiceClient` → `state-service` `/auth/**`). Auth is not Redis-backed — tokens are persisted in a local `user_token` MySQL table. All services that import `AuthModule` from `fm-common` delegate token operations to `state-service`.
- `fmcom-player-api` also calls `state-service` via `BrokerStateClient` for HTTP long-poll message delivery (`POST /broker/consume`, up to 22 s hold), replacing direct Amazon MQ connections for some player-api messaging paths. This is an in-process broker in `state-service` memory — at-most-once delivery; messages lost on ungraceful shutdown.
- `rnf` has a hard liveness dependency: `FeignConfig.connectionCheck()` pings `state-service` on a 1-minute `@Scheduled` timer and calls `System.exit(-1)` if the ping fails. This means any transient `state-service` outage or network hiccup terminates `rnf` containers, abandoning in-flight transcodes.
- `state-service` is also the sole coordinator for Elasticsearch query budget allocation: it subscribes to `ELASTICSEARCH_INSTANCE_REGISTERED`/`ELASTICSEARCH_QUOTA_REQUEST`/`ELASTICSEARCH_PERFORMANCE_FAILURE` on Amazon MQ and broadcasts `ELASTICSEARCH_LIMITS_ALLOCATED` to all registered instances. A `state-service` outage causes all services to fall back to `initial-limit` (1 query/instance in dev, 3 in prod), degrading search and analytics platform-wide.
- No `SecurityFilterChain` is configured in `state-service` — all endpoints (`/screen/**`, `/auth/**`, `/broker/**`, `/elasticsearch/**`) are unauthenticated at the HTTP layer. Security relies entirely on VPC network isolation.

### Frontend → @vrtly/component-library (design system dependency)

- `fmcom-vrtly-fe-monorepo` depends on `@vrtly/component-library` at `^0.8.20` from AWS CodeArtifact. All four SPAs (vrtly-home, VPM, VAM, onboarding) consume this library.
- Element Plus is declared as a peer dependency but is bundled into the library's output (`dist/component-library.mjs`) rather than externalized. Any consuming SPA that also depends on Element Plus will bundle two copies — duplicate code, inflated bundle size, and potential runtime issues with EP's global state (message instances, dialog stack).
- The library is ESM-only with no CJS output. The `package.json` `require` field incorrectly points to the `.mjs` ESM file — any toolchain evaluating the `require` condition will fail.
- Breaking-change risk areas: prop interface changes on `VrtlyContentCard` (encodes `quarantineType`, `transcodingStatus`, `scheduleStatus` directly from API shapes), changes to `_element.scss` (global EP variable overrides affecting all components), and icon renames in `src/assets/icons/index.ts` (consumed as raw string imports with no TypeScript name-safety on destructure).
- No CHANGELOG; no integration test pipeline that validates the library against the monorepo's actual usage. Version coordination is manual and undocumented.

### Amazon MQ as integration bus

- JMS destination names are typed constants in `fm-common` `Destinations` (31 `JmsDestination<T>` instances). Each destination has a typed payload class enforced at compile time. No runtime schema registry or contract enforcement at the broker level.
- `fmcom-api` and `fmcom-player-api` share topics: `API_CONTENT_QUARANTINE` is published by `fmcom-player-api` (and via `fm-common` `ContentQuarantineService`) and consumed by `fmcom-api` for quarantine processing.
- `API_CONTENT_ADD` is published by both `rnf` (after transcoding) and `fmcom-api` (for non-transcoding content events). Dual publishers on the same destination require idempotent consumer logic in `fmcom-api`'s `ContentMessageHandlers`.
- `BROKER_PREFIX` env var scopes all destination names per environment (dev prefix `"dev"`, prod empty) — preventing cross-environment message delivery.
- Feature flags (`@ConditionalOnProperty`) gate multiple JMS consumers in `fmcom-api` — in dev/QA some consumers are disabled, meaning messages may accumulate or be dropped silently.
- Dev/QA task definitions for both `rnf` and `state` expose broker credentials as plaintext environment variables — a confirmed credential hygiene risk across the platform.

---

## Ecosystem Gaps

The following services and packages are referenced within the analyzed repos but remain unanalyzed. Each is a gap for follow-up architecture documentation.

| Gap | Referenced by | Evidence | Follow-up needed |
|---|---|---|---|
| **`youtube-downloader` service** | `fmcom-api` (JMS `YOUTUBE_DOWNLOAD_DESTINATION`, internal HTTP `/internal/youtube-downloads/**`), `rnf` (`YoutubeContentDownloadReenqueueJob` — purpose unclear given fmcom-api owns download lock management) | Bidirectional: `fmcom-api` dispatches jobs; downloader calls `/complete` or `/fail` back. `rnf` also has a re-enqueue job for stuck downloads. | Spike needed: download concurrency model, heartbeat protocol, failure/retry behavior, relationship between rnf `YoutubeContentDownloadReenqueueJob` and fmcom-api `YoutubeDownloadRescueService` |
| **`cordova-player` (FireTV shell)** | `html5core` (README, `window._cordovaNative` bridge) | Provides device UUID, model, platform, shell version to `html5core` | Spike needed: update delivery model (does shell always load from S3 or can it bundle locally?), versioning contract with `html5core` |
| **Roku player app** | `fmcom-player-api` (`RokuMacMigrationService`, `RokuCertOverrideService`, MAC format migration) | Special-case MAC address handling and certification demo account logic woven into session and registration | Spike needed: Roku device protocol, MAC format, auth scheme, firmware version compatibility |
| **Android TV player app** | `fmcom-player-api` (device types in `ScreenDto`, platform enum values) | Implied by multi-platform device type support | Spike needed: tech stack, protocol compatibility with `fmcom-player-api` |
| **`my.vrtly.app` public portal (info-pack consumer)** | `fmcom-vrtly-fe-monorepo` (`VITE_INFOPACK_URL`), `html5core` (`qrCodeBuilder.ts`) | Referenced as QR code landing page; URLs encrypted server-side before embedding | Spike needed: tech stack, content rendering, encrypted payload format, patient session model |
| **XXL-Job admin server** | `fmcom-api` (executor port 9999, 15+ job handlers), `fmcom-player-api` (executor port 9997, telemetry cleanup), `rnf` (executor port 9996, 18 handlers) | Admin URL: `https://jobs.prod.vrtly.app/job-admin/`; `rnf` also has a `prod-perf` ECS variant | Operational gap: job inventory, scheduling config, failure alerting, single-point-of-failure risk assessment. `doc/scheduler-design.md` in `state-service` proposes retiring XXL-Job in favor of `state-service` as distributed cron coordinator |
| **GCP Firebase / Pub/Sub pipeline** | `fmcom-api` (`GcpPubSubWebhookController`, `ExternalEventConverter` plugin chain) | Inbound webhook at `/webhook/gcp/pubsub`; only `CrashlyticsConverter` visible | Gap: additional converter implementations (Firebase Analytics, other GCP log sources), event schema, volume |
| **Elasticsearch throttling / quota system** | `fmcom-api`, `fmcom-player-api`, `rnf`, `state` (`fm-common` `ThrottlingServiceModule`; `state` is the sole coordinator) | Config refs `elasticsearch.throttle.*`; `service-id: api/player/rnf/state`; `state-service` subscribes to ES-limit JMS topics and broadcasts `ELASTICSEARCH_LIMITS_ALLOCATED` | Coordinator is `state-service` — a `state-service` outage drops all services to `initial-limit` (1–3 queries/instance). Gap: throttle behavior under saturation, how `ElasticsearchLimitAllocator.requestQuotaIncreaseForHeavyJob()` from `rnf` daily sweep interacts with concurrent fmcom-api ES activity, circuit breaker semantics |
| **OutScraper API** | `rnf` (`OutScraperApiService`, `OrganizationInfoUpdateJob`, `RecentlyActivatedHandlers`) | `https://api.outscraper.cloud`; per-request billing; no visible rate limiter or circuit breaker | Gap: rate limit / cost ceiling, API key rotation process, behavior on OutScraper service degradation |
| **Salesforce CRM integration** | `rnf` (sync jobs: organization, screen, user; long-poll tasks), `state` (`SalesforceNotificationService` in `fm-common` on every screen persist) | Feign-backed (`SalesforceAuthFeignClient`, `SalesforceDataFeignClient`, `SalesforceBatchFeignClient`); gated by `salesforce.enabled` | Gap: Salesforce org structure, field mappings, sync failure handling, impact of `salesforce.enabled=false` in some environments |
| **`prod-perf` RNF environment** | `rnf` (`bitbucket-pipelines.yml`, `prod-perf-task-definition.json`) | `reach-n-freq-perf` ECS service in `production-vrtly-ecs-cluster`; separate task definition | Gap: when is `prod-perf` used, who triggers it, does it share Amazon MQ broker with prod (same endpoint visible in task definition) |

---

## Review Findings

### Confirmed Claims

**1. Four analyzed services, correct stacks.**
All four service stacks listed in the Service Inventory are directly confirmed by the tech spikes: Spring Boot 3.2.x / Java 17 for both backend APIs (fmcom-api spike §Tech Stack, fmcom-player-api spike §Tech Stack), Vue 3 / Pinia / TypeScript / Vite for the monorepo (fe-monorepo spike §Tech Stack), Vue 3 / Pinia / TypeScript / Vite / `crypto-js` for `html5core` (html5core spike §Tech Stack). The deployed-to-S3/CloudFront claim for both SPAs is confirmed by `bitbucket-pipelines.yml` references in both spikes.

**2. `fm-common` version skew (8.9.0 vs 8.8.9).**
Confirmed explicitly in both backend spikes: fmcom-api spike lists `fm-common (internal artifact 8.9.0)`, fmcom-player-api spike lists `fm-common 8.8.9`.

**3. Amazon MQ JMS topic inventory.**
The map lists the correct inbound and outbound JMS destinations for `fmcom-api`. The fmcom-api spike §External Integrations explicitly enumerates: inbound `API_CONTENT_ADD`, `API_CONTENT_QUARANTINE`, `API_CONSULT_EMAIL_SEND`, `YOUTUBE_UPDATE_URL`; outbound `RNF_MEDIA_PROCESSING`, `YOUTUBE_DOWNLOAD`, `API_CONTENT_ADD`, `API_CONSULT_EMAIL_SEND`. The claim that `fmcom-player-api` subscribes to 9 `PLAYER_*` topics and publishes `API_CONTENT_QUARANTINE` is confirmed in fmcom-player-api spike §External Integrations: "Subscribes to 9 `PLAYER_*` topics ... Also publishes `API_CONTENT_QUARANTINE` on restore."

**4. `html5core` → `fmcom-player-api` request signing scheme.**
Confirmed in both spikes. The fmcom-player-api spike §Notable Patterns observation #2 states: "`SecurityInterceptorServiceImpl` authenticates devices by computing `SHA-1(serialNumber + timestamp)`." The html5core spike §utils/api.ts confirms the client side: "`apiRequest()`: wraps `fetch`, adds device serial + timestamp + SHA-1 signature." The 300-second replay window is confirmed in the player-api spike.

**5. `html5core` activation polling loop.**
Confirmed in html5core spike: `src/store/checkActivation.ts` "Polls `player/registerDevice` on 3-second intervals until activation confirmed." The system map's 3-second interval is accurate.

**6. AES-CBC response encryption with server-provided key stored in Pinia memory only.**
Confirmed in html5core spike §security.ts: "AES-CBC encryption/decryption using `crypto-js`; key is double-encrypted (server-provided key is itself encrypted with `'friendmediamedia'` as both key and IV)." The claim that the key is "stored in Pinia memory only and lost on reload" matches the spike's Open Question #5: "The security key returned by `player/registerDevice` (code `10002`) is stored only in memory (Pinia state)."

**7. `fmcom-player-api` private key committed to source — critical security gap.**
Confirmed in fmcom-player-api spike §Notable Patterns observation #3: "`src/main/resources/private_key.pem` and `prod_private_key.pem` are checked into the repository."

**8. Redis database index separation between services.**
Confirmed in fmcom-player-api spike §External Integrations: "Database index: `4` (dev), `2` (prod)." The system map's claim of "fmcom-api: default; fmcom-player-api: DB 4 dev / DB 2 prod" is accurate.

**9. MySQL pool sizes.**
Confirmed: fmcom-api spike lists "pool size 10"; fmcom-player-api spike lists "Pool size: 150 connections in prod." Both match the system map's Shared Infrastructure table.

**10. XXL-Job executor ports.**
Confirmed: fmcom-api spike §External Integrations states "executor port 9999"; fmcom-player-api spike states "Executor port `9997`." Both match the system map.

**11. `html5core` calls `fmcom-api` for Info Pack QR encryption.**
Confirmed in html5core spike §qrCodeBuilder.ts: "Builds encrypted Info Pack QR code URLs by calling `api.vrtly.ai/cms/encrypt`." The map correctly identifies this as the only cross-domain call from the player app to the CMS API. The spike also shows a second endpoint: `cms/qr-code/generate-qr-code` (html5core spike §External Integrations row "Vrtly CMS API").

**12. ABR escalation ladder stages.**
Confirmed in fmcom-player-api spike §PlaybackEscalationStage: "`HLS_FULL → HLS_720 → SRC_ORIGINAL → SRC_720 → SRC_540 → QUARANTINE`." Matches the system map verbatim.

**13. Playback telemetry is WebSocket-batched via localStorage queue.**
Confirmed in html5core spike §telemetry/: "Structured telemetry subsystem ... `telemetryQueue` (localStorage-buffered batch sender via WebSocket)." The system map's claim that `html5core` "batches telemetry events in a localStorage queue and flushes them over WebSocket" is accurate.

**14. `fmcom-player-api` per-screen quality cap: 30-minute Redis TTL.**
Confirmed in fmcom-player-api spike §Notable Patterns observation #5: "`settle-grace-minutes` (default 30) window." The system map states "writes a per-screen Redis entry (30 min TTL)" — observation #1 of §Telemetry and ABR mitigation.

**15. `fmcom-api` exposes `/internal/**` protected by API key.**
Confirmed in fmcom-api spike §controller/internal: "Service-to-service endpoints (`/internal/**`), protected by API key. Notably `InternalYoutubeDownloadController` (claim/heartbeat/complete/fail for download lock protocol)." The YouTube downloader bidirectional HTTP flow described in the map matches the spike.

**16. `fmcom-vrtly-fe-monorepo` dual Axios instances.**
Confirmed in fe-monorepo spike §Notable Patterns: "There are two distinct Axios instances: one in `packages/api/request/index.ts` (the shared client) and a near-identical one in each app's `src/utils/request.ts`." The system map's claim "a legacy duplicate exists per-app in `src/utils/request.ts` for VPM" is confirmed — though the spike notes the duplication extends beyond just VPM.

**17. `@vrtly/component-library` from AWS CodeArtifact at `^0.8.20`.**
Confirmed in fe-monorepo spike §Tech Stack: "`@vrtly/component-library` 0.8.x (external private npm package, served from AWS CodeArtifact)."

**18. GCP Pub/Sub inbound webhook at `/webhook/gcp/pubsub`.**
Confirmed in fmcom-api spike §controller/webhook: "`GcpPubSubWebhookController`" and §External Integrations: "Inbound HTTP push webhook (`/webhook/gcp/pubsub`)." Only the `CrashlyticsConverter` implementation is visible, consistent with the map's gap note.

**19. `fmcom-vrtly-fe-monorepo` four-app structure.**
Confirmed: fe-monorepo spike §Apps lists vrtly-home, vrtly-practice-manager (VPM), vrtly-ad-manager (VAM), and onboarding — matching the map's service table entry.

**20. Shared Elasticsearch cluster with per-service throttling.**
Confirmed in fmcom-player-api spike §External Integrations: "Throttling is configurable (initial limit 3 in prod)." The fmcom-api spike §External Integrations lists 25+ index modules. The map's note that both services share the same cluster and throttle via `ThrottlingServiceModule` (`service-id: api`, `service-id: player`) is consistent with spike evidence.

---

### Challenged Claims

**C1. "fmcom-player-api references `${SERVICE_DISCOVER_API}` ... exact endpoints called are not fully visible."**
The map frames this as uncertain. The fmcom-player-api spike §External Integrations is unambiguous: "api service — HTTP (config) — `${SERVICE_DISCOVER_API}` referenced for inter-service coordination. In prod: `https://api.prod.vrtly.app`." The spike does confirm this env var is present and resolves to the production CMS API URL. However, neither spike surfaces which specific `/internal/**` endpoints `fmcom-player-api` actually calls on `fmcom-api`. The map's hedging is defensible, but the direct HTTP dependency (not just via MQ) between player-api and fmcom-api should be represented more prominently in the Mermaid diagram — the current `PLAYERAPI -->|SERVICE_DISCOVER_API (internal HTTP)| FMAPI` edge exists but carries no label indicating the direction of data or which paths are called.

**C2. "fmcom-api dispatches transcoding jobs via JMS `RNF_MEDIA_PROCESSING` destination to `rnf`."**
The system map (§Content upload and transcoding, step 2) states: "`fmcom-api` ... dispatches a JMS message to Amazon MQ (`RNF_MEDIA_PROCESSING` destination)." The fmcom-api spike §service/media confirms this through `MediaProcessingDispatcher` as the "single outbound entry point for all media operations dispatched to RNF over JMS." However, the fmcom-api spike §External Integrations also lists `RnfFeignClient` (`GET /playlist/current/{screenId}` via Feign HTTP) as a separate, synchronous integration. The map conflates two distinct integration paths with `rnf`: JMS for media processing dispatch and Feign HTTP for playlist resolution. In the Mermaid diagram the `FMAPI -->|Feign HTTP| RNF` edge is present, but the narrative in step 2 omits the Feign path entirely, which could cause readers to misunderstand the rnf dependency surface.

**C3. "rnf receives `API_CONTENT_ADD` completion events back via JMS."**
The system map §Content upload, step 3 states: "`rnf` ... publishes completion events back via JMS (`API_CONTENT_ADD`)." However, the fmcom-api spike §External Integrations shows `API_CONTENT_ADD` in both the inbound (subscribe) and outbound (publish) sets for `fmcom-api` itself: "4 inbound JMS queues handled: `API_CONTENT_ADD` ... outbound: `RNF_MEDIA_PROCESSING`, `YOUTUBE_DOWNLOAD`, `API_CONTENT_ADD`." This creates ambiguity: does `fmcom-api` self-publish `API_CONTENT_ADD` after transcoding (a self-referential JMS pattern), or does `rnf` publish it and `fmcom-api` subscribes? The map asserts `rnf` as the publisher without evidence. The spike does not confirm what entity publishes `API_CONTENT_ADD` — calling this confirmed is unsupported. The map should flag this as a gap.

**C4. "PROVIDER users ... SPONSOR users" routing based on `organization.type` from login response.**
The map §CMS user session, step 4 says: "`vrtly-home` reads `organization.type` from the login response." The fe-monorepo spike §Notable Patterns states: "When a SPONSOR organization ... hits the VPM root (`home` route), they are redirected to `/brands` (VAM). The check is client-side only, relying on `organization.type` in localStorage." The routing check occurs against the localStorage-persisted value, not necessarily freshly from the login response. This is a subtle but materially different behavior — if `organization.type` in localStorage is stale, the routing decision is wrong. The map's framing implies the type is read fresh from the login payload, which is not precisely what the code shows.

**C5. "The admin diagnostics dashboard in `fmcom-api` reads `MITIGATION` events from Elasticsearch."**
The map §Telemetry and ABR mitigation, step 5 states: "`MITIGATION` telemetry events are written to Elasticsearch; the admin diagnostics dashboard in `fmcom-api` reads these for operator visibility." The fmcom-api spike mentions "admin diagnostics HTML page" rendered via Thymeleaf but does not explicitly confirm it reads MITIGATION events from Elasticsearch. The fmcom-player-api spike (observation #1) says MITIGATION events are "publishing `MITIGATION` telemetry events to Elasticsearch so the diagnostics dashboard shows the full set/clear lifecycle" — but that diagnostics dashboard could belong to either service. The claim that it sits in `fmcom-api` is an inference, not confirmed evidence.

**C6. "playbackController uses `PlaylistCurrentServiceLocal` as a local fallback."**
The map §rnf boundary states: "except `PlaylistCurrentServiceLocal` in player-api as a local fallback, details unclear." The fmcom-player-api spike §service/impl confirms `PlaylistCurrentServiceLocal` exists but also notes its purpose is "local playlist assembly" — the spike itself does not clarify whether this is a circuit-breaker fallback or an alternative flow (e.g., for Consult mode or custom playlists). The map's characterization as a "local fallback" for the rnf Feign path is an inference not directly confirmed by spike evidence.

**C7. The `VITE_REACH_AND_FREQUENCY_URL` claim.**
The map's Service Inventory lists VAM calling `VITE_REACH_AND_FREQUENCY_URL` → `fmcom-api`, and the Mermaid diagram shows `VAM -->|REST /cms/*\nVITE_REACH_AND_FREQUENCY_URL| FMAPI`. However, the fe-monorepo spike §Open Questions #2 states: "`VITE_REACH_AND_FREQUENCY_URL = 'https://rnf.dev.vrtly.app'` is referenced in VAM's dev env but **no usage was found in the VAM source code** during this audit." The map shows this as an active data flow from VAM to `fmcom-api`. Based on the spike evidence it is more likely dormant or a WIP integration directly to `rnf`, not to `fmcom-api`. The Mermaid diagram edge is potentially misleading.

---

### Missing Connections or Gaps

**M1. `html5core` → `fmcom-player-api`: `report/content` flow not in the Data Flow Narrative.**
The `report/content` path (html5core spike §playedContentReport.ts) is a separate HTTP `POST` submitted every 7 minutes — not via WebSocket — and is not mentioned anywhere in the map's Data Flow Narrative. The Mermaid edge `REST /player/*` covers it implicitly but it warrants a dedicated narrative step given its role in analytics and billing. *(Now partially addressed: added as step 6 of Flow 4.)*

**M2. `html5core` → `fmcom-player-api` plan reporting endpoint is unrepresented.**
The html5core spike §plan.ts describes `usePlan` sending the upcoming playback schedule (next 10 items) to `player/plan` whenever the content index changes. It is covered by the `REST /player/*` diagram edge but has no narrative mention. It is also uncertain whether this store is actually activated in the running app — spike Open Question #2.

**M3. `fmcom-player-api` dynamic HLS master playlist endpoint is unauthenticated.**
`/player/content/stream/{store}/{id}/{res}/{filename}.m3u8` is explicitly excluded from security and session interceptors. *(Now addressed: noted in Integration Points under html5core → fmcom-player-api.)*

**M4. `fmcom-player-api` Bucket4j rate limiting layer.**
The fmcom-player-api spike §Tech Stack lists Bucket4j 8.10.1 for in-memory/Redis-backed rate limiting on HTTP and WS handshake. The system map's interceptor description mentions security and session interceptors but not rate limiting. Low-priority documentation gap — no architectural decision depends on it currently.

**M5. `fmcom-player-api` in-memory session store is not horizontally safe.**
*(Now addressed: noted in Integration Points under html5core → fmcom-player-api.)*

**M6. URL inconsistency: `api.vrtly.app` vs `api.prod.vrtly.app`.**
The fe-monorepo spike uses `api.vrtly.app` (CMS surface); the fmcom-player-api spike uses `api.prod.vrtly.app` (inter-service). These may be two DNS names for the same ECS service or two separate ingress paths. Requires client confirmation before the next spike phase.

---

## Review Findings — Gap Fill Pass (2026-06-12)

The four gap spikes (rnf, state-service, fm-common, @vrtly/component-library) represent a substantial improvement in platform coverage. The rnf and state-service spikes are detailed and technically rigorous. The fm-common spike is valuable as a ground-truth inventory of JMS destinations, Redis key namespaces, and shared module boundaries. The component-library spike is thorough on UI risks. However, the gap fill is uneven in one important respect: it resolves the factual questions (who does what, how is it wired) but systematically defers the most operationally dangerous findings — version skew consequences, authority boundary resolution, dual-publisher idempotency — to open questions rather than stating verdicts. Several Phase 2 system-map edits assert resolutions that the spike evidence only partially supports, and a meaningful cluster of new internal contradictions has been introduced. The overall pass raises the confidence level of the system map substantially but introduces at least seven new challenged claims that must be tracked.

---

### C1–C7 Verdict Block

**C1 — `fmcom-player-api` → `fmcom-api` `SERVICE_DISCOVER_API` endpoint list: STILL OPEN.**
The rnf spike does not address this claim at all — rnf does not call `fmcom-api` directly via HTTP. The state-service spike does not address it either. The fm-common spike confirms `ScreenStateClient` and `InstanceStateClient` signatures but says nothing about `fmcom-player-api` calling `fmcom-api`'s internal endpoints. The original challenge — that the specific `/internal/**` paths called by `fmcom-player-api` on `fmcom-api` were never identified — is not resolved by any of the four gap spikes. The system map's hedge ("exact endpoints called are not fully visible") remains precisely as hedged as before.

**C2 — JMS + Feign split between `fmcom-api`/`fmcom-player-api` and `rnf`: RESOLVED.**
The rnf spike directly confirms both integration paths in its External Integrations table: `fmcom-player-api` calls `GET /playlist/current/{screenId}` on `PlaylistCurrentController` (Feign HTTP, synchronous), and `fmcom-api` sends work via `RNF_MEDIA_PROCESSING`, `RNF_GENERATE`, and related queues (JMS, asynchronous). The system map Phase 2 update ("C2 resolved: the JMS + Feign split is confirmed") is well-supported. The rnf spike also confirms that `PLAYER_ORGANIZATION_CONTENT_UPDATED`, `PLAYER_CONTENT_TRANSCODED`, and `PLAYER_CONTENTS_TRANSCODED_BATCH` are published by rnf — consistent with the system map's outbound JMS table for rnf.

**C3 — Who publishes `API_CONTENT_ADD`: PARTIALLY RESOLVED.**
The rnf spike explicitly states: "RNF is the publisher of `API_CONTENT_ADD`" (Notable Patterns §1, and the "What This Service Does" section). This confirms that `UnifiedVideoPipeline.onComplete()` publishes `ContentAddMessage` to `API_CONTENT_ADD` for `TriggerMode.MESSAGE` flows. The system map Phase 2 update adds the correct dual-publisher nuance — rnf publishes after transcoding; `fmcom-api` also publishes for "non-transcoding content events." However, "non-transcoding content events" is a phrase the rnf spike itself introduces without listing the specific `fmcom-api` code paths that publish. The fm-common JMS table lists `API_CONTENT_ADD` publisher as "fmcom-api (content upload → triggers screen content association)" — but that description is consistent with fmcom-api publishing it at the point of upload, before rnf processes it, which would make it a separate event, not self-publishing after transcoding. The claim in the Phase 2 system map that `ContentMessageHandlers` "must handle idempotent delivery" is an architectural assertion not validated by any spike. The rnf Open Question 1 explicitly asks: "is the consumer idempotent?" — meaning this is still an open question at the time of the spike. The resolution is genuine on "rnf publishes after transcoding" but remains open on "what does fmcom-api publish to the same queue and is the consumer idempotent."

**C4 — `organization.type` routing from login response vs. localStorage: STILL OPEN.**
None of the four gap spikes covers `fmcom-vrtly-fe-monorepo` routing behavior. The original challenge stands: the routing check reads from locally-persisted localStorage, not from the live login response. No gap spike addresses this distinction and the system map text was not updated to correct the framing.

**C5 — Admin diagnostics dashboard owner (`fmcom-api` vs. `fmcom-player-api`): STILL OPEN.**
None of the four gap spikes covers this. The fm-common spike confirms `TelemetryService` is shared by both services, but does not resolve which service hosts the admin diagnostics page that reads MITIGATION events. The state-service spike makes no mention of it. The challenged claim was not addressed.

**C6 — `PlaylistCurrentServiceLocal` as circuit-breaker fallback vs. separate flow: STILL OPEN.**
The rnf spike describes `PlaylistCurrentServiceLocal` as a service in rnf's own `service/` package (not fmcom-player-api) and lists it as serving the `GET /playlist/current/{screenId}` endpoint directly. The fm-common spike confirms `PlaylistCurrentServiceModule` as an activatable module with a `PlaylistCurrentService` that reads from `ElasticPlaylistSchedule`. The system map's framing — that `PlaylistCurrentServiceLocal` in `fmcom-player-api` is a fallback for rnf unavailability — is contradicted by the rnf spike: the class with that name in rnf is the *primary* implementation of the playlist endpoint, not a fallback. Whether `fmcom-player-api`'s `PlaylistCurrentServiceModule` import is an active fallback or a dead path remains unresolved, and the existing system-map text at the end of §fmcom-api/fmcom-player-api → rnf boundary perpetuates the confusion. The spike evidence actually weakens the "fallback" interpretation.

**C7 — `VITE_REACH_AND_FREQUENCY_URL` VAM → `fmcom-api` edge: STILL OPEN.**
None of the gap spikes covers the fe-monorepo. The challenged claim — that this env var is referenced in VAM's dev env but has no usage in VAM source — was not investigated or resolved by any of the four gap spikes. The Mermaid diagram edge `VAM → fmcom-api via VITE_REACH_AND_FREQUENCY_URL` remains potentially misleading.

---

### New Challenged Claims

**NC1. The system map states `API_CONTENT_ADD` has "two independent publishers" and the consumer "must handle idempotent delivery." This is an unverified architectural assertion.**
The fm-common JMS destination table lists `API_CONTENT_ADD` as publisher "fmcom-api (content upload → triggers screen content association)" with subscriber "fmcom-api (`ContentMessageHandlers`)." The rnf spike confirms rnf also publishes to this destination after transcoding. However, neither spike shows the `ContentMessageHandlers` implementation. The Phase 2 system-map addition asserts idempotency as a requirement without evidence that it is actually implemented. If `ContentMessageHandlers` performs a non-idempotent "add content to default screen" operation, duplicate messages will corrupt screen content assignments. This is stated as a resolved architectural note but is actually an untested assumption.

**NC2. The state-service spike reveals a direct contradiction with Confirmed Claim 2 (fm-common version skew) and the system-map service table.**
The system map Service Inventory lists `state` as pinning `fm-common` 8.7.8, while `fmcom-api` is at 8.9.0 and `rnf` is at 8.9.1. The state-service spike (Notable Patterns §13) confirms this and explicitly flags it as a risk: fields present in 8.9.0 not in 8.7.8 will be silently dropped. However, the system map does not call out the most dangerous concrete consequence: `state-service` at 8.7.8 does not have the typed `JmsDestination<T>` pattern or the `TelemetryRedisKeys` class or the `ContentQuarantineService` that were introduced in the 8.9.x line. The fm-common spike confirms all of these are 8.9.x additions. This means `state-service` and `fmcom-api` are not on the same JMS contract layer — state-service subscribes to JMS topics using the pre-typed-destination API, while rnf and fmcom-api publish using the typed `JmsDestination<T>` system. Whether the two serialization paths are wire-compatible is unverified by any spike.

**NC3. The fm-common spike lists `PLAYER_SCREEN_QUALITY_CAP_NOTIFY` publisher as "state service / `PlaybackQualityCapRule`" — but the system map does not list state-service as a publisher of this topic, and the state-service spike does not mention it.**
The system map's Amazon MQ section lists `fmcom-player-api` as subscribing to `PLAYER_SCREEN_QUALITY_CAP_NOTIFY` but does not identify the publisher. The fm-common JMS table attributes co-publication to state-service. The state-service spike makes no mention of `PlaybackQualityCapRule` or publishing to `PLAYER_SCREEN_QUALITY_CAP_NOTIFY`. This is an internal contradiction between the fm-common spike and the state-service spike: if state-service publishes this topic, it should appear in the state-service external integrations table. It does not. Either the fm-common spike's publisher attribution is wrong, or the state-service spike missed this publication path.

**NC4. The fm-common JMS table lists `PLAYER_SCREEN_UPDATED` publisher as "fmcom-api / state service" — but the state-service spike does not confirm that state-service publishes `PLAYER_SCREEN_UPDATED`.**
The state-service external integrations table lists outbound JMS as only `ALL_USER_ACCESS_CHANGED` and `ELASTICSEARCH_LIMITS_ALLOCATED`. If state-service also publishes `PLAYER_SCREEN_UPDATED`, this is a gap in the state-service spike's external integrations table. If it does not, the fm-common spike's publisher attribution for `PLAYER_SCREEN_UPDATED` is wrong. The system map Amazon MQ table (updated in Phase 2 to include state as a publisher of `ALL_USER_ACCESS_CHANGED` and `ALL_SYSTEM_PARAMS_CHANGED`) does not mention state-service publishing `PLAYER_SCREEN_UPDATED`, creating a three-way inconsistency between the system-map Phase 2 text, the fm-common spike, and the state-service spike.

**NC5. The system map states that `rnf` depends on `state-service` via `InstanceStateClient` for "screen state lookups" — but the rnf spike only confirms the ping/heartbeat use, not screen state lookups.**
The system map Integration Points section (fmcom-api / fmcom-player-api / rnf → state-service) states "All three backend services call `state-service` via Feign clients in `fm-common` `StateClientModule`: `ScreenStateClient` (50+ methods: screen CRUD...)." But the rnf spike External Integrations table lists only `InstanceStateClient` as the state-service Feign client used by rnf — used for the ping/heartbeat only. The rnf spike makes no mention of `ScreenStateClient` being imported by rnf. The fm-common spike confirms `ScreenStateClient` has 50+ methods but does not specify which services import it. The system map's claim that rnf calls `ScreenStateClient` may be incorrect — rnf may only use `InstanceStateClient` for liveness checks and access screen data directly via MySQL (`MySqlScreenModule`) rather than via state-service. If true, the dependency graph in the Integration Points section overstates rnf's dependency on state-service.

**NC6. The system map claims `PlaylistCurrentServiceLocal` is "an alternate playlist assembly path" in `fmcom-player-api` via `fm-common` `PlaylistCurrentServiceModule`. The fm-common spike confirms `PlaylistCurrentServiceModule` reads from `ElasticPlaylistSchedule` directly — but so does rnf's `PlaylistCurrentController`. Two services are reading from the same Elasticsearch playlist indices independently, with no coordination mechanism described.**
If `fmcom-player-api` activates `PlaylistCurrentServiceModule` and both rnf and player-api read from `ElasticPlaylistSchedule`, there are two independent readers of the pre-computed playlist data. This is not necessarily wrong, but neither spike explains the intended read priority or consistency model when `fmcom-player-api` calls rnf's `GET /playlist/current/{screenId}` (which rnf serves from its own `PlaylistCurrentController` backed by the same ES index). The question of why player-api would call rnf via Feign when it could read the same ES index directly is unresolved. The Phase 2 system-map note on this boundary perpetuates the ambiguity rather than resolving it.

**NC7. The state-service spike confirms `ScreenExtendedServiceImpl` always hits MySQL before checking the cache — contradicting the system map's characterization of state-service as a "microsecond in-memory read" service.**
The system map Platform Overview and the Integration Points section both describe state-service as returning screen data "from memory in microseconds" without touching MySQL. The state-service spike Notable Patterns §9 explicitly contradicts this for list queries: "MySQL is always hit regardless of cache state." The system map text is accurate for single-item `GET /screen/id/{id}` lookups but misleading as a general characterization of state-service performance. For `rnf`'s playlist generation sweep, which queries lists of screens, state-service is performing full MySQL reads on every call — doubling DB load. The system map's performance narrative for state-service should be qualified.

---

### New Risks & Observations

**NR1. `SalesforceNotificationService` is called from `ScreenPersistenceServiceImpl.save()` in state-service on every screen persist — meaning every screen write triggers a JMS publish to three Salesforce queues, regardless of what changed.**
The state-service spike External Integrations table confirms: "Called from `ScreenPersistenceServiceImpl.save()` after every screen persist." Three JMS topics are published (`RNF_SALESFORCE_ORGANIZATION_UPDATED`, `RNF_SALESFORCE_SCREEN_UPDATED`, `RNF_SALESFORCE_USER_UPDATED`). The rnf spike confirms rnf subscribes to all three Salesforce queues and runs CRM sync jobs. During a deployment window when `state-service` forces immediate flush of the entire dirty cache (`DeploymentSupportService.deployment = true`), thousands of screen persists will each trigger three JMS messages. This creates a JMS and rnf processing storm on every rolling deployment. Neither spike identifies a debounce, batch, or conditional-publish mechanism for Salesforce notifications.

**NR2. `fmcom-player-api` uses `BrokerStateClient` as an alternative JMS path through state-service's in-process broker. This means player-api JMS delivery is at-most-once, not guaranteed, and is independent of Amazon MQ's durability guarantees — but the system map Amazon MQ section does not differentiate which messages go through MQ vs. through the state-service broker.**
The state-service spike confirms: "Player-api instances use `BrokerStateClient` ... to publish and consume JMS-like messages without connecting to Amazon MQ directly." The fm-common spike confirms `BrokerStateClient` exists with publish/consume methods and that routing is governed by a `JmsMode` enum. The current system map Amazon MQ section lists all JMS destinations uniformly without noting that some player-api messages may route through state-service's in-process broker instead of Amazon MQ. This misrepresents the delivery semantics — at-most-once with 5-minute client expiry (state-service broker) is a materially different guarantee from Amazon MQ's at-least-once delivery. The routing rules (which messages go through MQ vs. state-service broker) are not documented in any spike.

**NR3. `state-service` has no `SecurityFilterChain` — all endpoints including `/screen/create`, `/auth/authorize`, and `/elasticsearch/limit/max` are unauthenticated within the VPC. The state-service spike explicitly names this as a blocking gap for the scheduler design. The system map mentions this under Integration Points but does not surface it as a platform-level risk in the Platform Overview or Shared Infrastructure sections.**
The state-service spike Notable Patterns §5 is unambiguous: "Any host with network access to the ECS task can read or mutate screen state, modify ES budget limits, or impersonate any other service." The `doc/scheduler-design.md` inside state-service calls this a "blocking decision." This is a critical security gap that affects all data flowing through state-service — not just screen state but auth tokens, ES quota governance, and the in-process message broker. The risk is not isolated to state-service; it extends to every service that trusts data returned from state-service without independent validation.

**NR4. The rnf `GenerateDailyPlaylistJob` daily sweep can silently miss screens with no alerting — the failure is invisible unless operators actively watch logs.**
The rnf spike Notable Patterns §13 confirms: "If generation exceeds these [30-min org / 5-min screen] timeouts, `waitForCompletion` returns the default value (null/empty set) silently." No metric is emitted; no alarm is triggered. This means a screen can go without a playlist update indefinitely and the platform has no automated detection. The system map does not capture this operational blind spot.

**NR5. `fm-common` is used by state-service at version 8.7.8, which predates the typed `JmsDestination<T>` system (added in 8.9.x per the fm-common spike). State-service publishes JMS messages using the pre-typed API while rnf (8.9.1) and fmcom-api (8.9.0) publish using the typed system. The fm-common spike confirms the type system enforces payload types at compile time but provides no runtime schema enforcement. If the wire format for JMS message serialization changed between 8.7.8 and 8.9.x, state-service and the other services may be exchanging messages with silently incompatible serialization.**
The fm-common spike Version Skew Analysis §2 identifies the typed JMS destination system as a "significant refactoring" introduced in 8.9.x. State-service subscribes to `ELASTICSEARCH_INSTANCE_REGISTERED`, `ELASTICSEARCH_QUOTA_REQUEST`, `ELASTICSEARCH_PERFORMANCE_FAILURE`, and `ELASTICSEARCH_INSTANCE_UNREGISTERED` — published by rnf and other services using the 8.9.x typed destination API. Whether the Jackson serialization of message payloads is backward-compatible between 8.7.8 and 8.9.x is unverified by any spike. A field added to a JMS payload DTO in 8.9.x would be silently ignored by state-service at 8.7.8 — the spike flags this risk but no spike resolves it.

**NR6. The `UnifiedVideoPipeline` `inPipeline` dedup set is JVM-local — a second rnf ECS instance (e.g., during a deployment overlap or in the `prod-perf` environment) has a separate `inPipeline` set and will not prevent duplicate in-flight transcoding of the same `contentId`.**
The rnf spike Notable Patterns §5 describes the `inPipeline` set as a "JVM-level dedup." With two rnf ECS instances running (rolling deployment, or `reach-n-freq-perf` running simultaneously with `reach-n-freq`), two instances can simultaneously claim and transcode the same content ID. The result would be two sets of S3 artifacts uploaded, a race condition on the final S3 write, and two `API_CONTENT_ADD` JMS messages published. The system map documents the `prod-perf` ECS variant as an ecosystem gap but does not surface the dedup collision risk.

**NR7. The component library bundles Element Plus rather than externalizing it, meaning every SPA in `fmcom-vrtly-fe-monorepo` ships two copies of Element Plus — one inside the component library bundle and one in the SPA's own bundle. This affects the initial load time for every provider and brand user on every page load.**
The component-library spike Notable Patterns §1 confirms: "Any consuming application that also depends on Element Plus will include two copies of the EP runtime." Element Plus is a heavyweight library. The monorepo pins both `@vrtly/component-library ^0.8.20` (which bundles EP) and presumably Element Plus directly. The user-visible impact is inflated bundle size for all four SPAs. This was previously noted in the system map's `@vrtly/component-library` section as a "risk of double-bundling" but the component-library spike now confirms it is not hypothetical — it is the actual build output.

**NR8. `state-service`'s `SyncOpService` uses a single `synchronized(locks)` monitor for all screen IDs. Under a high-throughput screen update burst, every screen write anywhere in the platform is serialized through this single lock. Combined with the 1-minute deferred flush and the deployment-window write storm (NR1 above), this creates a compounded availability risk during deployments.**
The state-service spike Notable Patterns §3 identifies this explicitly: "All operations for all screen IDs share a single `synchronized(locks)` monitor." The combination of three simultaneous stressors — Salesforce notification triggers on every screen persist (NR1), deployment flag forcing synchronous writes for 5 minutes, and a single-monitor lock on all screen IDs — creates a deployment-time serialization bottleneck that could cause significant latency or timeouts for screen operations platform-wide during every rolling deployment.

---

### Outstanding Gaps

The following gaps remain unresolved after this phase and should be the focus of subsequent spikes or client clarification:

1. **`fmcom-player-api` specific `/internal/**` endpoints called on `fmcom-api`** (C1 unresolved): A `fmcom-player-api` spike is still needed to enumerate the exact HTTP calls made to `fmcom-api` via `SERVICE_DISCOVER_API`.

2. **`API_CONTENT_ADD` dual-publisher idempotency** (C3 partially resolved): The `ContentMessageHandlers` implementation in `fmcom-api` must be examined to determine whether it performs an upsert or an insert. If it is not idempotent, the dual-publisher pattern is a live data corruption risk.

3. **`JmsMode` routing rules** (fm-common NC, NR2): Which messages in each service route through Amazon MQ and which route through state-service's in-process broker? This is critical for understanding delivery guarantees platform-wide.

4. **`ScreenStateClient` import by `rnf`** (NC5): Does rnf import `ScreenStateClient` and call it for screen data, or does it use MySQL directly via `MySqlScreenModule`? This determines whether rnf's dependency on state-service extends beyond the `InstanceStateClient` ping.

5. **Wire-format compatibility between `fm-common` 8.7.8 (state-service) and 8.9.x (rnf, fmcom-api)**: JMS payload DTO serialization compatibility across the version gap must be verified, particularly for ES-limit coordination messages that state-service exchanges with rnf and fmcom-api.

6. **Authority boundary for screen writes**: No documented policy governs which services can write directly to the MySQL `screen` table without going through state-service. The `fmcom-api` `MySqlScreenModule` import and direct JPA write access remain the primary ambiguity. A policy decision, not just a code audit, is required.

7. **`youtube-downloader` service**: Still unanalyzed. The rnf spike surfaces an additional complexity — rnf has a `YoutubeContentDownloadReenqueueJob` that interacts with the same YouTube download pipeline that `fmcom-api` manages. The relationship between these two re-enqueue mechanisms is undocumented.

8. **ES throttle quota release under exception**: The rnf spike Open Question 9 asks whether `requestQuotaIncreaseForHeavyJob()` leaves the quota elevated if an exception is thrown before the `finally` block. This is a silent resource-exhaustion risk affecting all services sharing the ES cluster.

9. **`CriticalIssueService` production implementation**: The fm-common spike confirms the default implementation only logs. If no production implementation sends alerts (Slack, PagerDuty), critical conditions like `ES_CLUSTER_NO_SPACE` are invisible to operators. This must be confirmed.

10. **`prod-perf` rnf environment isolation**: Whether `reach-n-freq-perf` shares the same Amazon MQ broker as `reach-n-freq` in production (same broker endpoint visible in both task definitions per the rnf spike) is unconfirmed. If it does, `TriggerMode.REST_BULK` jobs run in `prod-perf` will compete for JMS queue capacity and potentially interfere with live transcoding in `reach-n-freq`.

