---
title: "Tech Spike — fm-common (Internal Shared Library)"
last_updated: 2026-06-12
---

# Tech Spike: fm-common (Internal Shared Library)

## What This Library Does

`fm-common` is the internal shared Java library that acts as the single source of truth for all cross-service domain knowledge on the Vrtly platform. It is not a deployable service — it is a fat library JAR (`com.friendmedia:fm-common:8.9.1`) published to a private AWS CodeArtifact repository and consumed as a compile-time dependency by every backend service: `fmcom-api`, `fmcom-player-api`, `rnf` (the reach-and-frequency engine), and the `state` service.

The library owns the following platform-wide concerns:

**JMS contract layer.** All ActiveMQ queue and topic destination names live here as typed `JmsDestination<T>` implementations grouped in the `Destinations` interface. No service can publish or subscribe to a queue without importing this library. The `MessagingService` interface and `JmsModule` provide the publish/subscribe abstraction.

**Redis key namespaces.** All Redis key prefixes used by the telemetry and playback quality pipeline are defined in `TelemetryRedisKeys`. All player-facing Redis channel keys (screen playlists, recently-played state, plan/action queues) are defined in `RedisChannels` using the `RedisUtils.generateKey()` colon-delimited builder. There is no single Redis keyspace registry — keys are scattered across two classes.

**Elasticsearch index names.** All 40+ Elasticsearch index names and their `IndexCoordinates` instances are defined in `ElasticsearchIndex`. The class reads an `ES_PREFIX` environment variable at class-load time to namespace indices per environment (`dev_`, `qa_`, `alpha_`, `prod_` etc.). Each index has a corresponding `ElasticXxxModule` `@Configuration` class that registers the Spring Data Elasticsearch repository for that index.

**MySQL entity and repository modules.** Every JPA entity that is shared across services (Screen, Organization, Brand, Content, AdCampaign, SovRule, etc.) has its entity class and a `MySqlXxxModule` `@EntityScan`/`@EnableJpaRepositories` configuration class in `fm-common`. Importing services compose the exact set of entity modules they need via explicit `@Import`.

**Service interfaces and implementations.** Core business services — `SovRuleService`, `ContentQuarantineService`, `TelemetryService`, `LockService`, `PlaylistCurrentService`, `SalesforceNotificationService`, `ContentService`, `AuthService`, `CacheInvalidationService` — are declared as interfaces with full implementations here. Services opt in by importing the corresponding module.

**State service Feign clients.** The HTTP clients used to talk to the `state` service — `ScreenStateClient`, `InstanceStateClient`, `AuthServiceClient`, `BrokerStateClient` — are all Feign interfaces declared in `fm-common` and activated by importing `StateClientModule`.

**SOV rule engine.** The `SovRuleName` enum encodes the 3x3 matrix of custom-content × brand-count tiers with default percentage values; `SovRuleService` provides cache-backed per-screen SOV rule lookup.

**Auth module.** `AuthModule` / `AuthService` / `AuthServiceImpl` provide the shared token-based authentication logic (verify, refresh, upgrade, logout) that both `fmcom-api` and `fmcom-player-api` use without duplication.

**Elasticsearch throttle system.** `ThrottledElasticsearchTransport`, `ElasticsearchLimitClient`, `ElasticsearchThrottleProperties`, and the JMS-based coordinator protocol are all implemented in `fm-common`, making the throttle available to every service that imports `ElasticsearchThrottleConfig`.

**Telemetry pipeline.** `TelemetryModule`, `TelemetryService`, `TelemetryDeduplicationService`, `TelemetryBatchWriter`, and the daily-index `ElasticTelemetry` entity live here. The `TelemetryRedisKeys` class holds all Redis key prefixes used by telemetry detection rules.

The library does not own Spring Boot auto-configuration (no `spring.factories` / `AutoConfiguration.imports` file). All module activation is explicit: consumers must `@Import` each module. This is by design — it gives each service a precise, auditable set of capabilities without ambient classpath scanning.

---

## Tech Stack & Key Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| Spring Boot (parent) | 3.2.0 | BOM, managed versions; `spring-boot-starter-web`, `spring-boot-starter-data-jpa`, `spring-boot-starter-data-elasticsearch`, `spring-boot-starter-validation` |
| Java | 17 | Runtime and compile target |
| spring-boot-starter-security | Boot-managed (`provided`) | `AuthModule` — token-based auth filter and `AuthService`; `provided` so each service controls its own security config |
| spring-boot-starter-data-redis | Boot-managed (`provided`) | Redis key operations in `CacheInvalidationService`, `RedisService`, `PlaylistCurrentServiceImpl`; `provided` so services control their own Redis config |
| spring-boot-starter-activemq | Boot-managed (`provided`) | JMS publish/subscribe via `MessagingService`; `provided` so services wire their own broker connection |
| spring-cloud-starter-openfeign | Spring Cloud 2023.0.3 | `ScreenStateClient`, `InstanceStateClient`, `AuthServiceClient`, `BrokerStateClient` in `StateClientModule` |
| MySQL connector-j | Boot-managed (`runtime`) | JDBC driver for all `MySqlXxx` entity modules |
| Alibaba Fastjson | 1.2.83 | Legacy JSON serialization used in domain entity `cmsInfo()` / `adminInfo()` methods |
| Jackson Datatype JSR310 | Boot-managed | `LocalDateTime` / `LocalDate` serialization in Feign clients and DTOs |
| MapStruct | 1.5.5.Final (`provided`) | Compile-time DTO/entity mapper generation |
| Lombok | Boot-managed (`optional`) | Boilerplate reduction; annotation processor wired with `lombok-mapstruct-binding` 0.2.0 |
| AWS SDK v2 (s3) | 2.31.30 | `AwsService` — S3 object operations for CloudFront URL signing |
| aws-java-sdk-cloudfront (v1) | 1.12.671 | CloudFront signed URL / signed cookie generation in `AwsServiceImpl` |
| Google ZXing (core + javase) | 3.3.0 | QR code generation for content items |
| TwelveMonkeys ImageIO (jpeg, webp) | 3.7.0 | Extended image format support for server-side thumbnail generation |
| Apache Commons IO | 2.20.0 | File utility operations |
| Apache Commons Collections4 | 4.4 | Collection utilities |
| Apache Commons Codec | 1.15 | Base64 / hex encoding utilities |
| Apache Commons Lang3 | 3.19.0 | String and date utilities |
| ThreeTen Extra | 1.7.2 | Additional `java.time` types (e.g. `Interval`) |
| OpenCSV | 5.9 | CSV export of reports |
| Springfox Swagger 2 | 3.0.0 / 2.10.0 | Swagger annotations reused in shared controllers/DTOs |
| Checkstyle (plugin) | 3.6.0 / 12.3.1 | Enforced code style at `validate` phase; `failOnViolation=true`, `failsOnError=false` (violations are warnings that fail the build) |

---

## Domain Models / Shared Entities

### Core DTOs (in `model/dto/`)

| Class | Package | Description |
|---|---|---|
| `ScreenDto` | `model.dto` | Central screen transfer object. Carries all screen state fields: `id`, `name`, `mac`, `hardwareType` (`ScreenType`), `deviceType`, `deviceGroup`, `buildNumber`, `ipAddress`, `model`, `resolution`, `platform`, `osVersion`, `manufacturer`, `secret`, `dataId`, `lastDisplay`, `version`, `tvStatus`, `pinStatus`, `outputMode`, `activeSource`, `lastCecMessage`, `dateActivated`. Uses Lombok `@Builder`, `@FieldNameConstants`, mutable `_updates` map for partial-update protocol. Used by `ScreenStateClient`. |
| `ContentDto` | `model.dto` | Content item transfer object. Fields: `id`, `name`, `contentType`, `removed`, `expired`, `featured`, `src`, `size`, `duration`, `cover`, `subtitleUrl`, `qrCodeUrl`, `transcribeStatus`, `brandId`, `ticker`, `value` (list of `ContentPieceDto`), `scheduleStartDate/EndDate`, `scheduleStatus`, `transcodingStatus`, `playlistOnly`, `streamSrc`, `audio`, `socialNetworkPostId`, `source`. Implements `ContentTranscode`. |
| `PlaylistCurrentDto` | `model.dto` | Current playlist for a screen. Fields: `id`, `screenId`, `organizationId`, `date`, `timestamp`, `created`, `content` (`SortedSet<PlaylistEntryDto>`). Returned by `PlaylistCurrentService.getCurrentPlaylist()`. |
| `TelemetryDto` | `model.dto` | Telemetry event. Fields: `id`, `type`, `timestamp` (epoch ms), `receivedAt`, `datetime`, `received`, `screenId`, `mac`, `hardwareType`, `payload` (generic `Map<String, Object>`), `ext` (extension payload from Crashlytics/Sentry/Mux). `setTimestamp()` and `setReceivedAt()` keep `datetime` / `received` in sync. Implements `Comparable<TelemetryDto>` by timestamp. |
| `SovRuleDto` | `model.dto` | SOV rule transfer object for a screen. Used as response type by `SovRuleService`. |
| `ContentQuarantineDto` | `model.dto` | Quarantine record view. Used by `ContentQuarantineService.findAll()`. |
| `ConsultDto` | `model.dto` | Patient consultation session. Carries consult state, InfoPack associations, version statistics. |
| `CustomPlaylistDto` | `model.dto` | Custom playlist representation. |
| `PlaylistEntryDto` | `model.dto` | Single entry within a `PlaylistCurrentDto.content` sorted set. |
| `InfoPackDto` | `model.dto` | Patient education InfoPack. |
| `InfoPackBundleDto` | `model.dto` | InfoPack bundle grouping multiple InfoPacks. |
| `OrganizationDto` | `model.dto` | Organization transfer object (shared representation). |
| `ScreenConfigDto` | `model.dto` | Screen runtime configuration including features and subscription. |
| `ScreenUpdateDto` | `model.dto` | Payload for bulk screen update requests to `ScreenStateClient`. |
| `AuthTokenDto` | `model.dto` | Token pair returned by `AuthServiceClient` on login/refresh/verify. |
| `AuthRequestDto` | `model.dto` | Login credentials payload. |
| `AuthRefreshDto` | `model.dto` | Token refresh request. |
| `AuthVerifyDto` | `model.dto` | Token verify request. |
| `AuthUpgradeDto` | `model.dto` | Token upgrade request (adds extra auth context). |
| `LockDto` | `model.dto` | Distributed lock request: `LockType` and optional `targetId` (screen ID). |
| `TelemetryFilterDto` | `model.dto` | Filter parameters for telemetry queries (screenId, type, platform, contentId, time window). |
| `StripeCustomerDto` | `model.dto` | Stripe customer representation. |
| `StripeSubscriptionDto` | `model.dto` | Stripe subscription details. |
| `StripeInvoiceDto` | `model.dto` | Stripe invoice details. |
| `VideoDetailsDto` | `model.dto` | Video media detail including stream variants. |
| `VideoVariantDto` | `model.dto` | Individual ABR variant (resolution, URL). |
| `StreamVariantDetailsDto` | `model.dto` | HLS stream variant details. |
| `DashboardDto` | `model.dto` | Dashboard aggregates for admin UI. |
| `PlayCurrentDto` | `model.dto` | What a screen is currently playing (single item). |
| `ScreenOrganizationRoomDto` | `model.dto` | Projection: screen + organization + room. Used in `ScreenStateClient`. |
| `ScreenOrganizationAddressRoomDto` | `model.dto` | Extended projection: screen + org + address + room. |
| `ScreenPaidDeviceGroupDto` | `model.dto` | Projection: screen device group and paid status. |

### MySQL JPA Entities (in `model/mysql/`)

| Entity Class | Table | Description |
|---|---|---|
| `MySqlScreen` | `screen` | Screen device record. Fields: `id`, `name`, `mac`, `hardwareType` (`ScreenType`), `deviceType`, `deviceGroup`, `ScreenContentType`, `ScreenMode`, `ScreenSubscription`, `ScreenTvStatus`, `buildNumber`, `ipAddress`, `model`, `resolution`, `platform`, `osVersion`, `manufacturer`, `secret`, `dataId`, `lastDisplay`, `version`, `dateActivated`. Canonical screen record owned by state service; read by API and player via `ScreenStateClient`. |
| `MySqlAdCampaign` | `ad_campaign` | Ad campaign entity with SOV rules, status, screen slots, and content. |
| `MySqlSovRule` | `sov_rule` | Per-organization/screen SOV rule overrides. Referenced by `SovRuleService`. |
| `MySqlContent` / `MySqlContentPiece` | `content`, `content_piece` | Content library items and their media segments. |
| `MySqlInfoPack` / `MySqlInfoPackBundle` | `info_pack`, `info_pack_bundle` | Patient education material and bundle wrappers. |
| `MySqlConsult` | `consult` | Patient consultation session record. |
| `MySqlCustomPlaylist` / `MySqlCustomPlaylistSlot` | `custom_playlist`, `custom_playlist_slot` | Custom playlists with ordered slots. |
| `MySqlOrganization` | (implicit) | Provider / brand organization record. Relationship: Organization → Screens → Playlists. |
| `MySqlBrand` | `brand` | Brand entity with categories, social handles, CloudFront assets. |
| `MySqlUser` / `MySqlUserRole` / `MySqlUserPermission` / `MySqlUserOtp` / `MySqlUserTerm` | `user`, `user_role`, `user_permission`, `user_otp`, `user_term` | Auth-domain entities. |
| `MySqlStripeCustomer` / `MySqlStripeSubscription` / `MySqlStripeInvoice` / `MySqlStripePaymentIntent` / `MySqlStripePrice` / `MySqlStripeProduct` / `MySqlStripeFeature` | stripe tables | Stripe billing domain. |
| `MySqlOrder` / `MySqlOrderItem` | `order`, `order_item` | Hardware order domain (Shippo). |
| `MySqlLock` | `lock` | Distributed lock record used by `LockService`. |
| `MySqlPlaylist` / `MySqlPlaylistContent` / `MySqlScreenPlaylist` | playlist tables | Playlist content and screen assignments. |
| `MySqlRoom` / `MySqlLocation` | `room`, `location` | Physical room and location. |
| `MySqlWhiteLabel` | `white_label` | White-label branding instance. |
| `MySqlProviderSponsor` | `provider_sponsor` | Sponsor contract between brand and provider. |
| `MySqlOrganizationUser` | `organization_user` | Many-to-many user ↔ org join with permissions. |
| `MySqlOrganizationFeatures` | `organization_features` | Feature flags per organization. |
| `MySqlOrganizationState` | `organization_state` | Organization lifecycle state. |
| `MySqlSystemParam` | `system_param` | Key-value system parameter store. |
| `MySqlYoutubeDownloadLock` | `youtube_download_lock` | YouTube download pipeline lock state. |
| `MySqlContentQuarantine` | `content_quarantine` | Content quarantine records (type: SCREEN or ALL). |
| `MySqlDiagnosticsSharedItem` | `diagnostics_shared_item` | Diagnostics dashboard shared items. |
| `MySqlReportLogRecord` / `MySqlReportLogException` | report tables | Error reporting and exception logging. |
| `MySqlActivityRecord` | `activity_record` | Audit activity events. |
| `MySqlScreenBrand` | `screen_brand` | Screen ↔ brand assignment. |
| `MySqlScreenContent` | `screen_content` | Screen ↔ content association. |
| `MySqlOrganizationSubscribedBrand` | `organization_subscribed_brand` | Brand subscription per organization. |
| `MySqlPromoCode` | `promo_code` | Promotional codes. |
| `MySqlRegistryCode` | `registry_code` | Device activation registry codes. |
| `MySqlElasticsearchSaveFailure` | `elasticsearch_save_failure_record` | Records of ES write failures for retry. |

---

## JMS Destination Constants

All constants are defined as string values in `Destinations.Key` (inner interface). Each constant has a corresponding `JmsDestination<T>` implementation class and a typed instance in the `Destinations` interface. The type is either `QUEUE` (point-to-point, one consumer) or `BROADCAST` (topic, all consumers receive a copy).

| Constant Name | Value (queue/topic name) | Type | Publisher(s) | Subscriber(s) |
|---|---|---|---|---|
| `ALL_SYSTEM_PARAMS_CHANGED` | `all.system.params.changed` | BROADCAST | state service (when system params change) | fmcom-api, fmcom-player-api, rnf (any subscriber needing to refresh param cache) |
| `ALL_USER_ACCESS_CHANGED` | `all.user.access.changed` | BROADCAST | state service (on token revocation/upgrade) | fmcom-api, fmcom-player-api (cache invalidation) |
| `API_CONTENT_ADD` | `api.content.add` | QUEUE | fmcom-api (content upload → triggers screen content association) | fmcom-api (`ContentMessageHandlers`) |
| `API_CONTENT_QUARANTINE` | `api.content.quarantine` | QUEUE | fmcom-player-api / `ContentQuarantineService` (via telemetry detection) | fmcom-api (`ContentQuarantineHandlers`) |
| `API_CONSULT_EMAIL_SEND_DESTINATION` | `api.consult.email.send` | QUEUE | fmcom-api (consult flow trigger) | fmcom-api (`ConsultNotificationHandlers`) |
| `PLAYER_CONTENT_TRANSCODED` | `player.content.transcoded` | BROADCAST | rnf (after single content transcode completes) | fmcom-player-api (cache invalidation, screen playlist refresh) |
| `PLAYER_CONTENTS_TRANSCODED_BATCH` | `player.contents.transcoded.batch` | BROADCAST | rnf (after batch transcode) | fmcom-player-api |
| `PLAYER_HISTORY_LOAD` | `player.history.load` | BROADCAST | fmcom-api (trigger history pre-load) | fmcom-player-api |
| `PLAYER_ORGANIZATION_ACTIVITY` | `player.organization.activity` | BROADCAST | fmcom-api (organization activity events) | fmcom-player-api |
| `PLAYER_ORGANIZATION_CONTENT_UPDATED` | `player.organization.content.updated` | BROADCAST | fmcom-api (content library change) | fmcom-player-api |
| `PLAYER_ORGANIZATION_UPDATED` | `player.organization.updated` | BROADCAST | fmcom-api (organization settings change) | fmcom-player-api |
| `PLAYER_SCREEN_CONTENT_PENDING` | `player.screen.content.pending` | BROADCAST | fmcom-api (content added to screen, awaiting transcode) | fmcom-player-api |
| `PLAYER_SCREEN_CONTENT_UPDATED` | `player.screen.content.updated` | BROADCAST | fmcom-api / rnf (screen content ready) | fmcom-player-api |
| `PLAYER_SCREEN_QUALITY_CAP_NOTIFY` | `player.screen.quality.cap.notify` | BROADCAST | state service / `PlaybackQualityCapRule` (cap applied) | fmcom-player-api (serve downscaled assets) |
| `PLAYER_SCREEN_UPDATED` | `player.screen.updated` | BROADCAST | fmcom-api / state service (screen config change) | fmcom-player-api |
| `RNF_GENERATE` | `rnf.generate` | QUEUE | fmcom-api (trigger playlist generation) | rnf |
| `RNF_MEDIA_PROCESSING` | `rnf.media.processing` | QUEUE | fmcom-api (`MediaProcessingDispatcher`) | rnf (unified media processing entry) |
| `RNF_OPEN_HOURS_UPDATED` | `rnf.open.hours.updated` | QUEUE | fmcom-api (open hours saved) | rnf |
| `RNF_PDF_TO_IMAGE_DESTINATION` | `rnf.pdf.to.image` | QUEUE | fmcom-api (PDF upload) | rnf |
| `RNF_RECENTLY_ACTIVATED` | `rnf.organization.recently.activated` | QUEUE | fmcom-api (new organization activation) | rnf |
| `RNF_SALESFORCE_ORGANIZATION_UPDATED` | `rnf.salesforce.organization.updated` | QUEUE | fmcom-api (`SalesforceNotificationService.organization()`) | rnf (CRM sync) |
| `RNF_SALESFORCE_SCREEN_UPDATED` | `rnf.salesforce.screen.updated` | QUEUE | fmcom-api (`SalesforceNotificationService.screen()`) | rnf |
| `RNF_SALESFORCE_USER_UPDATED` | `rnf.salesforce.user.updated` | QUEUE | fmcom-api (`SalesforceNotificationService.user()`) | rnf |
| `RNF_TRANSCODE_DESTINATION` | `rnf.transcode` | QUEUE | fmcom-api (legacy per-operation transcode dispatch) | rnf |
| `YOUTUBE_DOWNLOAD_DESTINATION` | `youtube.download` | QUEUE | fmcom-api (YouTube content add) | youtube-downloader service |
| `YOUTUBE_UPDATE_URL_DESTINATION` | `youtube.url.update` | QUEUE | youtube-downloader service (URL ready) | fmcom-api (`YoutubeUpdateUrlHandlers`) |
| `ELASTICSEARCH_INSTANCE_REGISTERED` | `elasticsearch.instance.registered` | QUEUE | Any service with throttle enabled (on startup via `ElasticsearchLimitClient`) | state service (allocator) |
| `ELASTICSEARCH_INSTANCE_UNREGISTERED` | `elasticsearch.instance.unregistered` | QUEUE | Any service with throttle enabled (on shutdown) | state service |
| `ELASTICSEARCH_LIMITS_ALLOCATED` | `elasticsearch.limits.allocated` | BROADCAST | state service (allocator broadcasts new limits) | fmcom-api, fmcom-player-api, rnf (update `ThrottledElasticsearchTransport`) |
| `ELASTICSEARCH_QUOTA_REQUEST` | `elasticsearch.quota.request` | QUEUE | Any service (backlog / heavy-job start/end signal) | state service |
| `ELASTICSEARCH_PERFORMANCE_FAILURE` | `elasticsearch.performance.failure` | QUEUE | Any service (on ES 429/503/timeout) | state service (may decrease budget) |

---

## Redis Key Namespaces & Constants

There are two classes defining Redis key patterns and one interface defining channel/hash keys.

### `TelemetryRedisKeys` (`constant/TelemetryRedisKeys.java`) — telemetry / playback pipeline

| Constant | Pattern | Used By | Notes |
|---|---|---|---|
| `PLAYBACK_QUALITY_CAP_PREFIX` | `screen:playback:quality:cap:{screenId}` | fmcom-player-api (`PlaybackQualityCapRule`), fmcom-api diagnostics | 15-min TTL. Stored value is `MediaResolution.name()` (e.g. `"FHD_1080"`). Caps resolution served. |
| `GLOBAL_MAX_QUALITY_CAP_KEY` | `system:playback:quality:cap:max` | fmcom-player-api (`PlaybackQualityResolverServiceImpl`), fmcom-api diagnostics | Singleton key, no TTL. Fleet-wide resolution ceiling. |
| `BAD_MANIFEST_SCREENS_PREFIX` | `content:bad_manifest:screens:{contentId}` | fmcom-player-api (`ContentManifestIncompatibleDetectionRule`) | ZSET. Score = epoch ms. Sliding 7-day window of screens that emitted codec errors. |
| `BAD_MANIFEST_HW_TYPES_PREFIX` | `content:bad_manifest:hwtypes:{contentId}` | fmcom-player-api | Same shape as above, keyed on `hardwareType.name()`. Multi-vendor signal required before quarantine. |
| `BAD_MANIFEST_QUARANTINED_MARKER_PREFIX` | `content:bad_manifest:quarantined:{contentId}` | fmcom-player-api (`ContentManifestIncompatibleDetectionRule`) | SETNX with 30-day TTL. Hot-path dedup to skip DB + JMS if already quarantined. |
| `MITIGATION_LAST_FETCH_PREFIX` | `screen:mitigation:lastFetchAt:{screenId}` | fmcom-player-api (mitigation cooldown) | Epoch-ms timestamp. Written by player-api content-fetch interceptor. |
| `MITIGATION_STATE_PREFIX` | `screen:mitigation:state:{source}:{screenId}` | fmcom-player-api | Small map: fingerprint + emit timestamp. Used by `MitigationTelemetryEmitter.shouldEmit`. |
| `DEDUP_PREFIX` | `telemetry:dedup:{fingerprint}` | `TelemetryDeduplicationService` | Configurable TTL. Prevents duplicate telemetry events. Written by both api and player-api. |
| `PLAYBACK_ESCALATION_PREFIX` | `screen:content:escalation:{screenId}:{contentId}` | fmcom-player-api (`PlaybackEscalationServiceImpl`) | Permanent. Escalation stage machine (full ABR → HLS off → src downscale → 540p → quarantine). |
| `PLAYBACK_ESCALATION_INDEX_PREFIX` | `screen:content:escalation:index:{screenId}` | fmcom-player-api | Redis Set. Reverse index of contentIds with active escalation per screen. |
| `ROKU_CERT_OVERRIDE_PREFIX` | `roku:cert:override:{mac}` | fmcom-player-api (`RokuCertOverrideServiceImpl`), fmcom-api diagnostics | 3-day TTL. Funnels pre-release Roku devices to demo account during certification. |

### `CacheConstant` (`enums/CacheConstant.java`) — player-api cache

| Constant | Value | Used By | Notes |
|---|---|---|---|
| `Key.GET_DATA` | `player:getData:v2` | fmcom-player-api (screen data endpoint cache) | Spring Cache key. Versioned `v2` suffix. |
| `Query.SAVE_SCREEN_HOURLY_WIFI_STATUS_SCRIPT` | Lua: `redis.call('zadd',KEYS[1],'nx',ARGV[1],ARGV[2])` | fmcom-player-api | Lua script for idempotent ZADD for hourly wifi status log. |

### `RedisChannels` (`enums/RedisChannels.java`) — player-api Redis hash and queue keys

All keys generated by `RedisUtils.generateKey()` using `:` as delimiter.

| Constant | Generated Key | Used By | Notes |
|---|---|---|---|
| `ACTIVITY_RECORD_HASH` | `activity:record:hash` | fmcom-player-api | Hash for activity record dedup. |
| `CLOUD_FRONT_CONTENT_URL_HASH` | `s3:content` | fmcom-player-api | CloudFront signed URL cache for content. |
| `CLOUD_FRONT_PHOTO_URL_HASH` | `s3:photo` | fmcom-player-api | CloudFront signed URL cache for photos. |
| `BRAND_CF_LOGO_HASH` | `brand:cf:url` | fmcom-player-api | CloudFront signed URL cache for brand logos. |
| `CURRENTLY_PLAYED_CONTENT_OF_SCREEN_HASH` | `screen:current:play:content` | fmcom-player-api | Current playing content per screen. |
| `RECENTLY_PLAYED_CONTENT_OF_SCREEN_LIST` | `screen:recently:play:content` | fmcom-player-api | Recently played content per screen (list). |
| `RECENTLY_PLAYED_BRAND_CONTENT_OF_SCREEN_LIST` | `screen:recently:play:brand:content` | fmcom-player-api | Recently played brand content per screen. |
| `RECENTLY_PLAYED_CONTENT_OF_BRAND_SORTED_SET` | `brand:recently:play:content` | fmcom-player-api | Sorted set of recently played content per brand. |
| `RECENTLY_PLAYED_CUSTOM_CONTENT_OF_SCREEN_LIST` | `screen:recently:play:custom:content` | fmcom-player-api | Recently played custom content per screen. |
| `RECENTLY_PLAYED_PLAYLIST_LIST` | `screen:recently:play:list` | fmcom-player-api | Recently played playlists per screen. |
| `CHANGED_SCREEN_PLAYLIST_CONTENT_SORTED_SET` | `changed:screen:playlist:content:sorted_set` | fmcom-player-api | Sorted set of screens with changed playlist content. |
| `CHANGED_SCREEN_ORGANIZATION_SORTED_SET` | `changed:screen:organization:sorted_set` | fmcom-player-api | Sorted set of screens with changed organization. |
| `UPDATED_SCREENS_QUEUE` | `updated_screens:queue` | fmcom-player-api | Queue of screen IDs pending update processing. |
| `UPDATED_USERS_QUEUE` | `updated_users:queue` | fmcom-player-api | Queue of user IDs pending update processing. |
| `UPDATED_ORGANIZATIONS_QUEUE` | `updated_orgs:queue` | fmcom-player-api | Queue of org IDs pending update processing. |
| `ORG_ACTIVITY_QUEUE` | `org:activity:queue` | fmcom-player-api | Queue of organization activity events. |
| `SCREEN_HOURLY_WIFI_STATUS_KEY` | `screen:hourly:wifi:status` | fmcom-player-api | Per-screen hourly wifi status log ZSET. |
| `SCREEN_PREPARE_DATA_LIST` | `screen:prepare:data` | fmcom-player-api | Screen data preparation queue. |
| `SCREEN_PLAYLIST_LIST` | `screen:playlist` | fmcom-player-api | Current playlist data per screen. |
| `SCREEN_PLAYLIST_POD_LIST` | `screen:playlist:pod` | fmcom-player-api | Pod-based playlist data per screen. |
| `SCREEN_PREVIEW_TIME_HASH` | `screen:preview:time` | fmcom-player-api | Preview time tracking per screen. |
| `SCREEN_SELECTED_CUSTOM_PLAYLIST` | `screen:selected:custom:playlist` | fmcom-player-api | Active custom playlist selection per screen. |
| `SCREEN_SELECTED_PLAYLIST` | `screen:selected:playlist` | fmcom-player-api | Active playlist selection per screen. |
| `SCREEN_PLAN` | `screen:plan` | fmcom-player-api | Screen plan data (SOV schedule). |
| `SCREEN_PLAN_ACTION` | `screen:plan:action` | fmcom-player-api | Pending plan action events per screen. |
| `PHONE_NUMBER_LOCK` | `phone:number:lock` | fmcom-api / fmcom-player-api | OTP send rate-limiting lock by phone number. |

**Redis isolation assessment.** There is no explicit keyspace prefix per service. `TelemetryRedisKeys` uses namespace prefixes (`screen:`, `content:`, `system:`, `telemetry:`, `roku:`) that are intentionally designed for cross-service use. `RedisChannels` uses simpler prefixes oriented toward player-api. The `CacheConstant.Key.GET_DATA` key (`player:getData:v2`) uses a `player:` prefix that naturally scopes it. No systematic partition exists — collision risk is managed by discipline in naming conventions, not by any technical keyspace isolation mechanism (no Redis DB index separation, no Redisson namespace config visible in `fm-common`). Both `fmcom-api` and `fmcom-player-api` share the same Redis instance and write to keys from `RedisChannels` and `TelemetryRedisKeys`.

---

## Shared Service Interfaces

| Interface | Key Methods | What It Calls / Mechanism | Notes |
|---|---|---|---|
| `ScreenStateClient` | `getById(Long)`, `getByMac(String)`, `create(ScreenDto)`, `update(Long, boolean, Map)`, `update(List<ScreenUpdateDto>)`, `save(ScreenDto)`, `findAllByIdIn(Collection<Long>)`, `findAllByOrganizationIdAndEnabledIsTrue(Long)`, `search(Long, String, Pageable)`, `findActiveScreenAt(...)`, `countByOrganizationIds(...)`, `findAllByLastDisplayGreaterThan(...)`, `deleteById(Long)`, `getScreenConfig(Long)`, `filterIdsByContentType(...)`, and ~35 additional query methods | HTTP (Feign) → `${service.discover.state}/screen/**` | The most-called cross-service interface. Full CRUD + analytics queries for screens. Custom `ScreenStateClientConfig` ensures null map values are preserved in update payloads (so "set field to null" is distinguishable from "omit field"). `@EnableFeignClients` in `StateClientModule`. |
| `InstanceStateClient` | `ping()` | HTTP (Feign) → `${service.discover.state}/ping` | Health check / liveness probe for the state service. |
| `AuthServiceClient` | `authorize(AuthRequestDto)`, `verify(AuthVerifyDto)`, `refresh(AuthRefreshDto)`, `upgrade(AuthUpgradeDto)`, `logout(AuthVerifyDto)`, `logoutAll(AuthRefreshDto)` | HTTP (Feign) → `${service.discover.state}/auth/**` | Token lifecycle operations delegated to state service. Used by `AuthServiceImpl` in the shared `AuthModule`. |
| `BrokerStateClient` | `publish(String key, JmsType, String message)`, `consume(String key, JmsType, String clientId, int count)`, `disconnect(String clientId)` | HTTP (Feign) → `${service.discover.state}/broker/**` | State-service-hosted message broker proxy (fallback / alternative to direct ActiveMQ for BROADCAST topics). Introduced to support services that cannot connect directly to Amazon MQ. |
| `AuthService` | `createUserDetails(AuthRequestDto)`, `verifyUserAccess(String)`, `refreshUserAccess(AuthRefreshDto)`, `logout(String)`, `upgrade(AuthUpgradeDto)`, `invalidate(String)`, `logoutAll(AuthRefreshDto)` | Delegates to `AuthServiceClient` (state service); maintains a local in-memory cache of verified tokens | Shared between fmcom-api and fmcom-player-api. `invalidate()` evicts local cache only, does not call state service. |
| `TelemetryService` | `save(Collection<TelemetryDto>)`, `cleanup()`, `findAllByScreenIdAndTimestampBetween(Long, Long, Long)`, `findAllFiltered(TelemetryFilterDto, Pageable)`, `findAllByCategories(filter, categories, pageable)`, `countByType(filter)`, `countByEvent(filter)`, `countByPlatform(filter)`, `countByPayloadField(filter, field, value)`, `countByCategories(filter, categories)`, `countIssuesByScreen(filter, categories, size)`, `countTelemetryByScreen(filter, size)`, `countIssuesByScreenAndCategory(...)`, `countIssuesByContentAndCategory(...)`, `timeseriesCounts(fromMs, toMs, intervalMs, platform, screenIds, categories)` | Elasticsearch (`ElasticTelemetry` daily-index via `TelemetryDailyIndexWriter`) + optional Redis dedup via `TelemetryDeduplicationService` | Only `TelemetryModule` activates this. Used by fmcom-player-api (ingest) and fmcom-api (diagnostics). Supports batch writes via `TelemetryBatchWriter` (`telemetry.batch.enabled=true`). |
| `ContentQuarantineService` | `findAll(filter, pageable)`, `place(ContentQuarantinePlaceDto)`, `restore(Long)`, `restoreAllByContentId(Long)`, `restoreAllByIds(List<Long>)`, `restoreAllByScreenId(Long)`, `findAllGrouped(filter, groupBy, pageable)`, `getQuarantinedContentSummary(orgId, contentIds)`, `getQuarantinedContentIdsForScreen(screenId, contentIds)` | MySQL (`MySqlContentQuarantine`), JMS (`API_CONTENT_QUARANTINE` publish on place/restore to trigger api regeneration) | Activated by `ContentQuarantineModule`. Used by fmcom-player-api telemetry rules and by fmcom-api diagnostics dashboard. |
| `SovRuleService` | `refreshCache()`, `findPerScreenByOrganizationId(Long)`, `findByScreenId(Long)`, `findByScreenIdIn(Collection<Long>)` | MySQL (`MySqlSovRule`) with an in-memory cache | Activated by `SovRuleServiceModule`. Used by rnf (playlist SOV enforcement) and fmcom-api (SOV rule admin). |
| `LockService` | `execute(LockDto, Runnable)`, `executeForOne(LockDto, Callable)`, `executeForAll(LockType, Callable)` | MySQL (`MySqlLock`) via `MySqlLockModule` — DB-row locking | Activated by `LockServiceModule`. Used by fmcom-player-api for playlist generation serialization per screen. `LockType` enum controls lock granularity. |
| `SalesforceNotificationService` | `organization(Long)`, `screen(Long)`, `user(Long)` | JMS (`RNF_SALESFORCE_ORGANIZATION_UPDATED`, `RNF_SALESFORCE_SCREEN_UPDATED`, `RNF_SALESFORCE_USER_UPDATED`) | Activated by `SalesforceNotificationServiceModule`. Used by fmcom-api to trigger Salesforce CRM sync via rnf. |
| `PlaylistCurrentService` | `getCurrentPlaylist(Long screenId, LocalDateTime from, Integer length)` | Elasticsearch (`ElasticPlaylistSchedule`), constants: `LOOKUP_MINUTES_BEFORE_REQUEST = 5`, `DEFAULT_REQUEST_SIZE = 30` | Activated by `PlaylistCurrentServiceModule`. Core method used by fmcom-player-api to retrieve the scheduled playlist for a screen at a given time. |
| `ContentService` | Full CRUD + transcode status management for content items | MySQL (`MySqlContent`, `MySqlContentPiece`) + business logic for transcode lifecycle | Activated by `ContentServiceModule`. Shared between fmcom-api (write) and fmcom-player-api (read). |
| `CacheInvalidationService` | `invalidate(...)` | Redis / Spring Cache | Activated by `CacheInvalidationServiceModule`. Used to evict player-api caches when content or organization state changes. |
| `MessagingService` | `send(JmsDestination, T)`, `subscribe(JmsDestination, Consumer)`, `unsubscribe(JmsDestination)` | ActiveMQ (Amazon MQ) via Spring JMS or via `BrokerStateClient` (depending on `JmsMode`: `MQ` vs `STATE`) | `JmsModule` activates this. Central JMS send/subscribe abstraction used by all services. Contains a `ReentrantReadWriteLock` for maintenance mode. |
| `NoticeService` | `notifyScreenChangedOrganization(Long oldOrgId, Long newOrgId)` | Internal event propagation | Activated by `NoticeModule`. Used when a screen is reassigned between organizations. |
| `ScreenFilterService` | `findScreensByStatusAmongProjections(projections, activityTypes)`, additional filter methods | MySQL projections + status logic using `ScreenActivityType` | Activated by `ScreenFilterModule`. Used by rnf and fmcom-api for screen selection during playlist/SOV generation. |
| `CriticalIssueService` | `reportCriticalIssue(String code, String message, Map context)` | Default implementation: log-only; other implementations may send alerts (Slack, PagerDuty, etc.) | `CriticalIssueModule`. Used by ES throttle system for `ES_CLUSTER_NO_SPACE` and similar alerts. |

---

## Module Inventory

### MySQL Entity Modules

| Module Class | Type | Purpose |
|---|---|---|
| `MySqlScreenModule` | `@EntityScan` | Screen entity + Organization + ScreenBrand |
| `MySqlAdCampaignModule` | `@EntityScan` + `@EnableJpaRepositories` | Ad campaign entity and repository |
| `MySqlAdCampaignContentModule` | `@EntityScan` + `@EnableJpaRepositories` | Ad campaign ↔ content join |
| `MySqlAdCampaignScreenModule` | `@EntityScan` + `@EnableJpaRepositories` | Ad campaign ↔ screen join |
| `MySqlAdCampaignDeletionReportModule` | `@EntityScan` + `@EnableJpaRepositories` | Deletion audit trail |
| `MySqlBrandModule` | `@EntityScan` + `@EnableJpaRepositories` | Brand entity |
| `MySqlBrandCategoryModule` | `@EntityScan` + `@EnableJpaRepositories` | Brand primary/secondary categories |
| `MySqlBrandRankingModule` | `@EntityScan` + `@EnableJpaRepositories` | Brand ranking scores |
| `MySqlConsultModule` | `@EntityScan` + `@EnableJpaRepositories` | Consult session entity |
| `MySqlContentModule` | `@EntityScan` + `@EnableJpaRepositories` | Content library entity |
| `MySqlContentPieceModule` | `@EntityScan` + `@EnableJpaRepositories` | Content media segments |
| `MySqlContentQuarantineModule` | `@EntityScan` + `@EnableJpaRepositories` | Content quarantine records |
| `MySqlCustomPlaylistModule` | `@EntityScan` + `@EnableJpaRepositories` | Custom playlist |
| `MySqlCustomPlaylistScreenModule` | `@EntityScan` + `@EnableJpaRepositories` | Custom playlist ↔ screen assignment |
| `MySqlCustomPlaylistSlotModule` | `@EntityScan` + `@EnableJpaRepositories` | Ordered custom playlist slots |
| `MySqlDashboardModule` | `@EntityScan` + `@EnableJpaRepositories` | Dashboard aggregates |
| `MySqlDiagnosticsSharedItemModule` | `@EntityScan` + `@EnableJpaRepositories` | Diagnostics dashboard shared items |
| `MySqlDsOrganizationModule` | `@EntityScan` + `@EnableJpaRepositories` | DS-specific organization fields |
| `MySqlElasticsearchSaveFailureModule` | `@EntityScan` + `@EnableJpaRepositories` | ES write failure retry log |
| `MySqlInfoPackModule` | `@EntityScan` + `@EnableJpaRepositories` | InfoPack patient education content |
| `MySqlInfoPackBundleModule` | `@EntityScan` + `@EnableJpaRepositories` | InfoPack bundle |
| `MySqlInfoPackEventLogModule` | `@EntityScan` + `@EnableJpaRepositories` | InfoPack engagement event log |
| `MySqlLibraryModule` | `@EntityScan` + `@EnableJpaRepositories` | Content library grouping |
| `MySqlLocationModule` | `@EntityScan` + `@EnableJpaRepositories` | Physical location |
| `MySqlLockModule` | `@EntityScan` + `@EnableJpaRepositories` | Distributed lock record |
| `MySqlMailChimpEmailLogModule` | `@EntityScan` + `@EnableJpaRepositories` | MailChimp email delivery log |
| `MySqlMailChimpUserInteractionModule` | `@EntityScan` + `@EnableJpaRepositories` | MailChimp user interaction events |
| `MySqlNetworkModule` | `@EntityScan` + `@EnableJpaRepositories` | Network configuration per device |
| `MySqlOrderModule` / `MySqlOrderItemModule` | `@EntityScan` + `@EnableJpaRepositories` | Hardware order + line items |
| `MySqlOrganizationModule` | `@EntityScan` + `@EnableJpaRepositories` | Core organization entity |
| `MySqlOrganizationAddressModule` | `@EntityScan` + `@EnableJpaRepositories` | Organization address |
| `MySqlOrganizationContactModule` | `@EntityScan` + `@EnableJpaRepositories` | Organization contact info |
| `MySqlOrganizationExcludedBrandModule` | `@EntityScan` + `@EnableJpaRepositories` | Brands excluded per org |
| `MySqlOrganizationFeaturesModule` | `@EntityScan` + `@EnableJpaRepositories` | Per-org feature flags |
| `MySqlOrganizationGoogleMapsModule` | `@EntityScan` + `@EnableJpaRepositories` | Geocoding cache per org |
| `MySqlOrganizationOnboardingModule` | `@EntityScan` + `@EnableJpaRepositories` | Onboarding state machine |
| `MySqlOrganizationPromotedContentModule` | `@EntityScan` + `@EnableJpaRepositories` | Promoted content per org |
| `MySqlOrganizationScreenOptionModule` | `@EntityScan` + `@EnableJpaRepositories` | Screen display options per org |
| `MySqlOrganizationSpecialtyModule` | `@EntityScan` + `@EnableJpaRepositories` | Medical specialty tags per org |
| `MySqlOrganizationStateModule` | `@EntityScan` + `@EnableJpaRepositories` | Organization lifecycle state |
| `MySqlOrganizationSubscribedBrandModule` | `@EntityScan` + `@EnableJpaRepositories` | Brand subscriptions per org |
| `MySqlOrganizationUserModule` | `@EntityScan` + `@EnableJpaRepositories` | User ↔ org many-to-many |
| `MySqlOrganizationUserLoginModule` | `@EntityScan` + `@EnableJpaRepositories` | User login history |
| `MySqlOrganizationOpenHoursModule` | `@EntityScan` + `@EnableJpaRepositories` | Organization open hours |
| `MySqlPlaylistModule` / `MySqlPlaylistContentModule` | `@EntityScan` + `@EnableJpaRepositories` | Playlist and playlist content entries |
| `MySqlScreenBrandModule` | `@EntityScan` + `@EnableJpaRepositories` | Screen ↔ brand assignment |
| `MySqlScreenContentModule` | `@EntityScan` + `@EnableJpaRepositories` | Screen ↔ content association |
| `MySqlScreenPlaylistModule` | `@EntityScan` + `@EnableJpaRepositories` | Screen ↔ playlist assignment |
| `MySqlScreenSettingsModule` | `@EntityScan` + `@EnableJpaRepositories` | Per-screen display settings |
| `MySqlScreenStripeSubscriptionModule` | `@EntityScan` + `@EnableJpaRepositories` | Stripe subscription per screen |
| `MySqlScreenTrackModule` | `@EntityScan` + `@EnableJpaRepositories` | Screen tracking events |
| `MySqlScreenVersionModule` | `@EntityScan` + `@EnableJpaRepositories` | Screen firmware version history |
| `MySqlSocialNetworkAccountModule` | `@EntityScan` + `@EnableJpaRepositories` | Social network OAuth accounts |
| `MySqlSocialNetworkSelectedContentModule` | `@EntityScan` + `@EnableJpaRepositories` | Curated social content selections |
| `MySqlSovRuleModule` | `@EntityScan` + `@EnableJpaRepositories` | SOV rule overrides per screen/org |
| `MySqlSpecialtyBrandCategoryModule` | `@EntityScan` + `@EnableJpaRepositories` | Specialty ↔ brand category mapping |
| `MySqlStripeCustomerModule` | `@EntityScan` + `@EnableJpaRepositories` | Stripe customer records |
| `MySqlStripeFeatureModule` | `@EntityScan` + `@EnableJpaRepositories` | Stripe feature flags |
| `MySqlStripeInvoiceModule` | `@EntityScan` + `@EnableJpaRepositories` | Stripe invoice records |
| `MySqlStripePaymentIntentModule` | `@EntityScan` + `@EnableJpaRepositories` | Stripe payment intent records |
| `MySqlStripePriceModule` / `MySqlStripeProductModule` | `@EntityScan` + `@EnableJpaRepositories` | Stripe price and product catalog |
| `MySqlStripeSubscriptionModule` | `@EntityScan` + `@EnableJpaRepositories` | Stripe subscription state |
| `MySqlSubscriptionTierDefaultsModule` | `@EntityScan` + `@EnableJpaRepositories` | Default settings per subscription tier |
| `MySqlSystemParamModule` | `@EntityScan` + `@EnableJpaRepositories` | System-wide key-value parameters |
| `MySqlUserModule` | `@EntityScan` + `@EnableJpaRepositories` | User auth entity |
| `MySqlUserOtpModule` | `@EntityScan` + `@EnableJpaRepositories` | OTP codes for patient SMS auth |
| `MySqlUserPermissionModule` | `@EntityScan` + `@EnableJpaRepositories` | Per-user permission overrides |
| `MySqlUserRoleModule` | `@EntityScan` + `@EnableJpaRepositories` | User roles |
| `MySqlUserTermModule` | `@EntityScan` + `@EnableJpaRepositories` | User-agreed terms records |
| `MySqlWhiteLabelModule` | `@EntityScan` + `@EnableJpaRepositories` | White-label branding configs |
| `MySqlYoutubeDownloadLockModule` | `@EntityScan` + `@EnableJpaRepositories` | YouTube download pipeline lock |
| `MySqlPromoCodeModule` | `@EntityScan` + `@EnableJpaRepositories` | Promotional codes |
| `MySqlRegistryCodeModule` | `@EntityScan` + `@EnableJpaRepositories` | Device activation codes |
| `MySqlReportLogRecordModule` / `MySqlReportLogExceptionModule` | `@EntityScan` + `@EnableJpaRepositories` | Error and exception reporting logs |
| `MySqlRoleModule` | `@EntityScan` + `@EnableJpaRepositories` | Role definitions |
| `MySqlRoomModule` | `@EntityScan` + `@EnableJpaRepositories` | Physical room entity |
| `MySqlActivityRecordModule` | `@EntityScan` + `@EnableJpaRepositories` | Audit activity records |

### Elasticsearch Modules (37 total)

| Module Class | Index (from `ElasticsearchIndex`) | Purpose |
|---|---|---|
| `ElasticAdCampaignScreenSlotModule` | `{prefix}ad_campaign_screen_slot` | Ad campaign screen slot records including `ElasticSovRule` embedded objects |
| `ElasticAuditModule` | `{prefix}audit` | CUD audit trail; includes `AuditListener` JPA entity listener |
| `ElasticBrandModule` | `{prefix}brand` | Brand analytics data |
| `ElasticBrokerMessagesModule` | `{prefix}broker_messages` | Message broker routing events (state service) |
| `ElasticCampaignPlayedContentRecordModule` | `{prefix}campaign_played_content_record` | Ad campaign played content records |
| `ElasticContentModule` | `{prefix}content` | Content library analytics |
| `ElasticContentPlayedRecordModule` | `{prefix}content_played_record` | Per-content play records |
| `ElasticHfOrganicImpressionModule` | `{prefix}hf_organic_impression` | High-frequency organic impression events |
| `ElasticBrandImpressionReportModule` | `{prefix}impression_brand_report` | Brand impression aggregate reports |
| `ElasticImpressionReportModule` | `{prefix}impression_report` | Ad impression reports |
| `ElasticInfoPackStatisticsModule` | `{prefix}info_pack_statistics` | InfoPack view statistics |
| `ElasticInfoPackTokenModule` | `{prefix}info_pack_token` | InfoPack patient session tokens |
| `ElasticMgmtModule` | (cluster management) | ES cluster management (health check, node info for throttle system); activated by `TelemetryModule` |
| `ElasticOrderModule` | `{prefix}order` | Hardware order analytics |
| `ElasticOrganizationStateChangeLogModule` | `{prefix}organization_state_change_log` | Organization state transition log |
| `ElasticOrganizationStateLogModule` | `{prefix}organization_state_log` | Organization state snapshot log |
| `ElasticOrganizationUserLoginModule` | `{prefix}organization_user_login` | User login events |
| `ElasticPlayCurrentModule` | `{prefix}play_current` | What each screen is currently playing |
| `ElasticPlaybackReportModule` | `{prefix}playback_report` | Playback reports including SOV drift (`ElasticPlaybackSovDrift`) |
| `ElasticPlayedContentReportModule` | `{prefix}played_content_report_{yyyy_MM}` | Monthly partitioned played content reports |
| `ElasticPlaylistScheduleModule` | `{prefix}playlist_schedule` | Playlist schedule data used by `PlaylistCurrentService` |
| `ElasticProofOfPlayReportModule` | `{prefix}proof_of_play_report` | Proof-of-play brand advertising reports |
| `ElasticProviderScreenOnLogModule` | `{prefix}provider_screen_on_log` | Provider screen-on time events |
| `ElasticReportedIssueModule` | `{prefix}reported_issue` | User-reported issues |
| `ElasticScreenConnectionStatusModule` | `{prefix}screen_connection_status_log` | Screen online/offline connection events |
| `ElasticScreenEventReportLogModule` | `{prefix}screen_event_report_log` | Screen event reporting log |
| `ElasticScreenHourlyTvStatusReportLogModule` | `{prefix}screen_hourly_tv_status_report_log` | TV power status per hour per screen |
| `ElasticScreenHourlyWifiStatusLogModule` | `{prefix}screen_hourly_wifi_status_log` | Wifi signal strength log per hour |
| `ElasticScreenLastActivityModule` | `{prefix}screen_last_activity` | Last activity timestamp per screen |
| `ElasticScreenLastActivityReportModule` | `{prefix}screen_last_activity_report` | Screen activity report aggregates |
| `ElasticScreenStateLogModule` | `{prefix}screen_state_log` | Screen state snapshot log |
| `ElasticScreenStatusGlobalReportModule` | `{prefix}screen_status_global_report` | Fleet-wide screen status reports |
| `ElasticScreenStatusReportModule` | `{prefix}screen_status_report` | Per-screen status reports |
| `ElasticSocialNetworkContentModule` | `{prefix}social_network_content` | Social network content analytics |
| `ElasticSovRuleBrandReportModule` | `{prefix}sov_rule_brand_report` | SOV rule performance per brand |
| `ElasticSovRuleReportModule` | `{prefix}sov_rule_report` | SOV rule compliance reports |
| `ElasticThrottleStatsModule` | `{prefix}es_throttle_stats` | ES throttle statistics (hourly, per service) |
| *(Telemetry — no Module.java)* | `{prefix}telemetry-{yyyy.MM.dd}` | Daily-partitioned telemetry events; activated via `TelemetryModule`; uses `TelemetryIndexTemplateInitializer` |
| *(ScreenEvent — no Module.java)* | `{prefix}screen_event` | Screen lifecycle events; `ElasticScreenEventModule` via `ScreenEventModule` |

### Cross-Cutting Service Modules

| Module Class | Type | Purpose |
|---|---|---|
| `AuthModule` | `@ComponentScan` | Token auth service (`AuthService`, `AuthServiceImpl`, `AuthUserDetailsProvider`). Used by both fmcom-api and fmcom-player-api. |
| `StateClientModule` | `@Configuration` + `@EnableFeignClients` | Activates all four Feign clients: `ScreenStateClient`, `InstanceStateClient`, `AuthServiceClient`, `BrokerStateClient`. |
| `JmsModule` | `@ComponentScan` | Messaging infrastructure: `MessagingService` implementation, `JmsConfig`, `DestinationResolverImpl`, maintenance mode properties. |
| `LockServiceModule` | `@ComponentScan` + `@Import(MySqlLockModule)` | `LockService` — DB-backed distributed lock. |
| `ThrottlingServiceModule` | `@ComponentScan` | Elasticsearch throttle beans: `ThrottledElasticsearchTransport`, `ElasticsearchLimitClient`. Used by all services that access ES. |
| `SalesforceNotificationServiceModule` | `@ComponentScan` | `SalesforceNotificationService` — JMS-based CRM sync notifications. |
| `SovRuleServiceModule` | `@ComponentScan` + MySQL import | `SovRuleService` — cached SOV rule lookup per screen. |
| `ContentQuarantineModule` | `@ComponentScan` + MySQL import | `ContentQuarantineService` — quarantine lifecycle management. |
| `ContentServiceModule` | `@ComponentScan` | `ContentService` — shared content CRUD and transcode status management. |
| `TelemetryModule` | `@ComponentScan` + `@Import` + `@EnableElasticsearchRepositories` | `TelemetryService`, `TelemetryDeduplicationService`, `TelemetryBatchWriter` (conditional), `ElasticMgmtModule`. |
| `PlaylistCurrentServiceModule` | `@ComponentScan` | `PlaylistCurrentService` — current playlist fetch from ES. |
| `CacheInvalidationServiceModule` | `@ComponentScan` | `CacheInvalidationService` — Redis cache eviction. |
| `RedisServiceModule` | `@ComponentScan` | `RedisService` — sorted set addIfAbsent operations. |
| `ActivityRecordModule` | `@ComponentScan` | `ActivityRecordService` — audit activity logging. |
| `ElasticAuditServiceModule` | `@ComponentScan` | `ElasticAuditService` + `AuditListener` — automatic CUD audit trail to ES. |
| `AwsServiceModule` | `@ComponentScan` | `AwsService` — S3 and CloudFront operations. |
| `CryptoServiceModule` | `@ComponentScan` | `CryptoService` — HMAC/AES encryption utilities. |
| `NoticeModule` | `@ComponentScan` | `NoticeService` — screen-organization reassignment events. |
| `ScreenFilterModule` | `@ComponentScan` | `ScreenFilterService` — screen status filtering. |
| `ScreenEventModule` | `@ComponentScan` | `ScreenEventService` — screen lifecycle event recording to ES. |
| `OrganizationFeaturesModule` | `@ComponentScan` + MySQL import | Organization feature flag access. |
| `OrganizationUserLoginServiceModule` | `@ComponentScan` | Login event recording. |
| `StatisticsServiceModule` | `@ComponentScan` | Statistics aggregation service. |
| `SystemParamServiceModule` | `@ComponentScan` | System parameter read/write via `MySqlSystemParam`. |
| `TranscodingModule` | `@ComponentScan` | Shared transcoding status enum and properties. |
| `DailyPlaylistModule` | `@ComponentScan` | Daily playlist generation support. |
| `LongPollTaskServiceModule` | `@ComponentScan` | Long-poll task executor service. |
| `CriticalIssueModule` | `@ComponentScan` | `CriticalIssueService` — operator alert interface. |
| `SalesforceModule` (mapper) | `@ComponentScan` | Salesforce entity mapper. |
| `ContentPieceMapperModule` | `@ComponentScan` | `ContentPiece` DTO mapper. |
| `CustomPlaylistMapperModule` | `@ComponentScan` | Custom playlist DTO mapper. |
| `OrganizationMapperModule` | `@ComponentScan` | Organization DTO mapper. |

---

## Version Governance & Release Process

**Artifact coordinates:**
- groupId: `com.friendmedia`
- artifactId: `fm-common`
- version: `8.9.1` (current source in this repo)
- Repository: `https://vrtly-515289352310.d.codeartifact.us-west-2.amazonaws.com/maven/fm-common/`
- Distribution: AWS CodeArtifact, account `515289352310`, domain `vrtly`, region `us-west-2`
- Repository id in `settings.xml`: `vrtly-codeartifact`

**Build and release process (from `bitbucket-pipelines.yml`):**
1. All pipeline steps authenticate to CodeArtifact via AWS OIDC federation. The Bitbucket OIDC token is exchanged for a short-lived `CODEARTIFACT_AUTH_TOKEN` using the IAM role `arn:aws:iam::515289352310:role/bitbucket-cicd-deployrole`.
2. The build image is a private Amazon ECR image: `515289352310.dkr.ecr.us-west-2.amazonaws.com/base-oracle-jdk:17-ol-mvn`.
3. Pull requests against `develop` branch trigger `mvn -B -U clean verify` (build + test + checkstyle). No deploy.
4. Merges to `master` trigger `mvn deploy` — this publishes the JAR to CodeArtifact and makes it available to all consuming services.
5. No SNAPSHOT versioning is visible. The library appears to use fixed release versions: consumers pin a specific version in their `pom.xml`.

**No CHANGELOG is present.** There is no `CHANGELOG.md`, `CHANGES.txt`, `HISTORY.md`, or similar file in the repo root. Version history can only be inferred from CodeArtifact artifact versions or from git blame on `pom.xml`.

**No auto-configuration.** There is no `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` or `META-INF/spring.factories` file. All module wiring is explicit via `@Import` in each consuming service's `ImportConfig.java`.

**Checkstyle enforcement.** The Maven Checkstyle plugin runs at `validate` phase with `failOnViolation=true`. Style violations that exceed warning severity will fail the build. Configuration is in `doc/tools/checkstyle.xml` with suppressions in `checkstyle-suppression.xml`.

---

## Version Skew Analysis

The source code in this repository is at version **8.9.1** (as declared in `pom.xml`). The fmcom-api tech spike (filed at the time of the 8.9.0 release audit) references `fm-common:8.9.0` as the version imported by `fmcom-api`. This implies:

1. **8.9.1 is a minor patch above the version deployed in fmcom-api as of the spike date.** The difference between 8.9.0 and 8.9.1 is not directly visible because there is no CHANGELOG and no git history is available within the `fm-common` repository clone used for this spike (the git log shows only commits from the outer `vrtly-knowledge-base` repo, not the original `fm-common` Bitbucket history).

2. **What we can infer as additive or changed since 8.8.9 (the prior minor version):**
   - The `Destinations` interface and the typed `JmsDestination<T>` pattern appear to be a significant refactoring. The fmcom-api spike described JMS destinations as string constants only (`Destinations.RNF_MEDIA_PROCESSING`, etc.). The current code shows a richer type-safe model where each destination is a class implementing `JmsDestination<T>` with a typed payload class, expiry behavior, and a JmsType. This suggests the 8.9.x line introduced the typed JMS destination system.
   - `AuthModule`, `AuthService`, `AuthServiceClient`, and `BrokerStateClient` are all relatively new additions (author date comments show `2025-04` timestamps for `AuthServiceClient`, `2025-03` for `BrokerStateClient`). These are almost certainly additive 8.9.x changes that moved auth from per-service implementations into the shared library.
   - `TelemetryRedisKeys` (authored `2026-04-03`) is very new — it was almost certainly not present in 8.8.9 and was added during the 8.9.x line.
   - `ContentQuarantineService` (authored `2026-03-30`) and the quarantine pipeline are 8.9.x additions.
   - `TelemetryService` (authored `2026-04-25`) is a 8.9.x addition — the telemetry pipeline previously had no shared abstraction.
   - `OrganizationFeaturesModule` (authored `2026-04-24`) is new.
   - The Elasticsearch throttle system (`ElasticsearchThrottleConfig`, `ThrottledElasticsearchTransport`, `ElasticsearchLimitClient`) with its JMS-based coordinator appears to have been introduced in the 8.9.x line (the ELASTICSEARCH_ACCESS_CONTROL.md doc is the clearest evidence of a major added feature).

3. **Risk of upgrading from 8.9.0 to 8.9.1:** Without a CHANGELOG, any consuming service upgrading from 8.9.0 must inspect the diff manually. The library does not use semantic versioning in a way that guarantees backward compatibility within a minor version (e.g. 8.9.x). The presence of `@Deprecated` annotations (one found on `selectAllByBrandId` in `ScreenStateClient`) suggests some API surface is being phased out. Any service calling deprecated methods may receive compiler warnings.

4. **8.8.9 → 8.9.x is a significant delta:** The jump in minor version combined with author timestamps strongly suggests 8.9.x introduced: the JMS type system, the auth module, the telemetry pipeline, the ES throttle coordinator, content quarantine, and `BrokerStateClient`. This is not a cosmetic bump.

---

## Notable Risks & Observations

1. **Single point of version coordination across all services.** All backend services are coupled to the same `fm-common` version. Any breaking change — even in a single module (e.g. renaming a `ScreenDto` field or changing a JMS payload type) — requires a coordinated upgrade of all consumers simultaneously. There is no versioned API contract per module, no interface stability guarantee, and no mechanism to have two services on different `fm-common` versions at runtime. A bug introduced in any part of the library forces a rollback of all services.

2. **JMS destination name strings are not schema-registered.** All 31 queue and topic names are bare string constants in the `Destinations.Key` interface. There is no schema registry, no message envelope versioning, and no compatibility checking. If a queue name is renamed in a new `fm-common` version (e.g. `api.consult.email.send` → `api.email.send`), the old queue accumulates unprocessed messages while the new publisher sends to the renamed queue. Services on different `fm-common` versions would silently lose messages. The typed `JmsDestination<T>` pattern enforces payload types at compile time but provides no runtime schema enforcement.

3. **Redis keyspace is not technically isolated between services.** `fmcom-api` and `fmcom-player-api` share the same Redis instance and write to overlapping key namespaces defined in `RedisChannels`. There is no Redisson namespace prefix, no Redis DB index separation, and no key prefix that distinguishes api vs player-api keys. For example, `screen:current:play:content`, `screen:playlist`, and `screen:plan` are all player-api keys but they live in the same flat keyspace as `fmcom-api` auth token keys, ShedLock keys, and Spring Cache keys. A key-name collision between a future api feature and an existing player-api key would cause silent data corruption.

4. **`TelemetryRedisKeys` and `RedisChannels` are in different classes with no unified ownership.** `TelemetryRedisKeys` is in `constant/` while `RedisChannels` is in `enums/`. There is no `RedisKeyRegistry` or single authoritative reference. A developer adding a new Redis key can miss existing collisions if they only check one file. The naming conventions are also different: `TelemetryRedisKeys` uses fully qualified hierarchical prefixes (`screen:playback:quality:cap:`) while `RedisChannels` uses shorter, less descriptive prefixes (`screen:plan`). This inconsistency increases collision risk.

5. **Fastjson 1.2.83 is present in a shared library consumed by all services.** Alibaba Fastjson has a history of critical CVEs. While 1.2.83 was a security-focused release, it is over 3 years old (2022). Any CVE discovered in Fastjson after 1.2.83 would affect all services simultaneously since it is shipped as a transitive dependency of `fm-common`. The library cannot be easily removed because domain entity methods use Fastjson directly for `cmsInfo()` / `adminInfo()` JSON building. Upgrading requires code changes in both `fm-common` and any entity that uses `JSONObject` directly.

6. **No auto-configuration means ~80 explicit `@Import` statements in consuming services.** The design choice to require explicit `@Import` provides fine-grained control but creates a maintenance burden. Adding a new module to `fm-common` requires a code change in every consuming service's `ImportConfig.java`. There is no "import all" option, and no tooling to detect when a service is missing a module it implicitly depends on (e.g. via a transitive service call). Omitting a module causes `NoSuchBeanDefinitionException` at startup — this is caught early but makes onboarding new services error-prone.

7. **No CHANGELOG makes version upgrade decisions opaque.** Upgrading from 8.9.0 to 8.9.1 requires reading every commit diff on Bitbucket to assess risk. Given that `fm-common` contains JPA entities, if any entity field is changed (added, renamed, type-changed), it may trigger Liquibase migration requirements in consuming services that own migrations for that table — but only if those services run Liquibase. If they do not, the entity change may go unnoticed until runtime. The lack of a CHANGELOG is a significant operational risk for a library that owns the entire data model.

8. **SOV rule engine is a 3x3 enum with hardcoded default percentages — no versioning.** `SovRuleName` embeds business-logic percentage values (`defaultCustomPercentage`, `defaultBrandPercentage`, `defaultMaxSingleBrandPercentage`, `defaultMinOrganicBrandPercentage`) directly in enum constructor arguments. Changing these values requires a library version bump and redeployment of all consumers. The `MySqlSovRule` table can override these per-organization, but the defaults are code-frozen. If the business needs to change the matrix dimensions (e.g. add a "Very High" custom content tier), it requires an enum refactor with potentially breaking ordinal changes — the enum uses `values()[ordinal]` for deserialization, which is order-dependent.

9. **`ElasticsearchIndex` resolves the `ES_PREFIX` at class-load time from the system environment.** If the `ES_PREFIX` environment variable is not set at JVM startup, all index names are created without a prefix — meaning `dev`, `qa`, `alpha`, and `prod` environments would share the same Elasticsearch index names if they connect to the same cluster. The class logs a warning, but there is no fail-fast guard. A misconfigured deployment could write production data to a development index (or vice versa) silently.

10. **`ScreenStateClient` has 50+ methods — it is an extremely wide interface.** The Feign client covers screen CRUD, bulk updates, count queries, paginated queries, analytics queries, MAC-based lookups, organization-scoped queries, and admin operations. Any Feign timeout or state service outage causes all of these call sites to fail simultaneously. There is no circuit-breaker configuration visible in `StateClientModule`. The state service is a single point of failure for all screen lookups across the entire platform.

11. **`BrokerStateClient` introduces a dual-path JMS design with unclear routing rules.** The `JmsMode` enum (`MQ` vs `STATE`) and the existence of `BrokerStateClient` imply that some messages go through Amazon MQ directly and others are routed through the state service's broker proxy endpoint. The routing logic is not visible in `fm-common` alone (it is in each service's `MessagingService` implementation). If the routing configuration is incorrect for a given environment, messages may be silently dropped or duplicated.

12. **Telemetry deduplication TTL is `configurable` but the default is not visible in `fm-common`.** `TelemetryDeduplicationService` writes dedup fingerprints to Redis with a TTL bound to `TelemetryDeduplicationProperties`. The properties class is in `fm-common` but the default values are set in each service's `application.yml`. If `fmcom-api` and `fmcom-player-api` have different dedup TTLs, a telemetry event could appear deduplicated from one service's perspective but not another's — leading to inconsistent analytics counts.

13. **`AuthService.AUTH_RESULT` is a `ThreadLocal` on an interface.** `AuthService.AUTH_RESULT = new ThreadLocal<>()` is a static field on the interface. While this is valid Java, it is unusual and can mislead developers into thinking it is an instance field or a Spring bean. If the `ThreadLocal` is not cleared after use in an async or thread-pool context, it can leak authentication context between requests — a security concern.

14. **Checkstyle is enforced with `failsOnError=false` but `failOnViolation=true`.** This means checkstyle violations that are classified as warnings will fail the build, but errors in the checkstyle tool itself (e.g. misconfigured XML) will be ignored. This is the opposite of what most teams expect — typically tool errors are fatal and violations are warnings. The configuration may not be intentional.

15. **`MySqlScreen` entity lives in `fm-common` but screen state is managed by a separate `state` service.** The screen entity is both a JPA entity (for direct DB access via `MySqlScreen`) and a Feign DTO (`ScreenDto`). This means the MySQL `screen` table can be accessed both directly (by services that import `MySqlScreenModule`) and indirectly via the state service's REST API (`ScreenStateClient`). If both access patterns are in use simultaneously in the same service, there is a risk of stale cache reads from the Feign layer after a direct DB write.

---

## Open Questions

1. **Which services currently import which modules?** The fmcom-api spike references approximately 60 `@Import`s. What is the exact import list for fmcom-player-api and rnf? Are there modules in `fm-common` that no service currently imports (dead code)?


3. **How are Redis keys protected from cross-service collision in practice?** Is there an operational convention (e.g. Redisson namespace in application config, separate Redis DB per service) not visible in `fm-common` itself? Or do the naming conventions in `RedisChannels` and `TelemetryRedisKeys` provide sufficient isolation?

4. **Which `JmsMode` (`MQ` vs `STATE`) does each service use, and what governs the choice?** The `BrokerStateClient` path through the state service must exist for a reason (likely: services that are deployed in environments where they cannot reach Amazon MQ directly). What is the current routing configuration per environment (dev/qa/alpha/prod)?

5. **What is the `ES_PREFIX` value per environment?** Given the risk of index collision if this is unset, what are the actual values per environment and how are they validated in the deployment pipeline?

6. **Is `MySqlScreen` still accessed via direct JPA by any service, or is `ScreenStateClient` the only access path?** If fmcom-player-api imports `MySqlScreenModule` and also calls `ScreenStateClient`, there is a dual-write/dual-read risk. Clarification needed on the intended access pattern for the screen entity.

7. **What is the `CriticalIssueService` implementation used in production?** The default implementation only logs. Is there a production implementation that sends alerts (Slack, PagerDuty, OpsGenie)? If not, `ES_CLUSTER_NO_SPACE` and similar critical issues are only visible in logs.

8. **Why does `SovRuleName` use ordinal-based deserialization (`values()[ordinal]`)?** Ordinal-based enum deserialization breaks silently if the enum order changes. Is this stored as an ordinal in the database? If so, adding or reordering enum values is a breaking migration.

9. **What is the deduplication TTL for `TelemetryDeduplicationService` in each environment?** Is there a risk of telemetry events being suppressed across services due to conflicting TTL configurations?

10. **Does fmcom-player-api import `AuthModule` and use the shared `AuthService`?** The fmcom-api spike described a `TokenBasedAuthenticationFilter` in fmcom-api. Is authentication now fully delegated to the shared `AuthService` + `AuthServiceClient` in both services, or does fmcom-api still maintain its own filter? Understanding this is needed to assess the blast radius of a state service outage on auth.
