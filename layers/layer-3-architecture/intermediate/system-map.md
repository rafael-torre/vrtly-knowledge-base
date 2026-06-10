---
title: "System Map — Vrtly Platform"
last_updated: 2026-06-10
---

# System Map: Vrtly Platform

## Platform Overview

Vrtly is a digital-signage SaaS platform connecting two sides of a marketplace: healthcare practices (providers) and pharmaceutical/healthcare brands (sponsors). Providers manage waiting-room display screens; brands create advertising campaigns and educational content that play on those screens. The platform orchestrates content lifecycle from upload and transcoding through to real-time playlist delivery on physical display devices, with telemetry and analytics flowing back to both sides via a web-based management portal.

At a system level, the platform comprises four analyzed services — a management web frontend (monorepo), a central backend API, a device-facing player API, and an HTML5 player app — plus several unanalyzed integrated services (reach-and-frequency engine, state service, YouTube downloader, Cordova shell) and shared infrastructure (Amazon MQ, Redis ElastiCache, MySQL RDS, Elasticsearch, S3, CloudFront). The web frontend and HTML5 player app are static SPAs deployed to S3/CloudFront; the two backend APIs are containerized Spring Boot services running on ECS.

---

## Service Inventory

| Service | Role | Stack |
|---|---|---|
| `fmcom-vrtly-fe-monorepo` | CMS web frontend — four SPAs (vrtly-home, VPM provider portal, VAM advertiser portal, onboarding) | Vue 3, Pinia, TypeScript, Vite, Element Plus, `@vrtly/component-library`, Axios; deployed to S3/CloudFront |
| `fmcom-api` | Central backend — CMS operations, content lifecycle, billing, device management, social sync, admin | Spring Boot 3.2 / Java 17, MySQL, Redis, Elasticsearch, Amazon MQ (JMS), AWS SDK v1+v2, Stripe, `fm-common` 8.9.0 |
| `fmcom-player-api` | Device-facing backend — device registration, playlist delivery, WebSocket channel, ABR mitigation, telemetry ingestion | Spring Boot 3.2 / Java 17, MySQL, Redis, Elasticsearch, Amazon MQ (JMS), WebSocket, AWS SDK v1+v2, `fm-common` 8.8.9 |
| `html5core` | HTML5 player app — runs in WebView on FireTV, webOS, Tizen, iOS, browser; displays playlists and consults | Vue 3, Pinia, TypeScript, Vite, crypto-js; deployed to S3/CloudFront |
| `rnf` (gap) | Reach-and-frequency / playlist resolution engine | Not analyzed — referenced by `fmcom-api` and `fmcom-player-api` via Feign |
| `state` (gap) | Screen state service | Not analyzed — referenced by `fmcom-api` and `fmcom-player-api` via `fm-common` `ScreenStateClient` |
| `youtube-downloader` (gap) | YouTube video download worker | Not analyzed — receives JMS dispatch from `fmcom-api`; calls `/internal/youtube-downloads/**` to report progress |
| `fm-common` (gap) | Internal shared library (JAR) | Not analyzed — sourced from AWS CodeArtifact; provides domain models, JMS destinations, Redis key constants, `ScreenStateClient`, `TelemetryService`, `ContentQuarantineService`, and 60+ MySQL/Elasticsearch modules; pinned at 8.9.0 in `fmcom-api`, 8.8.9 in `fmcom-player-api` |
| `cordova-player` (gap) | FireTV native shell wrapping `html5core` in a WebView | Not analyzed — referenced in `html5core` README; provides device UUID, model, and version via `window._cordovaNative` |
| `roku-player` (gap) | Roku player app | Not analyzed — referenced in `fmcom-player-api` (`RokuMacMigrationService`, `RokuCertOverrideService`); communicates with `fmcom-player-api` |
| `android-player` (gap) | Android TV player app | Not analyzed — implied by `fmcom-player-api` device types |
| `@vrtly/component-library` (gap) | Design system / shared UI component library | Not analyzed — private npm package on AWS CodeArtifact (`^0.8.20`); consumed by `fmcom-vrtly-fe-monorepo` |
| `xxl-job-admin` (gap) | Distributed scheduled-job admin server | Not analyzed — `fmcom-api` registers 15+ jobs, `fmcom-player-api` registers telemetry cleanup; admin at `https://jobs.prod.vrtly.app/job-admin/` |
| `my.vrtly.app` public portal (gap) | Patient-facing info-pack landing page (QR code target) | Not analyzed — referenced by `fmcom-vrtly-fe-monorepo` as `VITE_INFOPACK_URL`; info-pack QR URLs are encrypted server-side before embedding |

---

## Interaction Diagram

See [System Overview Diagram](./system-overview-diagram.md) for the full four-view breakdown:

- **View 1 — System Context**: actors (Provider, Sponsor, Device Admin), system areas, and external integrations
- **View 2 — CMS Frontend + fmcom-api**: CMS portals, routing, fmcom-api internals, and owned infrastructure
- **View 3 — Device + fmcom-player-api**: device layer, html5core, player API, ABR escalation, and shared infra
- **View 4 — Async + Gap Services**: Amazon MQ event bus, XXL-Job scheduler, and the three gap microservices (rnf, state, youtube-downloader)

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
3. The `rnf` service (gap) picks up the message and runs transcoding via AWS Elastic Transcoder. A completion event is published to JMS (`API_CONTENT_ADD`). **Note:** who publishes `API_CONTENT_ADD` is unconfirmed — `fmcom-api` appears in both the publish and subscribe sets for this destination in the spike evidence; it may be `rnf` or a self-loop within `fmcom-api`. Requires `rnf` spike to resolve.
4. `fmcom-api` receives the completion event via its JMS `ContentMessageHandlers`, updates the `Content` entity to `COMPLETE`, and triggers Elasticsearch post-commit sync.
5. `fmcom-player-api` receives the `PLAYER_CONTENT_UPDATED` or `PLAYER_CONTENT_TRANSCODED_BATCH` JMS event, invalidates cached playlist state for affected screens, and pushes a `CONTENT_CHANGED` WebSocket message to connected devices.

### 3. Playlist delivery to a device

1. `html5core` opens a persistent WebSocket connection to `wss://player.vrtly.ai/ws` (`fmcom-player-api`).
2. On connection or `CONTENT_CHANGED` push, `html5core` calls `GET /player/playlist/current` on `fmcom-player-api`.
3. `fmcom-player-api` checks Redis for a cached playlist; on a miss it calls `rnf` via Feign (`GET /playlist/current/{screenId}`), which resolves SOV (share-of-voice) rules, ad slots, and brand sponsorships from its own data store.
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
| **MySQL RDS** (`fm_store`) | `fmcom-api` (primary domain DB, pool 10), `fmcom-player-api` (screens, sessions, consults, reports, pool 150) | Shared single database with `organization_id` as multi-tenant discriminator. Liquibase manages schema; both services run migrations independently — schema coordination risk. |
| **Redis ElastiCache** | `fmcom-api` (auth token cache, application cache, ShedLock distributed locks, feature flags), `fmcom-player-api` (session cache, per-screen quality caps, per-(screen,content) escalation state, WS dedup, quarantine ZSETs, lastFetchAt anchor) | Different logical Redis database indexes (fmcom-api: default; fmcom-player-api: DB 4 dev / DB 2 prod). Redis key constants shared via `fm-common` — collision risk if namespacing is not enforced. |
| **Amazon MQ (ActiveMQ)** | `fmcom-api` (publishes: `RNF_MEDIA_PROCESSING`, `YOUTUBE_DOWNLOAD`, `API_CONTENT_ADD`, `API_CONSULT_EMAIL_SEND`; subscribes: `API_CONTENT_ADD`, `API_CONTENT_QUARANTINE`, `YOUTUBE_UPDATE_URL`, `API_CONSULT_EMAIL_SEND`), `fmcom-player-api` (subscribes: 9 `PLAYER_*` topics; publishes: `API_CONTENT_QUARANTINE`) | SSL broker at `mq.us-west-2.amazonaws.com:61617`. JMS destination constants defined in `fm-common`. The `rnf` and `youtube-downloader` services are also on this bus (gap — exact topics not confirmed). |
| **Elasticsearch** | `fmcom-api` (25+ index modules via `fm-common`: analytics, ad campaign slots, played content, screen state logs, social content, impressions, orders), `fmcom-player-api` (telemetry events, mitigation events) | Both services share the same Elasticsearch cluster. Write throttling configured via `fm-common` `ThrottlingServiceModule` (`service-id: api`, `service-id: player`). |
| **AWS S3** | `fmcom-api` (media upload, CloudFront signed URLs for CMS delivery, `friendmedia-cms` bucket), `fmcom-player-api` (content asset reads, fallback read bucket, `friendmedia-cms`), `html5core` (subtitle reads from `friendmedia-cms`), `fmcom-vrtly-fe-monorepo` (SPA bundle hosting), `html5core` (app bundle at `html5core` / `html5core-beta` buckets) | Multiple S3 buckets serve different purposes. The CMS media bucket (`friendmedia-cms`) is read by both backend services and directly by `html5core` for subtitles in production. |
| **AWS CloudFront** | `fmcom-api` (signed URL generation via CloudFront private key for CMS content delivery), `fmcom-player-api` (signed URL generation for every playlist content URL delivered to devices; domain `d1cgzt8pcd208o.cloudfront.net`), `fmcom-vrtly-fe-monorepo` (CDN for SPA bundles), `html5core` (CDN for player app bundle) | Both backend services independently sign CloudFront URLs using RSA private keys. `fmcom-player-api` has `private_key.pem` committed to source — critical security gap. |
| **AWS EFS** | `fmcom-api` (mounted at `/mnt/efs` for shared media file storage between container instances) | Not referenced in `fmcom-player-api` — EFS appears to be used only for the media processing pipeline side. |
| **AWS Elastic Transcoder** | `fmcom-api` (dispatches transcoding jobs) | Indirect dependency for `fmcom-player-api` — transcoded content variants (HLS ladder, MP4 ladder) are what the escalation state machine steps through. |
| **AWS Transcribe** | `fmcom-api` (`TranscribeService`, `TranscribeJobTaskExecutor`) | Speech-to-text for subtitle generation. Long-running job polled by `TranscribeJobTaskExecutor`; result stored alongside the transcoded media. Used for subtitle delivery to `html5core` in production. |
| **XXL-Job Admin** | `fmcom-api` (executor port 9999; 15+ jobs: Stripe sync, social sync, ad slot generation, sponsor notifications, transcription repair), `fmcom-player-api` (executor port 9997; telemetry cleanup, failed report log parsing) | Shared XXL-Job admin server at `https://jobs.prod.vrtly.app/job-admin/`. Single point of failure for all scheduled tasks across both services. |
| **AWS CodeArtifact** | `fmcom-api` and `fmcom-player-api` (runtime dependency: `fm-common` JAR), `fmcom-vrtly-fe-monorepo` (npm dependency: `@vrtly/component-library`) | Domain `vrtly`, account `515289352310`, region `us-west-2`. Both build-time and deployment-time credential dependency. |
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

### fmcom-api / fmcom-player-api → rnf (playlist boundary)

- Both `fmcom-api` and `fmcom-player-api` hold separate `RnfFeignClient` instances calling `GET /playlist/current/{screenId}` on `rnf`.
- `fmcom-api` also sends media processing jobs to `rnf` via JMS (`RNF_MEDIA_PROCESSING` destination).
- `rnf` is the authoritative playlist resolver; neither backend constructs playlists independently (except `PlaylistCurrentServiceLocal` in player-api as a local fallback, details unclear).
- `rnf` is a critical dependency for both services — its SLA directly affects playlist delivery latency and availability.

### fm-common as shared contract layer

- `fm-common` (JAR) defines JMS destination name constants, Redis key prefixes, domain model types (`ScreenDto`, `ContentDto`, `PlaylistCurrentDto`, `TelemetryDto`), and service interfaces used by all microservices.
- `fmcom-api` pins `fm-common` at `8.9.0`; `fmcom-player-api` pins at `8.8.9` — a version skew exists. A breaking change in `fm-common` requires coordinated deployment across all consumers. No compatibility matrix is documented.
- Because `fm-common` source is not in the analyzed repos, changes to shared contracts are invisible in this view.

### Amazon MQ as integration bus

- JMS destination names are constants in `fm-common`. Services subscribe and publish by string name — no schema registry or contract enforcement at the broker level.
- `fmcom-api` and `fmcom-player-api` share topics: `API_CONTENT_QUARANTINE` is published by `fmcom-player-api` and consumed by `fmcom-api` for quarantine processing.
- Feature flags (`@ConditionalOnProperty`) gate multiple JMS consumers in `fmcom-api` — in dev/QA some consumers are disabled, meaning messages may accumulate or be dropped silently.

---

## Ecosystem Gaps

The following services and packages are referenced within the four analyzed repos but were not present in the codebase audit. Each is a gap for follow-up architecture documentation.

| Gap | Referenced by | Evidence | Follow-up needed |
|---|---|---|---|
| **`rnf` (Reach-and-Frequency / playlist resolver)** | `fmcom-api` (`RnfFeignClient`, JMS `RNF_MEDIA_PROCESSING`), `fmcom-player-api` (`RnfFeignClient`), `fmcom-vrtly-fe-monorepo` (`VITE_REACH_AND_FREQUENCY_URL` — dev env only; no active usage found in VAM source) | Prod URL: `https://rnf.prod.vrtly.app`; both backend services call it for playlist resolution | Spike needed: tech stack, playlist resolution algorithm, SOV rule engine, data ownership, SLA |
| **`state` service** | `fmcom-api` (`ScreenStateClient`, `InstanceStateClient` from `fm-common`), `fmcom-player-api` (`ScreenStateClient`) | Prod URL: `https://state.prod.vrtly.app`; called in hot paths for screen lookups | Spike needed: screen state ownership vs MySQL (`MySqlScreenModule`), authority boundary with `fmcom-api`, degradation behavior |
| **`youtube-downloader` service** | `fmcom-api` (JMS `YOUTUBE_DOWNLOAD`, internal HTTP `/internal/youtube-downloads/**`) | Bidirectional: `fmcom-api` dispatches jobs; downloader calls `/complete` or `/fail` back | Spike needed: download concurrency model, heartbeat protocol, failure/retry behavior |
| **`fm-common` (internal library, version 8.9.0 / 8.8.9)** | `fmcom-api`, `fmcom-player-api` | AWS CodeArtifact: `vrtly-515289352310.d.codeartifact.us-west-2.amazonaws.com/maven/fm-common/` | Source spike needed: domain model definitions, JMS destination constants, Redis key namespacing, version governance process |
| **`cordova-player` (FireTV shell)** | `html5core` (README, `window._cordovaNative` bridge) | Provides device UUID, model, platform, shell version to `html5core` | Spike needed: update delivery model (does shell always load from S3 or can it bundle locally?), versioning contract with `html5core` |
| **Roku player app** | `fmcom-player-api` (`RokuMacMigrationService`, `RokuCertOverrideService`, MAC format migration) | Special-case MAC address handling and certification demo account logic woven into session and registration | Spike needed: Roku device protocol, MAC format, auth scheme, firmware version compatibility |
| **Android TV player app** | `fmcom-player-api` (device types in `ScreenDto`, platform enum values) | Implied by multi-platform device type support | Spike needed: tech stack, protocol compatibility with `fmcom-player-api` |
| **`@vrtly/component-library` (design system)** | `fmcom-vrtly-fe-monorepo` (`^0.8.20` from CodeArtifact npm) | Pinned in root `package.json`; global SCSS imported | Spike needed: component inventory, versioning cadence, breaking-change coordination with monorepo, ownership |
| **`my.vrtly.app` public portal (info-pack consumer)** | `fmcom-vrtly-fe-monorepo` (`VITE_INFOPACK_URL`), `html5core` (`qrCodeBuilder.ts`) | Referenced as QR code landing page; URLs encrypted server-side before embedding | Spike needed: tech stack, content rendering, encrypted payload format, patient session model |
| **XXL-Job admin server** | `fmcom-api` (executor port 9999, 15+ job handlers), `fmcom-player-api` (executor port 9997, telemetry cleanup) | Admin URL: `https://jobs.prod.vrtly.app/job-admin/` | Operational gap: job inventory, scheduling config, failure alerting, single-point-of-failure risk assessment |
| **GCP Firebase / Pub/Sub pipeline** | `fmcom-api` (`GcpPubSubWebhookController`, `ExternalEventConverter` plugin chain) | Inbound webhook at `/webhook/gcp/pubsub`; only `CrashlyticsConverter` visible | Gap: additional converter implementations (Firebase Analytics, other GCP log sources), event schema, volume |
| **Elasticsearch throttling service** | `fmcom-api`, `fmcom-player-api` (`fm-common` `ThrottlingServiceModule`) | Config refs `elasticsearch.throttle.*`; `service-id: api`, `initial-limit: 1/3` | Gap: throttle behavior under saturation, circuit breaker semantics, shared vs per-service limits |

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

