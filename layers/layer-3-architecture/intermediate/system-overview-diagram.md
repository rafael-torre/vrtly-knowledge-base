---
title: "System Overview Diagram — Vrtly Platform"
last_updated: 2026-06-12
---

# System Overview Diagram: Vrtly Platform

Five focused views of the platform. Each diagram covers one concern area and stays under 15 nodes. Gap services (not yet spiked) are marked **⚠️**. Services confirmed by spike are shown without warning markers.

---

## View 1 — System Context

Who uses the platform, what the main system areas are, and which external services are integrated. No internal detail.

```mermaid
flowchart TD
    Provider["👤 Provider\nHealthcare practice admin"]
    Sponsor["👤 Sponsor / Brand\nAdvertiser"]
    DevAdmin["👤 Device Admin"]

    subgraph CMS["CMS Web Frontend · S3 / CloudFront"]
        CMSFE["VPM · VAM · vrtly-home · Onboarding\nVue 3 / TypeScript"]
    end

    subgraph Player["Player App · S3 / CloudFront"]
        PlayerFE["html5core · cordova ⚠️\nVue 3 / FireTV WebView"]
    end

    subgraph Backend["Backend APIs · AWS ECS"]
        APIs["fmcom-api  +  fmcom-player-api\nSpring Boot 3.2 / Java 17"]
    end

    Provider -->|"HTTPS"| CMS
    Sponsor -->|"HTTPS"| CMS
    DevAdmin -->|"HTTPS"| CMS

    CMS -->|"REST /cms/*"| Backend
    PlayerFE -->|"REST + WSS"| Backend

    Backend <-->|"Billing sync + webhooks"| Stripe["Stripe"]
    Backend -->|"Social content pull"| Meta["Meta Graph API"]
    GCP["GCP Pub/Sub / Firebase"] -->|"POST /webhook/gcp/pubsub"| Backend
    Backend -->|"Outbound SMS"| Twilio["Twilio"]
    Backend -->|"Shipping · Geocoding · Email\nCRM webhooks · CRM sync"| OtherExt["Other Integrations\nShippo · Google Maps · SMTP\nIntercom · MailChimp · Salesforce ⚠️"]
```

---

## View 2 — CMS Frontend + fmcom-api

Internal structure of the CMS portals, how they route to the backend, and the infrastructure fmcom-api owns. `fm-common` is shown as a shared library dependency of fmcom-api (not a standalone service). `@vrtly/component-library` is annotated with its double-bundling risk (Element Plus is bundled rather than externalized, producing two EP copies in every SPA).

```mermaid
flowchart TD
    subgraph CMS["CMS Web Frontend · S3 / CloudFront"]
        Home["vrtly-home\nAuth shell · org routing · session bootstrap"]
        VPM["VPM — Provider Portal\nScreen mgmt · content upload\nplaylist scheduling · device pairing"]
        VAM["VAM — Advertiser Portal\nCampaign creation · reach & frequency\nanalytics"]
        Onb["Onboarding\nOrg signup · account setup"]
        CompLib["@vrtly/component-library 0.8.20\n41 Vue 3 components · 111 icons · SCSS tokens\n⚠️ EP bundled not externalized — double-bundle risk"]
    end

    subgraph FMAPI["fmcom-api · Spring Boot / ECS"]
        FMCore["Content lifecycle · transcoding dispatch\nBilling (Stripe) · device mgmt\nSocial sync (Meta) · admin · scheduled jobs"]
        FMCommon["fm-common 8.9.0 (JAR)\nShared JMS destinations · Redis keys\nJPA entities · Feign clients · domain DTOs"]
    end

    subgraph Infra["Shared Infrastructure · AWS"]
        MySQL[("MySQL RDS\nfm_store — primary domain DB\npool size 10")]
        Redis[("Redis ElastiCache\nAuth + app cache · ShedLock · feature flags")]
        ES[("Elasticsearch\nAnalytics indices · ad slots · impressions")]
        S3CF["S3 + CloudFront\nMedia storage · SPA bundles\nSigned delivery URLs"]
        EFS["AWS EFS\nShared media files between ECS instances"]
        Transcribe["AWS Transcribe\nSpeech-to-text · subtitle generation"]
    end

    HTML5Preview["html5core\n(content preview)"]

    ExtServices["Other Integrations\nShippo · Google Maps · SMTP\nIntercom · MailChimp · Salesforce"]

    Home --> VPM
    Home --> VAM
    CompLib -->|"npm · AWS CodeArtifact"| Home
    CompLib -->|"npm · AWS CodeArtifact"| VPM
    CompLib -->|"npm · AWS CodeArtifact"| VAM
    VPM -->|"REST /cms/* · dual-token auth"| FMCore
    VAM -->|"REST /cms/* · dual-token auth"| FMCore
    Onb -->|"REST /cms/*"| FMCore
    VPM -->|"iframe / postMessage\ncontent preview"| HTML5Preview
    VAM -->|"iframe / postMessage\ncontent preview"| HTML5Preview

    FMCommon -->|"JAR compile-time dep\n@Import modules"| FMCore
    FMCore --> MySQL
    FMCore --> Redis
    FMCore --> ES
    FMCore --> S3CF
    FMCore --> EFS
    FMCore --> Transcribe
    FMCore -->|"Shipping · Geocoding · Email\nCRM webhooks · CRM sync"| ExtServices
```

---

## View 3 — Player App + fmcom-player-api

Device-side player, the player API, and the infrastructure it owns. Includes the inter-service call back to fmcom-api. `fm-common` is shown as a shared library dependency of fmcom-player-api (not a standalone service).

```mermaid
flowchart TD
    subgraph Device["Device / Player App"]
        Cordova["cordova-player ⚠️\nFireTV native shell\nProvides device UUID + model"]
        HTML5["html5core · Vue 3 / TypeScript\nFireTV · webOS · Tizen · iOS · Browser\nPlaylist playback · telemetry batching\nABR event reporting · Info Pack QR"]
    end

    subgraph PAPI["fmcom-player-api · Spring Boot / ECS"]
        PACore["Device reg & activation · playlist delivery\nWebSocket push · ABR escalation state machine\nTelemetry ingestion · rate limiting (Bucket4j)"]
        FMCommonP["fm-common 8.8.9 (JAR)\nShared JMS destinations · Redis keys\nJPA entities · Feign clients · domain DTOs\n⚠️ one minor version behind fmcom-api (8.9.0)"]
    end

    subgraph Infra["Shared Infrastructure · AWS"]
        MySQL[("MySQL RDS\nfm_store — pool 150")]
        Redis[("Redis ElastiCache DB 2\nSession · ABR quality caps · escalation state")]
        ES[("Elasticsearch\nTelemetry events · mitigation events")]
        S3CF["S3 + CloudFront\nSigned asset URLs for every playlist item"]
        MQ["Amazon MQ · ActiveMQ\n9 PLAYER_* topics subscribed"]
    end

    FMComAPI["fmcom-api\ninter-service coordination"]

    Cordova -->|"Loads player from S3 via WebView"| HTML5
    HTML5 -->|"REST /player/* · SHA-1 signed ⚠️"| PACore
    HTML5 -->|"WSS persistent\nplaylist push · remote commands"| PACore
    HTML5 -->|"REST /cms/encrypt · /cms/qr-code/*\n(Info Pack QR only)"| FMComAPI

    FMCommonP -->|"JAR compile-time dep\n@Import modules"| PACore
    PACore --> MySQL
    PACore --> Redis
    PACore --> ES
    PACore --> S3CF
    PACore -->|"Subscribes PLAYER_* · publishes API_CONTENT_QUARANTINE"| MQ
    PACore -->|"HTTP /internal/* · API key"| FMComAPI
    FMComAPI -->|"Publishes PLAYER_* → invalidates device playlists"| MQ
    MQ -->|"PLAYER_* topics trigger playlist refresh"| PACore
```

---

## View 4 — Async + Gap Services

Asynchronous event flows, scheduled jobs, confirmed microservices (rnf, state), and remaining gap services. rnf and state-service are now analyzed; youtube-downloader and xxl-job-admin remain unanalyzed (⚠️). State-service owns the ES concurrency budget; rnf is the sole transcoder and publishes `API_CONTENT_ADD` after every successful transcode.

```mermaid
flowchart TD
    FMComAPI["fmcom-api"]
    PlayerAPI["fmcom-player-api"]

    subgraph Async["Async Infrastructure · AWS"]
        MQ["Amazon MQ · ActiveMQ / JMS\n31 typed destinations (fm-common)\nBROKER_PREFIX per-env namespacing"]
        XXL["XXL-Job Admin ⚠️\nDistributed scheduler · single point of failure\njobs.prod.vrtly.app\nfmcom-api: 15+ jobs · fmcom-player-api: telemetry cleanup\nrnf: 18 handlers"]
    end

    subgraph Confirmed["Analyzed Microservices"]
        RNF["rnf (reach-n-freq)\nSpring Boot 3.2.0 / Java 17 · fm-common 8.9.1\nPlaylist resolution (serves pre-computed ES schedules)\nSOV engine · Media transcoding (FFmpeg)\n18 XXL-Job handlers · executor port 9996\nrnf.prod.vrtly.app"]
        State["state-service\nSpring Boot 3.3.2 / Java 17 · fm-common 8.7.8\nAuthoritative screen registry (JVM ConcurrentHashMap)\nIn-process HTTP long-poll message broker\nAuth token management (MySQL user_token)\nES concurrency governor (sole JMS coordinator)\nstate.prod.vrtly.app · port 9092"]
    end

    subgraph Gap["Gap Services ⚠️ — not yet analyzed"]
        YTD["youtube-downloader ⚠️\nYouTube video download worker\nReceives jobs via JMS YOUTUBE_DOWNLOAD"]
    end

    FMComAPI -->|"Feign HTTP /playlist/current/{screenId}"| RNF
    PlayerAPI -->|"Feign HTTP /playlist/current/{screenId}"| RNF
    FMComAPI -->|"JMS RNF_MEDIA_PROCESSING · RNF_GENERATE\nRNF_OPEN_HOURS_UPDATED · RNF_RECENTLY_ACTIVATED\nRNF_PDF_TO_IMAGE · RNF_TRANSCODE (legacy)"| MQ
    MQ -->|"RNF_* topics dispatch"| RNF
    RNF -->|"JMS API_CONTENT_ADD (transcoding done)\nPLAYER_CONTENT_TRANSCODED\nPLAYER_ORGANIZATION_CONTENT_UPDATED"| MQ

    FMComAPI -->|"Feign ScreenStateClient · AuthServiceClient"| State
    PlayerAPI -->|"Feign ScreenStateClient · BrokerStateClient\nHTTP long-poll /broker/consume (22 s)"| State
    RNF -->|"InstanceStateClient heartbeat\nhard System.exit(-1) on loss"| State
    State -->|"JMS ELASTICSEARCH_LIMITS_ALLOCATED\nALL_USER_ACCESS_CHANGED"| MQ

    FMComAPI -->|"JMS YOUTUBE_DOWNLOAD_DESTINATION"| YTD
    YTD -->|"JMS YOUTUBE_UPDATE_URL + HTTP callbacks"| FMComAPI

    FMComAPI --> XXL
    PlayerAPI --> XXL
    RNF --> XXL
```

---

## View 5 — Internal Microservices

Internal structure of the two newly analyzed backend services — rnf and state-service — and their relationships to the calling APIs and shared infrastructure. rnf is split into four functional subsystems; state-service into four owned capabilities. Both services share the same MySQL (`fm_store`) and Elasticsearch cluster as fmcom-api and fmcom-player-api.

```mermaid
flowchart TD
    FMComAPI["fmcom-api"]
    PlayerAPI["fmcom-player-api"]

    subgraph RNF["rnf · Spring Boot 3.2.0 / Java 17 · ECS"]
        PCC["PlaylistCurrentController\nServes pre-computed playlists from ES\nGET /playlist/current/{screenId}"]
        PGS["PlaylistGenerationService\nSOV + open-hours + POD algorithm\nXXL-Job daily sweep · JMS-triggered regen"]
        MPO["MediaPipelineOrchestrator\nRoutes RNF_MEDIA_PROCESSING by operation\nUnified + legacy PDF/transcode shims"]
        UVP["UnifiedVideoPipeline\nFFmpeg h264 + HLS ABR ladder\n3 thread pools · EFS temp staging\nPublishes API_CONTENT_ADD + PLAYER_* on complete"]
    end

    subgraph State["state-service · Spring Boot 3.3.2 / Java 17 · ECS"]
        SSS["ScreenStateService\nJVM ConcurrentHashMap — all ScreenDto\nMicrosecond reads · 1-min MySQL flush\nDeployment self-call flush on startup"]
        BS["BrokerService\nIn-process HTTP long-poll broker\nQueues + topics in heap · ES snapshot on shutdown\nAt-most-once delivery"]
        Auth["AuthService\nToken issuance + verify + refresh\nMySQL user_token table\nBroadcasts ALL_USER_ACCESS_CHANGED via JMS"]
        ESCoord["ElasticsearchLimitCoordinatorService\nSole ES quota allocator for all services\nSubscribes INSTANCE_REGISTERED/QUOTA_REQUEST\nBroadcasts ELASTICSEARCH_LIMITS_ALLOCATED"]
    end

    subgraph Infra["Shared Infrastructure"]
        MySQL[("MySQL RDS fm_store\npool 10")]
        Redis[("Redis DB 4 dev / DB 2 prod")]
        ES[("Elasticsearch\nElasticPlaylistSchedule\nElasticPlayCurrent + 37 indices")]
    end

    FMComAPI -->|"Feign GET /playlist/current/{screenId}"| PCC
    PlayerAPI -->|"Feign GET /playlist/current/{screenId}"| PCC
    FMComAPI -->|"JMS RNF_MEDIA_PROCESSING"| MPO
    MPO --> UVP
    PGS --> ES
    PCC --> ES
    UVP --> ES

    RNF -->|"InstanceStateClient — hard exit on loss"| SSS
    FMComAPI -->|"ScreenStateClient · AuthServiceClient"| SSS
    PlayerAPI -->|"BrokerStateClient long-poll /broker/consume"| BS
    SSS --> MySQL
    SSS --> Redis
    Auth --> MySQL
    ESCoord --> ES
```

---

## Gap Services — Status

### Resolved (spiked)

| Service | Spike Date | Key Findings |
|---|---|---|
| `rnf` (reach-n-freq) | 2026-06-12 | Spring Boot 3.2.0 / Java 17 / `fm-common` 8.9.1. Playlist resolver (serves pre-computed ES schedules), SOV engine, FFmpeg transcoder, 18 XXL-Job handlers (port 9996). JMS: subscribes to 6 RNF_* queues; publishes `API_CONTENT_ADD` (sole transcoding publisher), `PLAYER_CONTENT_TRANSCODED`, `PLAYER_CONTENTS_TRANSCODED_BATCH`, `PLAYER_ORGANIZATION_CONTENT_UPDATED`, `PLAYER_SCREEN_CONTENT_UPDATED`. Hard `System.exit(-1)` on state-service heartbeat loss. |
| `state-service` | 2026-06-12 | Spring Boot 3.3.2 / Java 17 / `fm-common` 8.7.8 (oldest version in fleet). Authoritative screen registry (JVM `ConcurrentHashMap`), in-process HTTP long-poll broker, auth token management (`user_token` MySQL table), sole ES concurrency budget coordinator. No `SecurityFilterChain` — all endpoints open within VPC. Port 9092. |
| `fm-common` JAR | 2026-06-12 | Current source at 8.9.1. Four production versions: fmcom-api 8.9.0, fmcom-player-api 8.8.9, rnf 8.9.1, state 8.7.8. 31 typed JMS destinations, 80+ MySQL JPA modules, 37 Elasticsearch modules, all Feign clients for state-service. No CHANGELOG; no auto-configuration. |
| `@vrtly/component-library` | 2026-06-12 | Version 0.8.20. 41 Vue 3 components, 111 icons, SCSS token system. Element Plus bundled (not externalized) — double-bundle risk in all four SPAs. ESM-only with broken `require` field. No CHANGELOG; no integration test against monorepo. |

### Outstanding (not yet analyzed)

| Service | Evidence | Priority |
|---|---|---|
| `youtube-downloader` | Bidirectional with `fmcom-api` via JMS (`YOUTUBE_DOWNLOAD_DESTINATION`, `YOUTUBE_UPDATE_URL_DESTINATION`) + internal HTTP; `rnf` has a `YoutubeContentDownloadReenqueueJob` whose relationship to fmcom-api's `YoutubeDownloadRescueService` is unclear | Medium |
| `cordova-player` (FireTV shell) | Wraps `html5core`; provides device UUID, model, and version via `window._cordovaNative` | Medium |
| Roku player app | Special-cased in `fmcom-player-api` (`RokuMacMigrationService`, `RokuCertOverrideService`) | Medium |
| Android TV player app | Implied by device type enum in `fmcom-player-api` | Low |
| `my.vrtly.app` (patient info-pack portal) | QR code landing page referenced by `html5core` as `VITE_INFOPACK_URL`; URLs encrypted server-side before embedding | Low |
| XXL-Job Admin | Single point of failure for all scheduled tasks across three services (fmcom-api: 15+ jobs; fmcom-player-api: telemetry cleanup; rnf: 18 handlers). `state-service` `doc/scheduler-design.md` proposes retiring XXL-Job in favor of state-service as distributed cron coordinator. | Medium |

---

## Notable Architectural Risks (surfaced during discovery)

- **`private_key.pem` committed to source** in `fmcom-player-api` — CloudFront signing key exposed in repo history.
- **Shared MySQL database** between `fmcom-api` and `fmcom-player-api` — each runs Liquibase migrations independently; schema coordination risk.
- **`fm-common` version skew** — `fmcom-api` on 8.9.0, `fmcom-player-api` on 8.8.9; breaking changes require coordinated deployments with no published compatibility matrix.
- **In-memory session store** (`SessionHolder`) in `fmcom-player-api` — not horizontally safe; ECS scale-out requires ALB sticky sessions or silent WebSocket push drops occur.
- **SHA-1 request signing** between `html5core` and `fmcom-player-api` — deprecated for authentication use cases.
- **Unauthenticated HLS streaming endpoint** — `/player/content/stream/...` explicitly excluded from all security interceptors in `fmcom-player-api`.
