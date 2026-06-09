---
title: "Tech Spike — Player-specific backend (Vrtly Player API)"
last_updated: 2026-06-09
---

# Tech Spike: Player-specific backend (Vrtly Player API)

## What This Service Does

The Vrtly Player API (`fmcom-player-api`) is the dedicated backend that all display devices (Fire Stick, Roku, Android TV, webOS, HTML5/Cordova players) communicate with at runtime. It handles the full device lifecycle: initial registration and pairing, session authentication, playlist/content delivery, real-time WebSocket channel management, playback telemetry ingestion, and server-side adaptive bitrate (ABR) quality mitigation. Every content URL served to a player passes through this service — it signs CloudFront URLs, applies quality caps, and rewrites HLS manifest URLs on the fly based on device capability and observed playback failures.

At the core of its intelligence is a multi-layered ABR mitigation stack: a network-quality cap rule that writes per-screen Redis entries when ABR bitrate events show degradation, and a per-(screen, content) playback escalation state machine (`HLS_FULL → HLS_720 → SRC_ORIGINAL → SRC_720 → SRC_540 → QUARANTINE`) that automatically downgrades a content's serving variant when decode failures accumulate beyond a configurable threshold. This architecture allows the service to autonomously remediate playback problems on devices without requiring operator intervention, while publishing `MITIGATION` telemetry events to Elasticsearch so the diagnostics dashboard shows the full set/clear lifecycle.

## Tech Stack & Key Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| Spring Boot | 3.2.2 | Web framework, IoC container, graceful shutdown |
| Java | 17 | Runtime (JDK 17 features used throughout) |
| Spring Cloud OpenFeign | 2023.0.0 | HTTP client to reach `rnf` (reach-n-freq) service for playlist |
| Spring Data JPA + Hibernate | (Boot-managed) | MySQL ORM; schema managed by Liquibase |
| MySQL Connector/J | 9.6.0 | JDBC driver; HikariCP connection pool |
| Liquibase | 4.26.0 | Schema migration management |
| Spring Data Redis (Lettuce) | (Boot-managed) | Session cache, quality caps, escalation state, WS dedup |
| Apache Commons Pool2 | (Boot-managed) | Lettuce connection pool |
| Bucket4j | 8.10.1 | In-memory/Redis-backed rate limiting for HTTP and WS handshake |
| Spring WebSocket | (Boot-managed) | Real-time device channel (`/ws` endpoint) |
| Spring Data Elasticsearch | (Boot-managed) | Telemetry event storage |
| Spring ActiveMQ (JMS) | (Boot-managed) | Messaging bus; subscribe to `PLAYER_*` topics from `fm-common` |
| XxlJob | 2.4.0 | Distributed job scheduler for telemetry cleanup and screen activity jobs |
| AWS SDK v2 S3 | 2.24.11 | S3 file operations |
| AWS SDK v1 CloudFront | 1.12.671 | Signed CloudFront URL generation |
| Bouncycastle | 1.46 | RSA/PEM key handling for CloudFront signing |
| fm-common | 8.8.9 | Vrtly internal shared library — domain models, JMS destinations, Redis key constants, common services, state-client, lock-service, quarantine-service, telemetry-service (see gap note below) |
| MapStruct | 1.5.5.Final | Bean mapping (DTO ↔ entity) |
| Lombok | (Boot-managed) | Boilerplate reduction |
| springdoc-openapi | 2.2.0 | Swagger UI |
| commons-validator | 1.8.0 | Input validation utilities |
| Testcontainers | (Boot-managed) | Integration test containers |

## Main Modules / Packages

| Package / Folder | Purpose |
|---|---|
| `web/` | REST controllers — player lifecycle, playlists, config, telemetry, content, consult, info-pack, registration, screen-plan, custom, QR, resource, legacy |
| `web/ws/` | WebSocket handler (`BaseWebSocketHandler`) — delegates all lifecycle events to `WebSocketMgmtService` |
| `interceptor/` | HTTP interceptor chain: `RateLimitInterceptor` → `SecurityInterceptor` (SHA-1 signature + timestamp) → `SessionInterceptor` (session lookup + quality cap resolution) → `ScreenInterceptor` → `MitigationFetchInterceptor` (records lastFetchAt for mitigation cooldown) |
| `interceptor/ws/` | WebSocket handshake interceptor chain: `WsSessionCapInterceptor` → `WsRateLimitInterceptor` → `WsSecurityInterceptor` → `WsSessionInterceptor` → `WsScreenInterceptor` |
| `service/` | Core business services — session, player heartbeat/registration, playlist, config, screen, content, file, reporting, response logging |
| `service/impl/` | Service implementations; includes `PlaylistCurrentServiceLocal` (local playlist assembly) and `ContentStreamServiceImpl` (dynamic HLS master playlist generation) |
| `service/telemetry/` | Telemetry analysis engine: `TelemetryEventAnalyzerServiceImpl` dispatches incoming telemetry to registered `TelemetryDetectionRule` implementations asynchronously |
| `service/telemetry/rule/` | Detection rules: `PlaybackQualityCapRule` (network ABR degradation → Redis cap), `ContentPlaybackEscalationRule` (decode failure → escalation ladder), `AbrErrorBurstDetectionRule`, `ContentManifestIncompatibleDetectionRule`, `ContentSkipNextClusterDetectionRule`, `DeviceInfoSyncRule`, `ExcessiveSkipNextDetectionRule`, `PlaybackQualityCapRule`, `ScreenResolutionFloor`, `SuccessfulPlaybackTelemetryRule` |
| `service/telemetry/escalation/` | Per-(screen, content) escalation state machine: `PlaybackEscalationServiceImpl`, `PlaybackEscalationStage` enum, `FailedVariantClassifier` |
| `service/quarantine/` | `QuarantineRestoreServiceImpl` — clears all player-api Redis artifacts and triggers DB delete + downstream playlist regen on re-transcode events |
| `messaging/` | JMS consumers (`MessageHandlers`) subscribing to `PLAYER_*` ActiveMQ topics; `ScreenNotificationService` / `ScreenHistoryLoadService` |
| `feign/` | `RnfFeignClient` — calls the `rnf` (reach-n-freq) service for the current playlist |
| `config/` | Spring configuration beans: Redis, WebSocket, WebMvc (CORS + interceptor wiring), XxlJob, async thread pools, Feign, cache, scheduling |
| `config/props/` | Typed `@ConfigurationProperties` for async pools, security interceptor timeouts, session TTL, player escalation, file directories, xxl-job |
| `aspect/` | AOP aspects: `EncryptionAspect` (response body encryption), `RequestTimeLogger`, `ResponseLoggingAspect` |
| `job/` | XxlJob handlers: `TelemetryCleanupJob`, `ParseFailedReportLogsTask` |
| `utils/` | Utility classes: `ContentUtils` (URL rewriting + quality cap + escalation stage integration), `PlaybackQualityContext` / `QualityCapLogContext` (ThreadLocal cap state), `SessionHolder` / `WsSessionHolder` (in-memory concurrent maps), `SecurityUtils`, `BrickModeUtils`, `EndOfLifeUtils`, `OrganizationSessionHolder` |
| `enums/` | `WebSocketMessageType`, `WebSocketScreenEvent`, `PlaylistType`, `RequestParameter` |
| `mapper/` | MapStruct mappers for Brand, Consult, Organization, PlayedContentReport, PlaylistContent |
| `model/dto/` | Request/response DTOs including WebSocket message envelopes, consult, telemetry, played-content records |
| `repository/mysql/` | Extended JPA repositories for consult, info-pack, organization users, screen brands |
| `legacy/` | Legacy `RoomService` for backward-compatible room/session endpoints |

## External Integrations

| Integration | Type | Details |
|---|---|---|
| **rnf (reach-n-freq) service** | HTTP (Feign) | `RnfFeignClient` calls `${SERVICE_DISCOVER_RNF}/playlist/current/{screenId}` — resolves the active playlist for a screen. In prod: `https://rnf.prod.vrtly.app`. **Not present in repos/ directory — gap.** |
| **api service** | HTTP (config) | `${SERVICE_DISCOVER_API}` referenced for inter-service coordination. In prod: `https://api.prod.vrtly.app`. **Not present in repos/ directory — gap.** |
| **state service** | Library client | `ScreenStateClient` from `fm-common` calls `${SERVICE_DISCOVER_STATE}`. In prod: `https://state.prod.vrtly.app`. **Not present in repos/ directory — gap.** |
| **AWS ActiveMQ (Amazon MQ)** | JMS (SSL) | Subscribes to 9 `PLAYER_*` topics (screen updated, content updated/pending, quality cap notify, org updated, history load, content transcoded batch). Default broker: `ssl://b-451110d0-...mq.us-west-2.amazonaws.com:61617`. Also publishes `API_CONTENT_QUARANTINE` on restore. |
| **Redis (ElastiCache)** | Lettuce / Redis | Session cache, per-screen quality cap state (30 min TTL), per-(screen, content) escalation state (no TTL), WS session dedup, `lastFetchAt` mitigation anchor (7d TTL), global max quality cap key, quarantine rule ZSETs. Database index: `4` (dev), `2` (prod). |
| **MySQL (RDS)** | HikariCP / JPA | Primary operational store: screens, organizations, content, playlists, brands, quarantine, consult tracks, info-pack, reports, users, locations. Schema managed by Liquibase. Pool size: 150 connections in prod. |
| **Elasticsearch** | Spring Data ES | Telemetry ingestion sink. `TelemetryService` (from `fm-common`) writes `TelemetryDto` records; `MITIGATION` telemetry events also written here for diagnostics dashboard. Throttling is configurable (initial limit 3 in prod). |
| **AWS S3** | AWS SDK v2 | Read access for content assets; fallback read bucket configurable. Primary: `friendmedia-cms` (prod). |
| **AWS CloudFront** | AWS SDK v1 | Signed URL generation for every content URL served to devices. Keys stored in `private_key.pem` / `prod_private_key.pem`. Domain: `d1cgzt8pcd208o.cloudfront.net` (prod). |
| **XxlJob admin** | HTTP | Distributed job scheduling. Admin: `https://jobs.prod.vrtly.app/job-admin/`. Executor port `9997`. |
| **AWS SSM Parameter Store** | ECS secrets injection | All sensitive env vars (DB credentials, Redis auth, Elasticsearch creds, MQ credentials, crypto keys) are injected at container start via SSM ARNs in the ECS task definition. |
| **fm-common library** | Internal JAR | Pulled from AWS CodeArtifact (`vrtly-515289352310.d.codeartifact.us-west-2.amazonaws.com/maven/fm-common/`). Version 8.8.9. Contains domain models, JMS `Destinations` constants, `ScreenStateClient`, `ContentQuarantineService`, `TelemetryService`, `LockService`, `PlaylistCurrentService`, `AwsService`, `MessagingService`, and many shared repositories. **Source not in repos/ directory — gap.** |

## Key Data Entities / Domain Models

| Entity / DTO | Origin | Description |
|---|---|---|
| `ScreenDto` | `fm-common` | Core screen record: id, mac, organizationId, enabled, subscription, hardwareType, resolution, deviceType, platform, osVersion, manufacturer, secret |
| `SessionDto` | `playerapi` | Runtime session: mac, `ScreenDto`, requestIp, lastUpdate, timestamp, WeakReference to `WebSocketSession` |
| `PlaylistCurrentDto` | `fm-common` | The time-ordered playlist delivered to a player: screen/org IDs, date, sorted set of `PlaylistEntryDto` |
| `PlaylistEntryDto` | `fm-common` | Single slot in the playlist: datetime, duration, `ContentDto`, ownership type |
| `ContentDto` | `fm-common` | Content record: id, contentType, src (S3 URL), streamSrc (HLS master URL), cover, subtitleUrl, detailsCurrent (MP4 ladder JSON), detailsStream (HLS ladder JSON) |
| `TelemetryDto` | `fm-common` | Telemetry event from a device: type, mac, screenId, hardwareType, timestamp, payload (free-form `Map<String,Object>`) |
| `PlaybackEscalationState` | `playerapi` | Redis-stored record: `PlaybackEscalationStage` (enum), enteredAt, lastAdvanceAt, freshFails counter |
| `PlaybackEscalationStage` | `playerapi` | Enum: `HLS_FULL → HLS_720 → SRC_ORIGINAL → SRC_720 → SRC_540 → QUARANTINE` — each stage declares the variant key it serves |
| `PlaybackQualityCap` | `playerapi` | Value record: `MediaResolution` tier + `roku` boolean flag |
| `ScreenRegistrationDto` | `playerapi` | Registration response: pairing code (new device) or secret + config (known device) |
| `ConsultVersionSimplifiedDto` | `playerapi` | Consult version with content list, tracks, info-pack ids; URLs rewritten per escalation stage |
| `InfoPackSimplifiedDto` | `playerapi` | Info-pack summary with brand cover/logo URLs |
| `WebSocketMessageDto` | `playerapi` | WS envelope: type (`WebSocketMessageType`), payload (Object), ack token |
| `MySqlContentQuarantine` | `fm-common` | Quarantine row: contentId, screenId (nullable for ALL type), type (SCREEN/ALL), reason |
| `PlaylistCurrentDto` | `fm-common` | Complete current playlist including `PlaylistEntryDto` set with content, schedule, and type |

## Notable Patterns, Risks & Observations

**1. In-memory session store (`SessionHolder`, `WsSessionHolder`) is node-local.**
Sessions and WS connections are held in `ConcurrentHashMap` instances on each JVM. There is no distributed session replication. Under ECS with multiple task replicas, a device's HTTP request may land on a different node than its WebSocket connection. The WS cap-check and `send()` fallback path uses a `UnsentNoticeService` but cross-node sends are silently dropped to the `unsentNotice` bucket rather than delivered live. This is a known architectural constraint; the service relies on the ActiveMQ `PLAYER_SCREEN_*` fan-out to update session state on the correct node — but that only works for the node holding the WS session.

**2. SHA-1-based request signing.**
`SecurityInterceptorServiceImpl` authenticates devices by computing `SHA-1(serialNumber + timestamp)` and comparing against the `signature` query parameter. SHA-1 is cryptographically weak; if a device's serial number is known (it's often a MAC address) an attacker can forge signatures. The timestamp-based expiry window (default 300s) limits replay exposure, but the scheme has no per-session secret unless `player.config.enable-encryption` is true. A bypass (`?hello`) is allowed on non-production environments via `skipValidation`.

**3. Credentials and keys committed to source.**
`src/main/resources/private_key.pem` and `prod_private_key.pem` are checked into the repository. These are the RSA private keys for CloudFront URL signing. Even if rotated, the git history retains them. Additionally, `application.yml` hard-codes default AWS access key/secret, broker credentials, and encryption keys as fallback values. This is a critical security gap.

**4. Telemetry pipeline is best-effort / fire-and-forget.**
`TelemetryController` catches all exceptions and logs a warning; `TelemetryEventAnalyzerService.analyzeAsync` runs on a dedicated thread pool and swallows failures. This is intentional to avoid back-pressure from Elasticsearch propagating to the player. However, it means telemetry loss is silent and there is no dead-letter queue or retry mechanism for analysis failures.

**5. Playback escalation ladder is sophisticated but carries operational complexity.**
The `PlaybackEscalationStage` ladder is a 6-stage monotonic state machine stored permanently in Redis (no TTL). State is only reset on re-transcode events or device firmware changes. The `settle-grace-minutes` (default 30) window is designed to absorb stale pre-refetch failures but creates a 30-minute blind period after each advance during which real failures on the new variant are not counted. The `active` vs `enabled` dual flags allow shadow mode, but the application.yml comments acknowledge that old-rule standown is tied to `escalation.active=true`, meaning there is a transitional period where both the old and new rules coexist.

**6. Dynamic HLS master playlist endpoint has no authentication.**
`/player/content/stream/{store}/{id}/{res}/{filename}.m3u8` is explicitly excluded from `SecurityInterceptor` and `SessionInterceptor` because the URL is handed to the player as a pre-authenticated resource. This means anyone who discovers the URL pattern can enumerate and fetch filtered playlists without credentials. The 24-hour `Cache-Control` header further extends exposure window. CloudFront signed URL protection is absent on this path.

**7. `fm-common` version pinning is a hidden coupling risk.**
The shared library at version `8.8.9` owns domain models, JMS destinations, Redis key constants, and several critical service interfaces (`TelemetryService`, `ContentQuarantineService`, `ScreenStateClient`). Any breaking change in `fm-common` requires coordinated deployment across all services. The source of `fm-common` is not in the `repos/` directory, so changes to shared contracts are invisible in this codebase view.

**8. Async thread pool proliferation.**
Four separate `ThreadPoolTaskExecutor` instances are configured: `player-business-thread-` (40/200), `telemetry-thread-` (16/64), `response-log-thread-` (4/16), `ws-send-thread-` (32/256). The XxlJob executor adds another thread on port 9997. At peak, this service can have ~600 threads plus Tomcat's own 400-thread pool, totalling ~1,000+ threads in a 7.8 GB container (2 vCPU). Under GC pressure this is a risk.

**9. Legacy endpoints coexist with modern ones.**
`LegacyPlayerController` handles `/v5/playerApi/**` paths. `PlayerController.getConfig()` is marked `@Deprecated(forRemoval = true)`. `PlayerController.registerDevice()` is also deprecated. The versioned response branching in `PlayerController.checkVersion()` (version codes 540/550) adds conditional logic that is difficult to test exhaustively and will accumulate technical debt as old client versions age out.

**10. Roku MAC migration service.**
`RokuMacMigrationService` and `RokuCertOverrideService` implement special-case logic for Roku device MAC address format migration and certification-build demo accounts. These are cross-cutting concerns woven into `SessionServiceImpl`, `RegistrationServiceImpl`, and `PlayerController`. Their interaction with normal registration flow and session lookup is difficult to reason about without the Roku-specific MAC format documentation.

**11. `@Lazy` used to break circular dependencies at construction time.**
`PlaybackEscalationServiceImpl` uses `@Lazy` on `ScreenNotificationService` to break a construction cycle: `ContentUtils → PlaybackEscalationService → ScreenNotificationService → WebSocketMessagingService → ConsultService → ContentUtils`. Using `@Lazy` is a valid workaround but signals an architectural cycle that warrants untangling.

**12. Redis Lua scripts for custom content operations.**
Three Lua scripts (`save_custom_content_of_screen.lua`, `save_recently_playlist.lua`, `save_brand_content_of_screen.lua`) implement atomic multi-key operations. These are not evaluated at application startup, so script errors are runtime failures. There is no version pinning or idempotency guard on the scripts.

**13. Content URL rewriting logic is centralised but very broad.**
`ContentUtils.updateContentUrls()` is called for every content item in every playlist, consult, and custom playlist response. It reads from `PlaybackQualityContext` (a `ThreadLocal`) and calls Redis for escalation state on every content ID. On a large playlist with 30-60 items this is 30-60 synchronous Redis reads per request, compounding latency under Redis pressure.

## Open Questions

1. **Session replication strategy**: Is horizontal scaling of player-api expected to be sticky (ALB session affinity) or stateless? The current in-memory `SessionHolder` design is not horizontally safe without session affinity. What is the actual ECS service scaling policy and whether sticky sessions are configured on the load balancer?

2. **fm-common version governance**: Who owns `fm-common` releases? What is the process for coordinating breaking-change deployments across player-api, api, rnf, and state services simultaneously? Is there a shared changelog or compatibility matrix?

3. **Escalation ladder rollout state**: `player.escalation.active` defaults to `false` in `application.yml` but is `true` in the prod task definition. Is the shadow-mode vs. active-mode distinction still in active use, or is it safe to remove the dual-flag complexity?

4. **CloudFront streaming endpoint authorization**: Is the unauthenticated `/player/content/stream/` endpoint intended to be publicly accessible? Should CloudFront signed URLs be applied here, or is security handled via obscurity of the URL pattern?

5. **Private keys in repository**: `private_key.pem` and `prod_private_key.pem` are committed. Have these been rotated since being committed? What is the remediation plan for the git history exposure?

6. **`fm-common` Redis key namespacing**: The key constants (`TelemetryRedisKeys`, `PLAYBACK_ESCALATION_PREFIX`, etc.) are defined in `fm-common`. Are these keys shared between multiple services on the same Redis instance (database index 4/2)? If so, a key collision between player-api and another service is possible.

7. **Legacy endpoint removal timeline**: `PlayerController.registerDevice()` and `getConfig()` are marked for removal. What version of the player app can still be hitting these endpoints? Is there telemetry to measure their remaining traffic before removal?

8. **Consult feature scope**: `ConsultController` and `ConsultService` represent a "consult" feature (brand-filtered content experience with user tracking). Is this a separate product line from the normal display playlist? What percentage of deployed screens use it?

9. **State service responsibility**: `ScreenStateClient` from `fm-common` is called for screen lookups in hot paths (session build, escalation notifications, mitigation emitter). What is the state service's SLA and how does player-api behave under state service degradation? Is there a fallback or circuit breaker?

10. **XxlJob integration**: XxlJob exposes an executor on port 9997, which is open in the ECS task definition. What jobs are scheduled, and is the XxlJob admin UI accessible from outside the VPC? The `telemetryCleanup` job is the only one visible in this codebase; are there others registered in the admin console?
