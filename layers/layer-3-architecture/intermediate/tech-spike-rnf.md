---
title: "Tech Spike — Reach-n-Feq (RNF Playlist Resolver / SOV Engine)"
last_updated: 2026-06-12
---

# Tech Spike: Reach-n-Feq (RNF Playlist Resolver / SOV Engine)

## What This Service Does

`reach-n-freq` (RNF) is the compute-intensive, non-CMS backend for the Vrtly platform. It owns three distinct capabilities that together make a screen display something at the right time with the right mix of content:

**1. Playlist generation and SOV enforcement.** For every active screen, RNF builds a time-indexed playlist schedule spanning the current and next calendar day. The generator resolves Share-of-Voice (SOV) rules from Elasticsearch ad-campaign slot data (`ElasticAdCampaignScreenSlot`) and Stripe subscription data to determine per-brand content allocations, then assembles a slot-by-slot sequence that honours those percentages, respects the organization's open-hours schedule, adjusts for patient-traffic density (POD — Period of Day), and avoids excessive content repetition through a scored candidate-selection algorithm. Generated playlists are stored in `ElasticPlaylistSchedule` and the live `play_current` index. The `fmcom-player-api` service consumes the current playlist from RNF via the `GET /playlist/current/{screenId}` HTTP endpoint.

**2. Media processing pipeline.** RNF is the sole executor of video transcoding and PDF-to-image conversion for the platform. It receives work via three JMS queues (`RNF_MEDIA_PROCESSING`, `RNF_TRANSCODE_DESTINATION` legacy shim, `RNF_PDF_TO_IMAGE_DESTINATION` legacy shim), processes media through a four-stage pipeline (download from S3 → FFmpeg normalization to canonical h264 MP4 → standalone tier variants → HLS ABR ladder), and uploads results back to S3. After completing a fresh upload or stuck-recovery transcode, RNF publishes `ContentAddMessage` to `API_CONTENT_ADD` on JMS, which is consumed by `fmcom-api`. This means **RNF is the publisher of `API_CONTENT_ADD`** for the content lifecycle, not fmcom-api self-publishing. fmcom-api dispatches the initial `MediaProcessingMessage` but RNF emits the completion signal. For C3 in the system map: `API_CONTENT_ADD` originates from RNF's `UnifiedVideoPipeline.onComplete()`.

**3. Analytics, reporting, and organization data enrichment.** RNF runs a substantial set of background jobs via XXL-Job: daily playlist generation sweeps, Elasticsearch impression reports, SOV compliance reports, playback reports, screen status reports, proof-of-play reports, organization state tracking, Salesforce data sync, brand ranking updates, and Elasticsearch index optimization. RNF also calls the OutScraper API to enrich organization address data and fetch Google Maps business information.

**Relationship to fmcom-api.** fmcom-api calls RNF over HTTP via `RnfFeignClient` for playlist resolution, and sends work to RNF over JMS (`RNF_MEDIA_PROCESSING`, `RNF_GENERATE`). RNF calls back to fmcom-api implicitly through JMS by publishing to `API_CONTENT_ADD` after transcoding completes, which fmcom-api's `ContentMessageHandlers` consumes to add the content to a default screen.

**Relationship to fmcom-player-api.** fmcom-player-api calls RNF over HTTP (`GET /playlist/current/{screenId}`) to retrieve the live playlist for a screen. RNF also publishes JMS messages (`PLAYER_ORGANIZATION_CONTENT_UPDATED`, `PLAYER_CONTENT_TRANSCODED`, `PLAYER_CONTENTS_TRANSCODED_BATCH`) that player-api consumes.

---

## Tech Stack & Key Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| Spring Boot | 3.2.0 | Core web framework (Jakarta EE namespace) |
| Java | 17 | Runtime |
| `fm-common` (internal) | 8.9.1 | Shared library: all Elasticsearch/MySQL repository modules, JMS destination constants, common DTOs, SOV rule engine, state client, transcoding enums, POD utilities, `DailyPlaylistModule`, `SovRuleServiceModule`, `ContentServiceModule`, `ScreenFilterModule`, `LongPollTaskServiceModule`, `ThrottlingServiceModule`, `TranscodingModule`, `TelemetryModule` |
| Spring Data JPA + Hibernate | Boot-managed | ORM for MySQL; `ddl-auto=validate`; Liquibase-managed schema |
| MySQL (connector 9.6.0) | 9.6.0 | Primary relational datastore; pool size 10 (min-idle 10, max 10); JDBC batch size 500 |
| Liquibase | 4.26.0 | Schema migration management |
| Spring Data Redis | Boot-managed | Application caching; Feign/state client support; `RedisTemplate` configured with Jackson2JsonRedisSerializer |
| Spring Boot ActiveMQ (Amazon MQ) | Boot-managed | JMS for inbound media processing + playlist generate messages; outbound API_CONTENT_ADD, PLAYER_* notifications |
| Spring Cloud OpenFeign | Boot-managed | HTTP clients: `SalesforceAuthFeignClient`, `SalesforceBatchFeignClient`, `SalesforceDataFeignClient`; state-client `InstanceStateClient` from `fm-common` |
| Spring Boot WebFlux | Boot-managed | Reactive HTTP (used by `fm-common` modules) |
| AWS SDK v1 (`aws-java-sdk-s3` 1.12.649) | 1.12.649 | S3 download, upload; CloudFront signed URL generation |
| AWS SDK v1 (`aws-java-sdk-cloudfront` 1.12.671) | 1.12.671 | CloudFront cache invalidation after re-transcode |
| AWS SDK v2 (`s3-transfer-manager` 2.31.30) | 2.31.30 | S3 Transfer Manager for high-throughput multi-part upload |
| AWS CRT (`aws-crt` 0.38.1) | 0.38.1 | Native runtime for S3 Transfer Manager |
| AWS SDK v2 BOM | 2.31.30 | Dependency management for all AWS SDK v2 modules |
| XXL-Job | 2.4.0 | Distributed scheduled job execution; admin at configurable URL; executor port 9996 |
| SpringDoc OpenAPI | 2.2.0 | Swagger UI at `/swagger-ui/index.html` |
| MapStruct | 1.5.5.Final | Compile-time DTO/entity mapping |
| Lombok | Boot-managed | Boilerplate reduction |
| Jackson `jackson-datatype-jsr310` | Boot-managed | Java 8 date/time serialization |
| `threeten-extra` | 1.7.2 | `LocalDateRange` used extensively in SOV and playlist scheduling |
| `java-string-similarity` | 2.0.0 | String similarity for OutScraper organization name matching |
| Apache PDFBox | 3.0.0 | PDF-to-image rasterization for InfoPack content |
| Feign OkHttp | 13.4 | OkHttp HTTP client backing for Feign (replaces default Java client) |
| Testcontainers | Boot-managed | Integration test containers |
| H2 | Boot-managed (test scope) | In-memory DB for unit tests |
| Spring Boot Actuator | Boot-managed | Health/metrics endpoints; all endpoints exposed |
| Logback | Boot-managed | Logging; logback-spring.xml configuration |
| Checkstyle | 10.10.0 | Code style enforcement at `validate` phase; violations fail the build |
| Maven Surefire | Boot-managed | Test runner; pattern `**/*Test.java` |

---

## Main Modules / Packages

| Package | Purpose |
|---|---|
| `ai.vrtly.reachnfreq` | Application entry point (`ReachNFreqApplication`) |
| `config` | Spring configuration: `ImportConfig` (40+ `fm-common` module imports), `FeignConfig` (Feign client scan + `InstanceStateClient` ping/heartbeat with `System.exit(-1)` on connection loss), `RedisConfig` (Redis template), `XxlJobConfig` (XXL-Job executor registration), `SchedulingConfig`, `WebConfig`, `SalesforceConfig`, `SalesforcePatchConfig`, `OutScraperConfig`, `CurrentPropertiesConfig` |
| `config/props` | `FeatureFlagProperties` (`feature.includePaidScreens`), `ElasticOptimizationProperties` (batch-delete size, throttling config) |
| `listener` | JMS message handlers subscribed via `@PostConstruct`: `MessageHandlers` (subscribes to `RNF_GENERATE` → triggers playlist generation), `MediaProcessingHandlers` (unified `RNF_MEDIA_PROCESSING` → `MediaPipelineOrchestrator`), `TranscodeHandlers` (legacy shim: `RNF_TRANSCODE_DESTINATION` → orchestrator; also hosts `executeTranscoding` XXL-Job sweep), `FileConversionHandlers` (legacy shim: `RNF_PDF_TO_IMAGE_DESTINATION` → orchestrator), `OrganizationOpenHoursHandlers` (`RNF_OPEN_HOURS_UPDATED` → `OrganizationInfoService.updateLocationOpenHours`), `RecentlyActivatedHandlers` (`RNF_RECENTLY_ACTIVATED` → `OrganizationInfoService.updateOrganizationData`) |
| `web` | REST controllers: `TranscodingController` (admin bulk re-transcode endpoints), `TranscodingJobsController` (bulk job progress poll), `PlaylistCurrentController` (`/playlist/current/{screenId}` — called by player-api), `SovRuleController` (manual SOV report generation), `OrganizationController`, `BrandController`, `AdCampaignController`, `SponsorController`, `ScreenContentController` (CSV report), `ScreenStatusReportsController`, `ImpressionReportsController`, `DailyFootTrafficController`, `DailyScreenActivityController`, `OrganizationHourlyDistributionController`, `OrganizationOpenHoursController`, `NetworkController`, `PodController`, `PracticeActivationController`, `SalesforceController`, `ExternalParametersController`, `CustomController`, `AdviceController` (global exception handler) |
| `service` | Top-level service interfaces and implementations covering all domain operations: `PlaylistGenerationService` / `PlaylistGenerationServiceImpl` (playlist scheduling orchestration with `PlaylistPrioritizedTaskExecutor`), `VideoTranscodeService` / `VideoTranscodeServiceImpl` (bulk transcode REST entry point), `ScreenSlotSovService` / `ScreenSlotSovServiceImpl` (per-screen SOV rule resolution), `ImpressionService`, `OrganizationService`, `BrandService`, `ScreenService`, `ScreenContentService`, `AdCampaignService`, `SponsorService`, `OrganizationInfoService`, `OrganizationOpenHoursService`, `OrganizationStateService`, `OrganizationAddressService`, `OutScraperApiService`, `ContentPieceService`, `ContentServiceExt`, `FileConversionService`, `NetworkService`, `OrderService`, `PlaybackReportService`, `PlaylistCurrentServiceLocal`, `PracticeActivationService`, `ProofOfPlayReportService`, `ScreenRoomTypeService`, `ScreenStatusService`, `ScreenStatusGlobalReportService`, `SovRuleReportService`, `StripeCustomerService`, `OrganizationHourlyDistributionService`, `DailyFootTrafficService`, `DailyScreenActivityService`, `PodService`, `OrganizationPodAlphaService`, `OrganizationPlaceValidityService` |
| `service/generator` | `PlaylistGeneratorService` / `PlaylistGeneratorServiceImpl` — core per-screen and per-org playlist assembly algorithm: builds time periods from open-hours, calls `ScreenSlotSovService`, loads content via `ContentServiceExt`, fills `ContentContainer`, iterates slots using `getBy(TrafficLevel, time)` |
| `service/media` | `MediaPipeline` (interface: `supports()` + `execute(MediaProcessingMessage)`), `MediaPipelineOrchestrator` (routes by `MediaOperation` enum to registered pipeline beans; fails fast on unknown operations or duplicate pipeline registrations) |
| `service/media/impl` | `VideoTranscodePipeline` (`MediaOperation.VIDEO_TRANSCODE` → `UnifiedVideoPipeline`), `PdfToImagePipeline` (`MediaOperation.PDF_TO_IMAGE` → `FileConversionService`) |
| `service/media/video` | `UnifiedVideoPipeline` (singleton; 4-stage download/transcode/upload/notify; three `ExecutorService` pools; bounded `LinkedBlockingQueue` for back-pressure; shutdown hook; JVM-level dedup via `inPipeline` set), `BulkJobHandle` (per-submission progress tracker; `whenComplete` callback), `BulkJobRegistry` (in-memory registry; 1-hour TTL post-completion), `TranscodePipelineVersion` (monotonic integer stamp; currently `7`), `TriggerMode` (enum: `MESSAGE` vs `REST_BULK`; governs `API_CONTENT_ADD` emission and claim-phase source-status filtering) |
| `service/media/video/conversion` | `ConversionService` (HLS ABR ladder generation interface), `ConversionServiceCommon` (shared ffmpeg filter chain; `colorNormalizationFilters` selects between HDR tonemap, wide-gamut SDR, or passthrough), `StreamingService` (HLS implementation) |
| `service/salesforce` | `SalesforceAuthService`, `SalesforceDataService` with Feign-backed implementations |
| `service/mapper` | MapStruct mappers: `PlaylistScheduleMapper`, `BrandMapper`, `ImpressionReportMapper`, `NetworkMapper`, `OrganizationGoogleMapsMapper`, `ScreenStatusesMapper`, `SponsorMapper`, `BaseToDtoMapper` |
| `model/mysql` | Local JPA entities owned by RNF: `Organization` (read-only projection of the shared `fm_store` schema), `OrganizationHourlyDistribution`, `OrganizationPlaceValidity`, `OrganizationPodAlpha`, `Room`, `Screen`, `ScreenToBrandMapping` |
| `model/dto` | All DTO classes: playlist schedule DTOs, SOV DTOs, screen status DTOs, impression report DTOs, dashboard DTOs, OutScraper DTOs, Salesforce DTOs |
| `model/dto/generation` | `ContentContainer` (SOV-aware content pool: scores, targets, min-targets, pre-delay calculations, candidate selection), `AllocationStrategy` (SOV / ADJUST / RANDOM), `TrafficLevel` (HIGH / LOW), `PlaylistContainer`, `PeriodContainer`, `ScoreContainer`, `GenerationParamDto`, `GenerationTaskCallable`, `GenerationTaskRunnable`, `GenerationTaskRunnableFuture`, `PlaylistPrioritizedTaskExecutor`, `GenerationUtils` |
| `repository/mysql` | Local Spring Data repositories for `Organization`, `OrganizationHourlyDistribution`, `OrganizationPlaceValidity`, `OrganizationPodAlpha`, `Room`, `Screen`, `ScreenToBrandMapping`; projections and mappings |
| `feign` | `SalesforceAuthFeignClient`, `SalesforceBatchFeignClient`, `SalesforceDataFeignClient` |
| `job` | XXL-Job handlers: `GenerateDailyPlaylistJob` (`playlistDailyGenerate`, `playlistDailyCleanup`, deprecated `generatePlaylistDaily`), `TranscodeHandlers.executeTranscoding` (hosted in listener package), `ElasticOptimizationJob`, `ImpressionReportJob`, `SovRuleReportJob`, `ScreenStatusReportJob`, `ScreenStatusGlobalReportJob` (via `ScreenStatusGlobalReportService`), `PlaybackReportJob`, `ProofOfPlayReportJob`, `OrganizationStateJob`, `OrganizationInfoUpdateJob`, `BrandRankingUpdateJob`, `SalesforceDataSyncJob`, `ScreenLastDisplayedUpdateJob`, `PlaylistScheduleShrinkJob`, `InfoPackPdfToImageConversionJob`, `InfoPackVisitsReportCalculationJob`, `LocationMigrationJob`, `YoutubeContentDownloadReenqueueJob`, `Above1080pSrcRewriteJob` |
| `task` | Long-poll tasks: `UpdateOrganizationStateLongPollTask`, `UpdateSalesforceAccountsLongPollTask`, `UpdateSalesforcePracticeUsersLongPollTask`, `UpdateSalesforceScreensLongPollTask` |
| `enums` | `AppConstant` (organization-excluded-generation enum) |
| `exception` | `PlaylistGenerationException` |
| `utils` | Utility helpers |

---

## External Integrations

| Integration | Mechanism | Direction | Notes |
|---|---|---|---|
| **Amazon MQ (ActiveMQ)** | Spring JMS (`ssl://...mq.us-west-2.amazonaws.com:61617`); `BROKER_PREFIX` environment variable namespaces all destinations | Bidirectional | See JMS detail rows below |
| **JMS inbound: `RNF_GENERATE`** | `MessagingService.subscribe` in `MessageHandlers` | Inbound | `GenerateMessage` (orgId or screenId); triggers `PlaylistGenerationService.generateOrg` / `generateScreen`; gated by `rnf.jms.handlers.generate` |
| **JMS inbound: `RNF_MEDIA_PROCESSING`** | `MessagingService.subscribe` in `MediaProcessingHandlers` | Inbound | Unified `MediaProcessingMessage` (operation + contentId + store); routes to `MediaPipelineOrchestrator`; gated by `rnf.jms.handlers.media-processing` |
| **JMS inbound: `RNF_TRANSCODE_DESTINATION`** (legacy shim) | `MessagingService.subscribe` in `TranscodeHandlers` | Inbound | `TranscodeMessage`; converted to `MediaProcessingMessage(VIDEO_TRANSCODE)` and forwarded to orchestrator; scheduled for removal once `fmcom-api` fully migrated; gated by `rnf.jms.handlers.transcode` |
| **JMS inbound: `RNF_PDF_TO_IMAGE_DESTINATION`** (legacy shim) | `MessagingService.subscribe` in `FileConversionHandlers` | Inbound | `PdfToImageMessage`; converted to `MediaProcessingMessage(PDF_TO_IMAGE)` and forwarded; gated by `rnf.jms.handlers.pdf-to-image` |
| **JMS inbound: `RNF_OPEN_HOURS_UPDATED`** | `MessagingService.subscribe` in `OrganizationOpenHoursHandlers` | Inbound | `OpenHoursUpdatedMessage` (locationId); triggers open-hours re-fetch from OutScraper/Google |
| **JMS inbound: `RNF_RECENTLY_ACTIVATED`** | `MessagingService.subscribe` in `RecentlyActivatedHandlers` | Inbound | `RecentlyActivatedMessage` (orgId); triggers organization data refresh |
| **JMS outbound: `API_CONTENT_ADD`** | `MessagingService.send` in `UnifiedVideoPipeline.onComplete()` | Outbound | `ContentAddMessage`; published only for `TriggerMode.MESSAGE` flows (fresh upload, per-id REST dispatch, stuck-recovery sweep); consumed by `fmcom-api` `ContentMessageHandlers` to add content to a default screen |
| **JMS outbound: `PLAYER_ORGANIZATION_CONTENT_UPDATED`** | `MessagingService.send` in `PlaylistGenerationServiceImpl` | Outbound | `OrganizationUpdateMessage`; emitted after org playlist generation completes |
| **JMS outbound: `PLAYER_CONTENT_TRANSCODED`** | `MessagingService.send` in `UnifiedVideoPipeline.uploadPhase` | Outbound | `ContentTranscodedMessage` (single content id); emitted per-item for `TriggerMode.MESSAGE` flows only |
| **JMS outbound: `PLAYER_CONTENTS_TRANSCODED_BATCH`** | `BulkJobHandle.whenComplete` callback in `UnifiedVideoPipeline` | Outbound | `ContentsTranscodedBatchMessage` (list of ids); emitted once per completed `TriggerMode.REST_BULK` job on seal; consolidates per-item broadcasts to reduce downstream cascade overhead |
| **JMS outbound: `PLAYER_SCREEN_CONTENT_UPDATED`** | `MessagingService.send` in playlist generation flow | Outbound | `ScreenUpdateMessage`; screen-level playlist update notification |
| **fmcom-player-api** | Inbound HTTP — RNF exposes `GET /playlist/current/{screenId}` | Inbound HTTP | `PlaylistCurrentController`; returns `PlaylistCurrentDto`; player-api calls RNF here to get the live scheduled playlist |
| **State service** | `InstanceStateClient` (Feign) from `fm-common` `StateClientModule` | Outbound | URL configured via `SERVICE_DISCOVER_STATE`; used for screen state lookups; RNF pings the State service at startup and on a 1-minute heartbeat — **hard exit (`System.exit(-1)`)** if the connection is lost |
| **AWS S3** | AWS SDK v1 (`AmazonS3`) + SDK v2 S3 Transfer Manager | Outbound | Downloads source video from S3 for transcoding; uploads all transcoded artifacts (main h264, standalone tier variants, HLS master + rung playlists + `.ts` segments); also used for orphan-artifact cleanup (list + delete S3 objects) and re-transcode CloudFront invalidation |
| **AWS CloudFront** | SDK v1 (`aws-java-sdk-cloudfront`) | Outbound | Folder-path wildcard invalidation on re-transcode to clear CDN-cached stale artifacts; gated on `isReTranscode` and the presence of a derivable content folder; CloudFront distribution ID configured per env |
| **Elasticsearch (OpenSearch)** | `spring-data-elasticsearch` via 20+ `fm-common` elastic modules | Outbound | Reads: `ElasticAdCampaignScreenSlot` (SOV rules), `ElasticPlaylistSchedule` (existing playlist data), `ElasticPlayCurrent`, `ElasticScreenStateLog`, etc. Writes: `ElasticPlaylistSchedule`, impression reports, SOV reports, playback reports, proof-of-play reports, screen status reports. Throttled via `ThrottlingServiceModule` (`elasticsearch.throttle.*`); heavy jobs request quota increase via `ElasticsearchLimitClient` before concurrent sweeps |
| **MySQL** | JPA/Hibernate (`jdbc:mysql://...fm_store`) | Outbound | Reads organization, screen, brand, ad-campaign, content, open-hours, and Stripe subscription data from the shared `fm_store` schema (via `fm-common` MySQL modules). Writes organization hourly distribution, place validity, POD alpha. Liquibase-managed; pool 10/10 |
| **Redis** | Spring Data Redis (`spring.data.redis.*`); database index 4 (dev/QA), 2 (prod) | Outbound | Application caching; `fm-common` modules use Redis for distributed coordination; playlist generation `SyncOpService` uses Redis for per-screen mutual-exclusion; `fm-common` `LongPollTaskServiceModule` uses Redis |
| **OutScraper API** | `WebClient` (reactive HTTP) via `OutScraperApiService`; API key from SSM | Outbound | `https://api.outscraper.cloud`; used to fetch organization open-hours, place data, popular times, and working-hours info by address |
| **Salesforce** | `SalesforceAuthFeignClient` (auth) + `SalesforceDataFeignClient` (CRUD) + `SalesforceBatchFeignClient` (bulk API); gated by `salesforce.enabled` | Outbound | CRM sync for organizations, screens, users; long-poll tasks run Salesforce data sync; credentials from SSM |
| **XXL-Job Admin** | `XxlJobConfig` executor registration; port 9996 | Outbound registration | Admin URL configured via `XXL_JOB_ADMIN_ADDRESSES`; 18 registered XXL-Job handlers across `job/` and `listener/` packages |
| **AWS EFS** | Volume mount (`/mnt/efs`) | Local FS | Shared EFS volume for transcoding temp storage (`transcoding.temp-storage-path`); shared across instances of the same ECS service so the download worker and transcode worker can share the same filesystem during pipeline processing |
| **AWS SSM Parameter Store** | ECS task definitions; `secrets` section | Build/deploy | Sensitive values (DB, Redis, ES credentials, MQ password, OutScraper key, Salesforce secrets, AWS keys) injected as container environment variables from SSM at task launch |
| **AWS ECR** | Bitbucket Pipelines OIDC → ECR push | CI/CD | Image: `515289352310.dkr.ecr.us-west-2.amazonaws.com/reach-n-freq` |

---

## Key Data Entities / Domain Models

| Entity | Location | Description |
|---|---|---|
| `Organization` | `model/mysql/Organization.java` | Local read-only JPA projection of the shared `fm_store.organization` table. Carries `id`, `name`, `status`, `OrganizationType`, `CustomerType`, `v3Enabled`, `v4Enabled`, `utcOffset`, `treatPatientsNum`, `demo`, `createdDate`, `connectedDate`, `lastActiveSince`, `lastInactiveSince`. Used by generation eligibility queries and organization service. |
| `Screen` | `fm-common` `MySqlScreenModule` | Physical display device. Not redefined in RNF; accessed via `fm-common` repositories (`MySqlScreenRepository`). Linked to organization, room, location. Has subscription status, screen type, mode. |
| `Room` | `model/mysql/Room.java` | Physical room containing screens; belongs to a Location. Local JPA entity projection. |
| `OrganizationHourlyDistribution` | `model/mysql/OrganizationHourlyDistribution.java` | Persists per-organization per-hour patient volume estimates. Written by `OrganizationHourlyDistributionService` based on OutScraper popular-times data; drives POD (Period of Day) traffic-level classification for playlist generation. |
| `OrganizationPlaceValidity` | `model/mysql/OrganizationPlaceValidity.java` | Tracks the last-validated Google Maps place ID and validity state for an organization. Used by `OrganizationPlaceValidityService` to cache OutScraper lookups. |
| `OrganizationPodAlpha` | `model/mysql/OrganizationPodAlpha.java` | Alpha-tier grouping construct for organizations. Accessed via `OrganizationPodAlphaService`; exact business purpose unclear from the code — appears to be a test cohort or early-adopter grouping. |
| `ScreenToBrandMapping` | `model/mysql/mapping/ScreenToBrandMapping.java` | Maps screens to the brands whose content is eligible on that screen. Used by `ScreenSlotSovService` to derive per-screen brand sets for SOV percentage allocation. |
| `ElasticAdCampaignScreenSlot` | `fm-common` `ElasticAdCampaignScreenSlotModule` | Elasticsearch document that holds per-screen, per-date SOV slot allocation data for an ad campaign. Contains `screenId`, `date`, `brandId`, `ElasticSovRule` with percentage breakdowns. The primary input to `ScreenSlotSovServiceImpl` for freemium screens. |
| `MySqlScreenStripeSubscription` | `fm-common` `MySqlScreenStripeSubscriptionModule` | Stripe subscription row for a screen. When active (non-null `customPercentage`), determines that the screen is on a paid plan and drives `getPaidRules()` instead of ad-campaign slot lookup. Fields: `screenId`, `active`, `customPercentage`, `endDate`. |
| `ElasticPlaylistSchedule` | `fm-common` `ElasticPlaylistScheduleModule` | Elasticsearch document persisting the generated daily playlist schedule for a screen. Output of `PlaylistGenerationServiceImpl`; content is a time-indexed series of content slots. Read by the current-playlist service to serve `fmcom-player-api`. |
| `ElasticPlayCurrent` | `fm-common` `ElasticPlayCurrentModule` | Live "now playing" index for a screen; updated whenever a new playlist is generated. |
| `ContentContainer` | `model/dto/generation/ContentContainer.java` | In-memory domain object, not persisted. Encapsulates the full SOV-aware content pool for one screen/day: resolved targets (percentages per brand), `ranked` list (pre-built pool sized to SOV allocations), scored candidates, pre-delay schedules, and the `getBy(TrafficLevel, LocalTime)` method that drives real-time slot selection. Allocation strategy can be SOV, ADJUST (overuse correction), or RANDOM (< 10 items or no rules). |
| `ScreenSlotSovDto` | `model/dto/ScreenSlotSovDto.java` | Transfer object carrying the resolved SOV rule (`SovRuleDto`), per-brand percentage map, and the set of paid brand IDs for a given screen/date combination. Output of `ScreenSlotSovServiceImpl`; input to `ContentContainer` and the `PlaylistGeneratorServiceImpl.generate()` loop. |
| `PlaylistScheduleDto` / `PlaylistScheduleContentDto` | `model/dto/` | Output DTOs of the playlist generator: `PlaylistScheduleDto` holds a full day's time-indexed content sequence for a screen; `PlaylistScheduleContentDto` is a single slot entry with datetime and content reference. Mapped by `PlaylistScheduleMapper` to `ElasticPlaylistSchedule` for persistence and to `PlayCurrentDto` for the live index. |
| `ScoreContainer` | `model/dto/generation/ScoreContainer.java` | Wraps a `ContentDetailsDto` with runtime scoring state: per-candidate score (composed of priority, last-display, and pre-delay sub-scores), last-used time, play count, content ownership type, traffic level. Sorted by `SCORE_COMPARATOR` to build the `dispersion`-sized candidate window. |
| `PeriodContainer` | `model/dto/generation/PeriodContainer.java` | Represents one continuous time window (open-hours segment or off-hours gap) within the generation range. Carries date, open/close times, `isWorking` flag, `isFirst`/`isLast` flags, and the `SortedSet<PodContainerDto>` of traffic slots within the period. The generation algorithm iterates these in order. |
| `BulkJobHandle` | `service/media/video/BulkJobHandle.java` | Tracks progress of a bulk transcoding submission: UUID job id, `ContentStore`, `TriggerMode`, expected/processed/skipped/failed/claimed counters, sealed flag, `whenComplete(Runnable)` callback. Registered in `BulkJobRegistry` for 1-hour post-completion query window. |
| `ContentAddMessage` | `fm-common` JMS DTO | The JMS message published by `UnifiedVideoPipeline.onComplete()` to `API_CONTENT_ADD` after a successful transcode. Carries `contentId`, optional `organizationId`, optional `screenId`, and `ContentStore`. Consumed by fmcom-api's `ContentMessageHandlers`. |

---

## Notable Patterns, Risks & Observations

**1. RNF is the publisher of `API_CONTENT_ADD`, not fmcom-api self-publishing.**
After a video transcodes successfully under `TriggerMode.MESSAGE`, `UnifiedVideoPipeline.onComplete()` publishes `ContentAddMessage` to `Destinations.API_CONTENT_ADD`. This is the signal that causes fmcom-api's `ContentMessageHandlers` to add the transcoded content to a default screen. This is a critical C3 flow fact: the transcoding completion triggers a downstream content-assignment side-effect in fmcom-api. For `TriggerMode.REST_BULK` (admin re-transcodes), the notification is intentionally suppressed — already-assigned content must not be re-added to a default screen.

**2. Hard process exit on State Service loss is a significant operational risk.**
`FeignConfig.connectionCheck()` runs on a 1-minute `@Scheduled` timer and calls `System.exit(-1)` if the State Service ping fails. This means a transient State Service outage or even a brief network hiccup will **terminate the RNF JVM entirely**. ECS will restart the container, but any in-flight transcodes are immediately interrupted (the shutdown hook marks claimed rows as FAILED), and any in-progress playlist generations are cancelled. There is no backoff, no retry, no alerting differentiation between transient and permanent unavailability.

**3. SOV algorithm is a sophisticated multi-phase in-memory engine — complex and not unit-tested at the algorithm level based on visible test files.**
`ContentContainer` runs up to five iterative passes of overuse adjustment (`adjustContentOveruse`), content-eligibility pruning (`fitContentToTargets`, `removeNonSuitableContent`), and brand-distribution validation (`validatePercentages`). The scoring function composes three independent sub-scores (priority from content ownership type × traffic level, time-since-last-display, pre-delay positional hint). A `ThreadLocalRandom` probability-weighted selection is used for the common path. This is algorithmically dense and the correctness is hard to verify without a comprehensive test suite. A test case covering edge scenarios (single content item, mismatched SOV percentages, content shorter than min playlist slot) would de-risk future changes.

**4. `PlaylistPrioritizedTaskExecutor` handles concurrency but the bounds are implicit.**
`PlaylistGenerationServiceImpl` uses a `PlaylistPrioritizedTaskExecutor` (a `ThreadPoolExecutor` subclass) for async generation, with in-memory `ConcurrentHashMap` maps tracking in-flight org/screen/save tasks. `MAX_ALLOWED_PARALLEL_GENERATIONS = 6` is enforced in the daily job via `ConcurrentExecutor.execute(…, 6)`. However individual `generateOrg` calls (from JMS messages) are submitted to the same pool without a parallel-count cap — only the XXL-Job daily sweep enforces the limit. Under load, JMS-triggered regenerations could saturate the thread pool.

**5. `UnifiedVideoPipeline` is a singleton with three long-lived thread pools and bounded back-pressure — well-designed but EFS-dependent.**
The pipeline separates download (I/O-bound, configurable pool), transcode (CPU-bound, typically 2 workers in prod), and upload (configurable) stages with a bounded `downloadedQueue` (`pipelineDownloadAheadLimit = 10` in prod) providing natural back-pressure. This is sound architecture. The critical dependency is the shared EFS mount at `/mnt/efs`: if EFS is unavailable, the pipeline cannot stage files and all in-flight transcodes fail. EFS mounts are ECS-configured; no code-level error handling exists for filesystem unavailability beyond FFmpeg/S3 exceptions propagating up.

**6. `TranscodePipelineVersion` (currently `7`) is a versioning contract shared between encoder and serving-side consumers — bump discipline matters.**
The pipeline stamps every produced `detailsCurrent` and `detailsStream` entry with an integer version. `UnifiedVideoPipeline.isAtCurrentPipelineVersion()` uses this to skip already-current content in bulk sweeps. The `>= CURRENT` comparison means a downgraded instance (older binary after a rollback) will never re-encode content stamped by a newer pipeline — by design. The risk is that an accidental ffmpeg-parameter change without a version bump silently serves stale-quality content from S3 until a manual re-transcode sweep is run.

**7. `open-in-view: true` is enabled — Hibernate open-session-in-view is active.**
`application.yml` sets `spring.jpa.open-in-view: true` (the Spring Boot default, not explicitly disabled). This allows Hibernate to lazily load associations during HTTP response serialization, outside any transaction boundary. The risk is the same as in fmcom-api: silent N+1 queries during response rendering, non-deterministic session lifecycle, and potential for serialization behavior to vary depending on proxy state. The impact is lower in RNF than in fmcom-api (RNF has fewer direct HTTP endpoints returning entities), but the flag should be explicitly set to `false`.

**8. JMS concurrency min/max defaults to match the transcode pool — but dev/QA do not configure `RNF_JMS_MAX_CONCURRENCY`.**
`application.yml` sets `spring.jms.listener.min-concurrency` and `max-concurrency` from `RNF_JMS_MIN_CONCURRENCY` / `RNF_JMS_MAX_CONCURRENCY` (defaults `1` / `2`). These default values match `TRANSCODING_TRANSCODE_POOL_SIZE=2` in prod. However dev and QA task definitions do not set `TRANSCODING_TRANSCODE_POOL_SIZE` or the JMS concurrency variables, meaning dev/QA run the default transcode pool of 2 workers but JMS could deliver messages faster than the pipeline can process them. The `downloadedQueue` bounded to `pipelineDownloadAheadLimit` (default `10` in dev since it is also not set in the dev task definition) provides the safety valve.

**9. Broker credentials are in plaintext in the dev and QA task definitions.**
`dev-task-definition.json` and `qa-task-definition.json` contain `BROKER_USER: devops` and `BROKER_PASSWORD: aAhuX2RbTJGp5ZksRA7JX8Vtm` as plaintext `environment` entries. The production task definition correctly uses SSM `secrets` for broker credentials. Dev/QA using the same physical Amazon MQ broker (same `b-451110d0-...` endpoint) as production but with plaintext credentials in committed JSON is a credential hygiene risk. These should be moved to SSM secrets.

**10. The State Service connection check uses `System.exit(-1)` with no documented runbook.**
While the state-client ping was designed as a liveness guard, the `System.exit(-1)` escalation is drastic and untested against scenarios such as: State Service rolling deployment (brief gap), ECS network interface reassignment, or load-balancer health-check flapping. No comment or documentation in `FeignConfig` explains the expected operational response. An operator seeing RNF containers cycling needs to look at CloudWatch logs to understand the cause; the `FATAL: Connection to State Service lost` log line is the only signal, and it is at `ERROR` level (not a dedicated alarm metric).

**11. `GenerateDailyPlaylistJob.playlistDailyUpdate()` is `synchronized` — single-threaded across XXL-Job re-submissions.**
The daily generation job method is `synchronized` on the Spring bean instance. This prevents concurrent XXL-Job invocations of the same job from running in parallel (correct), but it also means a manual XXL-Job re-trigger while the daily run is still in progress will block the thread pool until the first run completes. With `TIMEOUT_EXECUTION_ORG_MS = 30 minutes` per org and potentially hundreds of orgs, a full generation sweep can take significant wall-clock time. The blocking `synchronized` guard and the `waitForCompletion(task, …, TIMEOUT_EXECUTION_ORG_MS)` inside `generateOrg` mean the daily job thread is effectively held for the full generation duration.

**12. Orphan S3 cleanup after re-transcode is conservative but skips `ContentStore.CONSULT` entirely.**
After each transcode upload, `cleanupOrphanS3Objects()` lists and deletes S3 artifacts from prior runs (stale tier variants, old HLS segments) that are no longer in the just-uploaded set. `ContentStore.CONSULT` is explicitly excluded from cleanup because its S3 layout uses a shared org-level directory rather than per-content isolation — deleting by content-pattern could remove files belonging to sibling consult content. This is a correct safeguard, but it means stale artifacts for CONSULT content are never automatically cleaned and will accumulate on S3 indefinitely.

**13. `PlaylistGenerationServiceImpl` has 30-minute and 5-minute wall-clock timeouts — silent deadline misses.**
`TIMEOUT_EXECUTION_ORG_MS = 1,800,000` (30 min) and `TIMEOUT_EXECUTION_SCREEN_MS = 300,000` (5 min). If generation exceeds these, `waitForCompletion` returns the default value (null/empty set) silently. There is a `detectLongRunningTask` logger call at the threshold but no alert or metric emission. A screen stuck in generation produces no playlist update silently, and the failure mode is invisible unless operators actively watch logs.

**14. `RNF_JMS_ENABLED` is a global kill switch that disables all six JMS listeners simultaneously.**
Setting `rnf.jms.enabled=false` disables every JMS subscription — playlist generation, media processing (unified and legacy shims), open-hours updates, and recently-activated notifications. This is useful for dedicated bulk-transcoding instances (as noted in `UnifiedVideoPipeline` comments), but there is no per-category coarse kill switch between the individual handler flags and the global `rnf.jms.enabled`. An operator wanting to pause only playlist generation cannot do so without also pausing media processing.

**15. `feature.includePaidScreens = false` hardcoded default — no environment-level override in task definitions.**
`FeatureFlagProperties.includePaidScreens` defaults to `false` and none of the four task definitions set `FEATURE_INCLUDE_PAID_SCREENS`. This flag gates whether premium (paid) screens participate in certain analytics or generation paths. If the intent is to enable this for some environments, the absence from task definitions means it is silently `false` everywhere.

**16. Dual JMS destinations for `API_CONTENT_ADD` — RNF sends it, fmcom-api also sends it internally.**
From the fmcom-api spike, `API_CONTENT_ADD` appears in fmcom-api's outbound JMS table as well (fmcom-api publishes it for non-transcoding content events). RNF also publishes it after transcoding. The same JMS topic is thus written by two independent services. The consumers (fmcom-api `ContentMessageHandlers`) must handle idempotent delivery, since both fmcom-api and RNF can publish `API_CONTENT_ADD` for the same `contentId` in certain flows.

---

## Open Questions

1. **Is `API_CONTENT_ADD` published by both fmcom-api and RNF for the same content, and is the consumer (`ContentMessageHandlers` in fmcom-api) idempotent?** The fmcom-api spike lists `API_CONTENT_ADD` as both an inbound and outbound destination in fmcom-api. RNF `UnifiedVideoPipeline.onComplete()` also publishes to it. If fmcom-api self-publishes `API_CONTENT_ADD` for a content event and RNF also publishes it after transcoding the same content, the `ContentMessageHandlers` will process the same `contentId` twice. Clarification is needed on whether double-processing is idempotent (upsert semantics) or causes duplicate screen assignments.

2. **What is the scope and membership criteria for `OrganizationPodAlpha`?** `OrganizationPodAlpha`, `OrganizationPodAlphaService`, and `PodService` exist with meaningful-looking logic but no business documentation. Is this an active production cohort for A/B testing of the POD algorithm, a legacy grouping from an earlier version of the feature, or an admin-managed override mechanism? This affects how the generation algorithm selects traffic-level classifications for some organizations.

3. **Why does `FeignConfig.connectionCheck()` call `System.exit(-1)` rather than publishing a health metric or triggering an ECS health-check failure?** The current implementation kills the entire JVM on a State Service ping failure — including abandoning in-flight transcodes. An ECS health endpoint (`/actuator/health`) that reports `DOWN` when the State Service is unreachable would allow ECS to gracefully drain and replace the task without destroying in-progress work. Is the `System.exit` approach intentional, and is there a runbook for operators?

4. **What happens to the `YoutubeContentDownloadReenqueueJob` in RNF's context?** RNF has a `YoutubeContentDownloadReenqueueJob` in the `job/` package. From the fmcom-api spike, YouTube download management appears to live in fmcom-api (with `YoutubeDownloadLockService`, `YoutubeDownloadRescueService`). What does RNF's re-enqueue job do, and is it operating on the same `content` rows or a different mechanism?

5. **How is the `fm-common` version (`8.9.1` in RNF vs `8.9.0` in fmcom-api) managed across deployments?** RNF is on `8.9.1` while fmcom-api was on `8.9.0` at the time of its spike. Given that both services share `fm-common` JMS message DTOs (e.g. `ContentAddMessage`, `MediaProcessingMessage`) and Elasticsearch models, a version drift can cause serialization incompatibilities. Is there a compatibility matrix or a governance process for `fm-common` version alignment across the fleet?

6. **Is the legacy dual-listen rollout complete or still in progress?** `doc/media-processing-rollout.md` documents a rollout plan for migrating fmcom-api from publishing `TranscodeMessage`/`PdfToImageMessage` to the unified `MediaProcessingMessage`. The shim handlers (`TranscodeHandlers`, `FileConversionHandlers`) are described as "scheduled for removal." Has fmcom-api been fully migrated? Are the legacy queues (`RNF_TRANSCODE_DESTINATION`, `RNF_PDF_TO_IMAGE_DESTINATION`) still receiving traffic, and has the 24-hour drain window passed?

7. **What is the exact relationship between `ScreenSlotSovDto` computed by RNF and the `SovRuleService` from `fm-common`?** `ScreenSlotSovServiceImpl` imports `SovRuleService` from `fm-common` but the main SOV computation uses `ElasticAdCampaignScreenSlot` data directly. Is `SovRuleService` providing the rule definitions/constants, the validation logic, or something else? Clarifying this boundary matters for understanding where SOV rule configuration lives vs. where it is enforced.

8. **Is there a rate limit or circuit breaker on the OutScraper API calls, and what is the cost model?** `OutScraperApiService` calls `https://api.outscraper.cloud` for organization data enrichment. The `OrganizationInfoUpdateJob` and `RecentlyActivatedHandlers` trigger these calls. OutScraper is a paid third-party API with per-request billing. There is no visible rate limiter or circuit breaker in the code. Under the `OrganizationInfoUpdateJob` sweeping a large number of organizations, this could generate significant API cost or trigger rate-limit errors silently.

9. **What is the blast radius of the `ElasticsearchLimitClient.requestQuotaIncreaseForHeavyJob()` call during `playlistDailyUpdate`?** The Elasticsearch throttle service (`ThrottlingServiceModule`) uses a token-bucket style limiter shared via Redis. `requestQuotaIncreaseForHeavyJob()` temporarily raises the quota for the daily generation sweep, then `releaseQuotaFromHeavyJob()` restores it. If the generation sweep throws an uncaught exception before the `finally` block, does the quota stay elevated indefinitely? And how does the quota increase affect concurrent reads/writes from other services (`fmcom-api`) sharing the same Elasticsearch cluster?

10. **What is the `prod-perf` deployment environment?** `bitbucket-pipelines.yml` defines a `build-push-deploy-prod-perf` custom pipeline and a corresponding `prod-perf-task-definition.json`. This deploys to service `reach-n-freq-perf` in the `production-vrtly-ecs-cluster`. Is this a dedicated performance-testing instance, a canary deployment, or a permanent parallel service for bulk backfill? The existence of a separate `prod-perf` ECS service with its own task definition suggests it may be used for large-scale re-transcode sweeps (`TriggerMode.REST_BULK`) without competing with live JMS-driven traffic — but this is not documented anywhere in the repository.
