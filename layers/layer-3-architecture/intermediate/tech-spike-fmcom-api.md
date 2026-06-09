---
title: "Tech Spike — Main platform backend (FriendMedia API)"
last_updated: 2026-06-09
---

# Tech Spike: Main platform backend (FriendMedia API)

## What This Service Does

The FriendMedia API (`fmcom-api`) is the central backend platform that powers all CMS operations, device management, content lifecycle, and monetization for the Vrtly digital-signage platform. It provides REST endpoints consumed by the CMS web application (provider/brand-facing), an internal admin panel, and downstream services. The service handles multi-tenant provider and brand organizations, manages media screens (TVs in waiting rooms), controls the content library lifecycle from upload through transcoding, serves the advertising campaign and subscription billing systems, and acts as the coordination hub for a fleet of downstream services including a reach-and-frequency engine (RNF), a YouTube downloader, a state service, and a player.

It is not a pure API gateway — it owns a large share of the domain database, drives the media processing pipeline, handles all payment webhooks, and runs background job coordination. Concretely, it manages Organizations (healthcare providers / brands), their Screens, their Content libraries, Playlists, Ad Campaigns, Consult flows, InfoPack patient education materials, Stripe subscriptions, Shippo shipping orders, and social network content sync.

## Tech Stack & Key Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| Spring Boot | 3.2.0 | Core web framework (Jakarta EE namespace) |
| Java | 17 | Runtime |
| Spring Data JPA + Hibernate | Boot-managed | ORM for MySQL; single-table inheritance for Content |
| MySQL (connector 9.6.0) | — | Primary relational datastore |
| Liquibase 4.26.0 | — | Schema migration management |
| Spring Data Redis + Redisson 3.26.0 | — | Session-less token auth cache, distributed locks, application caching |
| ShedLock 5.16.0 (Redis provider) | — | Distributed lock around `@Scheduled` methods to prevent duplicate execution across N instances |
| Spring Cloud OpenFeign | 2023.0.0 | Typed HTTP clients for RNF service (`RnfFeignClient`), State service (`ScreenStateClient`, `InstanceStateClient`), Meta Graph API (`FacebookFeignClient`, `InstagramGraphFeignClient`, `InstagramAuthFeignClient`) |
| Spring Security | Boot-managed | Session-stateless token auth; custom `TokenBasedAuthenticationFilter`; internal API key header filter |
| Spring ActiveMQ (Amazon MQ) | Boot-managed | JMS broker for inter-service messaging (content events, YouTube download dispatch, consult notifications) |
| Spring WebFlux | Boot-managed | Reactive HTTP client used internally (alongside Feign) |
| AWS SDK v1 (1.12.649) | — | S3 uploads, CloudFront URL signing, Elastic Transcoder pipeline |
| AWS SDK v2 (2.17.295) | — | S3 v2 client, Amazon Transcribe (speech-to-text for subtitles) |
| Stripe SDK 28.2.0 | — | Billing, subscription management, webhook processing |
| Shippo SDK v2.1.6 | — | Hardware shipping label generation |
| Google YouTube Data API v3 | v3-rev221-1.25.0 | YouTube content metadata lookup |
| Google Maps Services 2.1.2 | — | Address geocoding and place validation |
| Google API Client 1.33.0 | — | OAuth flow for YouTube/Google |
| Twilio 11.3.0 | — | SMS OTP delivery |
| GCP Pub/Sub webhook | — | Inbound push from Firebase/GCP for device telemetry events |
| XXL-Job 2.4.0 | — | Distributed scheduled job executor (admin at `/job-admin`) |
| Elasticsearch | Boot-managed (spring-data-elasticsearch) | Analytics index for played content, screen state logs, ad campaign records, impression reports, order data, social network content — accessed via ~25 `fm-common` Elastic modules |
| MapStruct 1.5.5 | — | Compile-time DTO/entity mapping |
| Lombok | — | Boilerplate reduction |
| PDFBox 2.0.4, FFmpeg 0.8.0, JAI ImageIO | — | Server-side media processing (PDF thumbnails, video probing) |
| Fastjson 1.2.83 (Alibaba) | — | Legacy JSON serialization in domain objects; coexists with Jackson |
| Thymeleaf 3.1.2 | — | Email templates; admin diagnostics HTML page |
| SpringDoc OpenAPI 2.3.0 | — | Swagger UI at `/swagger-ui` |
| `fm-common` (internal artifact 8.9.0) | — | Shared library from AWS CodeArtifact (`vrtly-515289352310`); contains all Elasticsearch/MySQL repository modules, JMS destination constants, common DTOs, auth modules, state client, SOV rule engine, telemetry, transcoding enums |
| BouncyCastle 1.46 | — | Crypto utilities; encryption key / HMAC configuration present in app config |
| Intercom webhook | — | Inbound Intercom CRM events |

## Main Modules / Packages

| Package | Purpose |
|---|---|
| `auth` | Token-based stateless auth: `TokenBasedAuthenticationFilter`, `InternalApiKeyAuthFilter`, `AuthController` (login/logout/refresh/verify), `SuperUserService` (impersonation), OTP strategy for patient auth |
| `config` | Spring configuration: security (`WebSecurityConfig`), Amazon clients (`AmazonConfig`), Feign clients (`FeignConfig`), Redis (`RedisConfig`, `RedissonConfig`), XXL-Job (`XxlJobConfig`), async executor (`AsyncConfig`), ShedLock (`SchedulerLockConfig`), feature flags (`FeatureFlagProperties`), background task flags (`BackgroundTaskProperties`), `ImportConfig` (wires all 60+ `fm-common` modules) |
| `controller/admin` | Internal super-admin REST endpoints: organization management, screen settings, ad campaigns, brand management, diagnostics, Stripe feature flags, migration utilities, whitebox telemetry dashboard |
| `controller/cms` | Provider-facing REST API surface (the CMS): screens, content, playlists, brands, consults, InfoPacks, orders, Stripe checkout/subscription, social network auth/content, SOV rules, settings, reports |
| `controller/webhook` | Inbound webhooks: `StripeWebhookController`, `GcpPubSubWebhookController`, `MandrillWebhookController` |
| `controller/internal` | Service-to-service endpoints (`/internal/**`), protected by API key. Notably `InternalYoutubeDownloadController` (claim/heartbeat/complete/fail for download lock protocol) and `InternalLogIngestController` |
| `controller/connector` | Connector passthrough for Intercom and Shippo |
| `controller/api` | External B2B API endpoints (Salesforce, organization user management, notice) |
| `controller/subscription` | Public user subscription endpoints |
| `entity` | JPA entities grouped by domain: `auth` (User, Role), `business` (Organization, Brand, Library, Room, Playlist, WhiteLabel, Leads), `content` (Content abstract base with SINGLE_TABLE inheritance, Video, Youtube, Album, SocialNetworkPost), `ecommerce` (Order, Invoice, Subscription, Product, PromoCode), `relation` (OrganizationUser, ScreenContent, ProviderSponsor, etc.), `stat`, `stripe`, `subscription`, `consult`, `report`, `info_pack_event` |
| `service` | 100+ service classes covering all business domains; organized by sub-package: `business/`, `ecommerce/`, `relation/`, `social_network/`, `youtube/`, `media/`, `webhook/`, `report/`, `team/`, `user/`, `util/`, `state/`, `setting/` |
| `service/media` | `MediaProcessingDispatcher` — single outbound entry point for all media operations dispatched to RNF over JMS |
| `service/youtube` | `YoutubeDownloadRescueService` (ShedLock sweeper), `YoutubeDownloadLockService` (distributed claim/heartbeat/complete/fail protocol), `AdminYoutubeRetriggerService` |
| `service/webhook` | Stripe event handler chain: `StripeWebhookHandler` interface dispatched by `StripeObjectType` enum; implementations for Customer, Invoice, PaymentIntent, Price, Session, Subscription events |
| `messaging` | JMS message handlers (subscribe on `@PostConstruct`): `ContentMessageHandlers`, `ContentQuarantineHandlers`, `YoutubeUpdateUrlHandlers`, `ConsultNotificationHandlers` — each gated by feature flag (`@ConditionalOnProperty`) |
| `job` | XXL-Job handler beans registered via `@XxlJob`: ad slot generation, social sync, Stripe sync/migration/cleanup, screen definition alignment, consult storage realignment |
| `task` | `ScheduledTasks` (XXL-Job handlers for email reminders, scan reports, transcription repair, cache operations), `longpoll/` (async transcription job polling: `TranscribeJobTaskExecutor`, `TranscribeVideoTaskExecutor`, `UpdateOrgLastDisplayTimeTaskExecutor`) |
| `feign` | `RnfFeignClient` (playlist resolution), `FacebookFeignClient` (Meta Graph API), `InstagramAuthFeignClient`, `InstagramGraphFeignClient` |
| `event` | Spring application events: `BaseCudPostCommitEventListener`, Elasticsearch post-commit sync (`BrandCudEventListener`, `ContentCudEventListener`), S3 object deletion, subscription/order status updates, operate log |
| `aspect` | `RequestTimeLogger` AOP aspect for HTTP request timing |
| `mapper` | MapStruct mapper interfaces for entities to DTOs |
| `argumentResolver` | Custom Spring MVC argument resolvers: `@FMOrganization` (resolves org from auth context), `@FMApiOrganization`, `@FMApiScreen`, `@FMWhiteLabel` |
| `framework` | Domain request wrappers (`Req`), Jackson custom serializers (`CloudFrontSerializer` for signed URL generation) |
| `rest` | Response wrappers: `FMResponse<T>`, `ResponseCode` |
| `exportcsv` | CSV export utilities |
| `interceptor` | HTTP interceptors |

## External Integrations

| Integration | Mechanism | Direction | Notes |
|---|---|---|---|
| **RNF service** (`rnf`) | Spring Cloud Feign (`RnfFeignClient`) + JMS (`Destinations.RNF_MEDIA_PROCESSING`) | Outbound | Playlist resolution and media processing dispatch; URL configured via `service.discover.rnf`. **GAP: `rnf` repo not present in `repos/` directory** |
| **State service** (`state`) | `fm-common` `StateClientModule` / `ScreenStateClient` / `InstanceStateClient` via Feign | Outbound | Screen state reads; URL via `service.discover.state`. **GAP: `state` repo not present in `repos/` directory** |
| **YouTube Downloader service** | JMS outbound (`Destinations.YOUTUBE_UPDATE_URL_DESTINATION`, `YoutubeDownloadMessage`) + internal HTTP inbound (`/internal/youtube-downloads/**`) | Bidirectional | YD claims lock via API, heartbeats, then calls `/complete` or `/fail`; rescue sweeper re-dispatches stuck rows. **GAP: `youtube-downloader` repo not present in `repos/` directory** |
| **Amazon MQ (ActiveMQ)** | Spring JMS (`ssl://...mq.us-west-2.amazonaws.com:61617`) | Bidirectional | 4 inbound JMS queues handled: `API_CONTENT_ADD`, `API_CONTENT_QUARANTINE`, `API_CONSULT_EMAIL_SEND`, `YOUTUBE_UPDATE_URL`; outbound: `RNF_MEDIA_PROCESSING`, `YOUTUBE_DOWNLOAD`, `API_CONTENT_ADD`, `API_CONSULT_EMAIL_SEND` |
| **AWS S3** | AWS SDK v1 (`AmazonS3`) and v2 (`software.amazon.awssdk.s3`) | Outbound | Media upload, signed URL generation, CloudFront signed cookie |
| **AWS CloudFront** | SDK v1 (`aws-java-sdk-cloudfront`) | Outbound | Signed URL/cookie generation via private key (`cloudfront-key-file`) |
| **AWS Elastic Transcoder** | SDK v1 (`aws-java-sdk-elastictranscoder`) | Outbound | Video transcoding pipeline (pipeline ID configured in env) |
| **AWS Transcribe** | SDK v2 (`transcribe`) | Outbound | Speech-to-text for subtitle generation (`TranscribeService`, `TranscribeJobTaskExecutor`) |
| **AWS EFS** | Volume mount (`/mnt/efs`) | Local FS | Shared file storage between containers for media files |
| **Elasticsearch** | `spring-data-elasticsearch` via `fm-common` modules (25+ index modules) | Outbound | Analytics, screen state logs, played content reports, impression data, ad campaign slots, order data, social network content |
| **Redis** | Spring Data Redis + Redisson | Outbound | Token auth cache, application cache (`spring.cache.type=redis`), ShedLock (`shedlock-provider-redis-spring`), distributed locks via `LockServiceModule` |
| **MySQL** | JPA/Hibernate (`jdbc:mysql://...fm_store`) | Outbound | Primary database; Liquibase-managed schema; pool size 10 |
| **Stripe** | `stripe-java` SDK 28.2.0 + inbound webhook (`/stripe/webhook`) | Bidirectional | Subscriptions, invoices, payment intents, prices, products, customers; webhook secret verified via `Stripe-Signature` header |
| **Meta Graph API (Facebook/Instagram)** | Feign (`FacebookFeignClient`, `InstagramAuthFeignClient`, `InstagramGraphFeignClient`) | Outbound | OAuth token exchange and post/video/image fetching for social content library |
| **YouTube Data API v3** | Google API client library | Outbound | Video metadata and key lookup |
| **Google Maps/Places** | `google-maps-services` library (`GoogleMapsConfig`) | Outbound | Address geocoding and place validation (`GooglePlaceService`) |
| **Twilio** | `twilio` SDK | Outbound | SMS OTP for patient authentication (`TwilioProperties`) |
| **GCP Pub/Sub (Firebase)** | Inbound HTTP push webhook (`/webhook/gcp/pubsub`) | Inbound | Device telemetry events from Firebase (player app); decoded via `ExternalEventConverter` plugin chain, routed to `TelemetryService` from `fm-common` |
| **Shippo** | `shippo-java-client` SDK + `ShippoConnector` REST controller | Bidirectional | Hardware shipping label creation and tracking; `ShippoConnector` may proxy requests |
| **Intercom** | `IntercomController` inbound webhook | Inbound | CRM event ingestion |
| **MailChimp** | Webhook (`MandrillWebhookController`) + `MailChimpEmailLogService` | Inbound + Outbound | Email delivery status tracking |
| **Salesforce** | `SalesforceController` + `SalesforceNotificationServiceModule` from `fm-common`; `accountIdSFDC` field on Organization | Outbound (conditional) | CRM sync; gated by `salesforce.enabled` feature flag |
| **XXL-Job Admin** | `XxlJobConfig`, `@XxlJob` handlers; admin URL configured per env | Outbound registration | Distributed job scheduling; executor port 9999 |
| **SMTP (send.smtp.com)** | Spring Mail (`spring-boot-starter-mail`) | Outbound | Transactional email using Thymeleaf/Velocity templates |
| **AWS CodeArtifact** | Maven repository (`vrtly-515289352310.d.codeartifact.us-west-2.amazonaws.com`) | Build-time | Source for `fm-common` internal library |

## Key Data Entities / Domain Models

| Entity | Location | Description |
|---|---|---|
| `Organization` | `entity/business/Organization.java` | Central multi-tenant entity. Represents a healthcare provider or brand. Carries `OrganizationType` (PROVIDER/BRAND/INVENTORY), `CustomerType` (FREEMIUM/PREMIUM), `SubscriptionStatus`, `SubscriptionType`, Stripe customer ID, Chargebee customer ID, Salesforce account ID, onboarding state, feature flags (`v3Enabled`, `v4Enabled`, `autoPilotOn`), and last activity timestamps. Has EAGER collection of `Brand` (risk: see observations). |
| `User` | `entity/auth/User.java` | Spring Security `UserDetails` implementation. Mapped by email (used as username). Linked to `Organization` and `WhiteLabel`; has many-to-many `Role` (EAGER). Supports patient auth via `PhoneBasedAuthentication`. |
| `Content` (abstract) | `entity/content/Content.java` | Single-table inheritance root for the content library. Discriminator column `contentType`. Subclasses: `Video`, `Youtube`, `Album`, `SocialNetworkPost`. Carries `TranscodingStatus` enum, scheduling fields (`scheduleStatus`, `scheduleStartDate`, `scheduleEndDate`), `playlistOnly` flag, `qrCodeUrl`, `ticker`, captions flag. URLs serialized through `CloudFrontSerializer` for signed CDN delivery. |
| `Brand` | `entity/business/Brand.java` | Content creator / sponsor brand. Linked to `PrimaryCategory`, `SecondaryCategory`. Has social handles, CloudFront-signed logo/coverPic. |
| `Screen` | Via `fm-common` `MySqlScreenModule` | Physical display device. Referenced from many entities. Linked to `Organization`, `Room`, `Location`. Has `ScreenType` (hardware), `ScreenMode`. |
| `Playlist` / `PlaylistContent` | `entity/business/Playlist.java`, `PlaylistContent.java` | Provider content playlist. `ScreenPlaylist` join entity maps screens to playlists. |
| `Room` | `entity/business/Room.java` | Physical room containing screens; belongs to a Location. |
| `ProviderSponsor` | `entity/relation/ProviderSponsor.java` | Sponsor contract between a Brand and a Provider Organization. Drives `customerType` lifecycle (FREEMIUM/PREMIUM) and sponsor expiry notifications. |
| `Order` / `OrderItem` / `Invoice` / `Product` / `Subscription` | `entity/ecommerce/` | E-commerce domain for hardware orders (Shippo) and SaaS subscriptions (Stripe). |
| `AdCampaign` | Via `fm-common` `MySqlAdCampaignModule` | Advertising campaign entity. Has screen slots, content, statistics, SOV rules. |
| `InfoPack` / `InfoPackBundle` / `InfoPackContent` | Via `fm-common` `MySqlInfoPackModule`, `MySqlInfoPackBundleModule` | Patient education materials displayed on screens. InfoPack bundles wrap content; consult flow records (`Consult`) track engagement. |
| `Consult` | Via `fm-common` `MySqlConsultModule` | Patient consultation session tracked by the system. Has version statistics and InfoPack associations. |
| `OrganizationUser` | `entity/relation/OrganizationUser.java` | Many-to-many join with extra data: maps Users to Organizations with org-specific role/permission data. |
| `ScreenContent` | `entity/relation/ScreenContent.java` | Association between a Screen and a Content item. Populated by `ScreenContentService.addContentToScreen()` on `ContentAddMessage`. |
| `WhiteLabel` | `entity/business/WhiteLabel.java` | White-label branding instance; Organizations and Users can be scoped to a WhiteLabel. |
| `Leads` / `LeadsGroup` | `entity/business/Leads.java`, `LeadsGroup.java` | Sales lead management for provider acquisition pipeline. |
| `TranscribeJob` | `entity/util/TranscribeJob.java` | Tracks AWS Transcribe job state for subtitle generation. |
| `StripeWebhookType` / `StripeObjectType` | `entity/stripe/` | Enums that categorize Stripe webhook events and route them to typed `StripeWebhookHandler` implementations. |

## Notable Patterns, Risks & Observations

**1. Monolithic surface area — single deployable doing too much**
The API server combines CMS CRUD, payment processing, media pipeline dispatch, social network OAuth, device telemetry ingestion, distributed job execution, and admin tooling in a single Spring Boot JAR. This creates deployment coupling: a bug in the Stripe webhook path or a media upload backlog can degrade CMS responsiveness. Decomposition candidates: media pipeline and payment webhook processing could be isolated services.

**2. `enable_lazy_load_no_trans: true` — open session in view anti-pattern at the ORM level**
`application.yml` explicitly enables `hibernate.enable_lazy_load_no_trans`. This allows Hibernate to open new sessions mid-serialization outside any transaction boundary — a well-documented source of N+1 queries, non-deterministic SQL, and silent data inconsistency under load. Risk is compounded by `@JsonIgnoreProperties` patterns on entities that may or may not serialize associations depending on Hibernate proxy state at serialization time.

**3. EAGER fetch on `Organization.brands` collection**
`Organization.brands` is mapped `@OneToMany(fetch = FetchType.EAGER)`. Every query that loads an Organization will also load its full brand list. Given Organizations are loaded in many contexts (argument resolvers, security checks, list endpoints), this is a systemic N+1 / over-fetch risk.

**4. Entities as API DTOs — no separation layer on legacy paths**
Many controllers (particularly legacy CMS paths) return JPA entities directly as JSON. This is evidenced by `Organization.cmsInfo()` and `Organization.adminInfo()` methods that build `JSONObject` on-entity, and by Fastjson `JSONObject` usage inside entity classes. This couples the API contract to the schema and makes it difficult to evolve either independently. The newer `Modern*Controller` pattern uses MapStruct DTOs (e.g. `ModernScreenController`, `ModernScreenDetailsDto`) — the two approaches coexist without a consistent policy.

**5. Dual JSON libraries — Fastjson + Jackson coexistence**
Alibaba Fastjson (1.2.83) is used inside domain entity methods (`cmsInfo()`, `adminInfo()`, `getPlayerData()`) while Jackson is the Spring serializer. This dual-library setup means field access and null handling behave differently depending on which path serializes a given object. Fastjson 1.2.83 has known CVEs (patched in 1.2.83 but historically problematic); version should be validated against current advisories.

**6. Stripe webhook processed on unbounded `Executors.newFixedThreadPool(10)`**
`StripeWebhookController` spawns a fixed pool of 10 threads and fires-and-forgets webhook handling. There is no queue depth limiting, no backpressure, and no visibility into thread pool saturation. Stripe webhooks can arrive in bursts after outages. If handler threads block (e.g. on DB or external calls) the pool will saturate silently.

**7. Legacy webhook handler dead-code**
In `StripeWebhookController.handle()`, the `isLegacyWebhook()` branch calls `stripeWebhookHandlerLegacy.webhook(jsonObject)` but this call is commented out (`// stripeWebhookHandlerLegacy.webhook(jsonObject);`). The legacy detection logic still runs (DB query via `stripeCustomerService.isLegacyCustomer`), burning DB calls on every webhook for code that does nothing.

**8. YouTube download pipeline — complex distributed state with feature flags gating**
The YouTube download flow involves: api-server creating a content row, dispatching `YoutubeDownloadMessage` to JMS (gated by `youtube.download.enabled`), a separate `youtube-downloader` service claiming ownership via `/internal/youtube-downloads/{id}/claim`, heartbeating, then calling `/complete` or `/fail`. A `YoutubeDownloadRescueService` (ShedLock-protected) periodically re-dispatches stuck `NOT_READY` rows. The rescue flag and download flag are independent. In dev/QA environments both flags are `false` — content added as YouTube type will stay `NOT_READY` indefinitely unless manually triggered. This multi-flag state is a source of confusion and operational risk.

**9. GCP Pub/Sub webhook — in-memory screen lookup cache without eviction**
`GcpPubSubWebhookController` maintains a `ConcurrentHashMap` screen reference cache with a 10-minute TTL per entry. Entries for unknown device IDs are intentionally not cached (correct), but stale or decommissioned screens will stay in cache until TTL expiry. Under high event volume the map can grow without a size bound. A bounded cache (`LinkedHashMap` with LRU or Caffeine) would be safer.

**10. Secrets in application.yml defaults**
`application.yml` contains hardcoded default credentials for local development: DB password (`Aa1?3456`), broker credentials (`devops/aAhuX2RbTJGp5ZksRA7JX8Vtm`), Google Maps API key, Facebook/Instagram OAuth secrets, Stripe test keys, AWS access key ID and secret. These are expressed as defaults (overridden by env vars in ECS task definitions). However they are committed to source control, creating risk if the repo is ever exposed or if defaults are accidentally used in an environment that does not override them.

**11. Large `ImportConfig` — 60+ module imports as application composition**
`ImportConfig.java` explicitly `@Import`s approximately 60 `fm-common` modules. This is a design choice (explicit over auto-configuration), but it means the API server's dependency footprint is tightly coupled to the `fm-common` version and requires code changes to add or remove capabilities. There is no modularity boundary — a change to any `fm-common` module forces a full re-deployment of this service.

**12. XXL-Job for scheduled tasks rather than Spring Scheduler + Quartz**
XXL-Job is a Chinese-origin distributed job scheduler. It requires a separately deployed admin server (`job-admin`). If the XXL-Job admin is unavailable, registered jobs will not execute. All 15+ business-critical scheduled tasks (sponsor email notifications, Elasticsearch sync, ad campaign status updates, transcript repair) depend on this single external system. No fallback or degradation path is apparent in the code.

**13. `@Autowired` field injection in `ScheduledTasks`**
`ScheduledTasks` uses `@Autowired` field injection across 14 dependencies instead of constructor injection. This makes the class harder to test and conceals its coupling surface. The rest of the codebase largely uses `@RequiredArgsConstructor` (Lombok-generated constructor injection) — this class is an outlier.

**14. Mixed `Date` and `LocalDate`/`LocalDateTime`**
Domain entities use `java.util.Date` (legacy) with `@Temporal(TemporalType.TIMESTAMP)`, while newer service code uses `java.time.LocalDateTime`. Both types coexist in the same entities, creating conversion surface area and timezone handling complexity. All DB timestamps are stored as UTC (`serverTimezone=UTC`) but application-level handling varies.

**15. `Organization.brands` cascade + EAGER load on a mutable collection**
`Organization.brands` is `@OneToMany(cascade = CascadeType.ALL, fetch = FetchType.EAGER)`. The combination of ALL cascade and EAGER loading on a potentially large collection is dangerous: any save of an Organization will cascade to all brands, and any load of an Organization will issue a join or secondary select for all brands. This is an unintentional but real performance footgun in multi-brand scenarios.

## Open Questions

1. **What does the `state` service own vs what does `fmcom-api` own for screen state?** The API queries `ScreenStateClient` (from `fm-common`) for screen lookups in several controllers and the GCP webhook. It is unclear where the authoritative screen registry lives — in MySQL via `MySqlScreenModule` (in `fm-common`, imported here) or in a separate `state` service. Clarification needed on which service is the source of truth.

2. **What is the `player` service?** `SERVICE_DISCOVER_PLAYER` appears in the dev task definition environment variables but no `PlayerFeignClient` is visible in the codebase. Is the player service consumed via `fm-common` modules or is that env var vestigial?

3. **What is the Elasticsearch throttling service (`elasticsearch.throttle.*`)?** The configuration references a `ThrottlingServiceModule` from `fm-common` with a `service-id: api` and `initial-limit: 1`. Is this a rate limiter for Elasticsearch writes? What happens when the limit is breached?

4. **Is the legacy Chargebee integration still active?** `Organization` has `cbCustomerId` (Chargebee customer ID) and Stripe customer ID. The `StripeWebhookHandlerLegacy` exists but its call is commented out. Is Chargebee fully decommissioned or are some organizations still on the old billing system?

5. **What triggers the `GCP Pub/Sub webhook` and what `ExternalEventConverter` implementations exist?** Only the `CrashlyticsConverter` is visible in `service/webhook/external/crashlytics/`. Are there additional converters for Firebase Analytics or other GCP log sources that need to be documented?

6. **What is `OrganizationPodAlpha`?** The entity (`entity/business/OrganizationPodAlpha.java`) and its service exist but the business context is unclear — is this a legacy grouping construct or an active feature?

7. **Database sharding / multi-tenancy boundary**: All organizations share the same MySQL database with `organization_id` as a discriminator. Is there any plan for data isolation at the DB level, or is row-level security the long-term model?

8. **`fm-common` version governance**: The library is pinned at `8.9.0`. How is versioning managed across microservices? Is there a compatibility matrix, and what is the risk surface of a `fm-common` upgrade?

9. **What are the `AddressAllowList` / `AddressAllowListDetail` entities used for?** These entities and their admin controller exist but their purpose is not documented — is this an IP allowlist, a physical address allowlist for hardware shipping, or something else?

10. **Elasticsearch is configured but labeled "BQ" in job names**: `ScheduledTasks.syncDataToBq()` and `syncOrderToBq()` have `Bq` in their names (suggesting BigQuery) but call `elasticsearchSyncDataRecordService.syncAll()` and `orderService.syncToElasticsearch()`. Is this a naming artifact from a data warehouse migration, and is there a parallel BigQuery sync path?
