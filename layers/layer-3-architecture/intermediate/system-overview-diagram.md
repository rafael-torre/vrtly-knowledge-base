---
title: "System Overview Diagram — Vrtly Platform"
last_updated: 2026-06-10
---

# System Overview Diagram: Vrtly Platform

Four focused views of the platform. Each diagram covers one concern area and stays under 15 nodes. Gap services (not yet spiked) are marked **⚠️**.

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

Internal structure of the CMS portals, how they route to the backend, and the infrastructure fmcom-api owns.

```mermaid
flowchart TD
    subgraph CMS["CMS Web Frontend · S3 / CloudFront"]
        Home["vrtly-home\nAuth shell · org routing · session bootstrap"]
        VPM["VPM — Provider Portal\nScreen mgmt · content upload\nplaylist scheduling · device pairing"]
        VAM["VAM — Advertiser Portal\nCampaign creation · reach & frequency\nanalytics"]
        Onb["Onboarding\nOrg signup · account setup"]
    end

    subgraph FMAPI["fmcom-api · Spring Boot / ECS"]
        FMCore["Content lifecycle · transcoding\nBilling (Stripe) · device mgmt\nSocial sync (Meta) · admin · scheduled jobs"]
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

    ExtServices["Other Integrations\nShippo · Google Maps · SMTP\nIntercom · MailChimp · Salesforce ⚠️"]

    Home --> VPM
    Home --> VAM
    VPM -->|"REST /cms/* · dual-token auth"| FMCore
    VAM -->|"REST /cms/* · dual-token auth"| FMCore
    Onb -->|"REST /cms/*"| FMCore
    VPM -->|"iframe / postMessage\ncontent preview"| HTML5Preview
    VAM -->|"iframe / postMessage\ncontent preview"| HTML5Preview

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

Device-side player, the player API, and the infrastructure it owns. Includes the inter-service call back to fmcom-api.

```mermaid
flowchart TD
    subgraph Device["Device / Player App"]
        Cordova["cordova-player ⚠️\nFireTV native shell\nProvides device UUID + model"]
        HTML5["html5core · Vue 3 / TypeScript\nFireTV · webOS · Tizen · iOS · Browser\nPlaylist playback · telemetry batching\nABR event reporting · Info Pack QR"]
    end

    subgraph PAPI["fmcom-player-api · Spring Boot / ECS"]
        PACore["Device reg & activation · playlist delivery\nWebSocket push · ABR escalation state machine\nTelemetry ingestion · rate limiting (Bucket4j)"]
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

Asynchronous event flows, scheduled jobs, and the three gap microservices that need spiking.

```mermaid
flowchart TD
    FMComAPI["fmcom-api"]
    PlayerAPI["fmcom-player-api"]

    subgraph Async["Async Infrastructure · AWS"]
        MQ["Amazon MQ · ActiveMQ / JMS\nAsync event bus for content lifecycle\nand playlist invalidation"]
        XXL["XXL-Job Admin ⚠️\nDistributed scheduler · single point of failure\njobs.prod.vrtly.app"]
    end

    subgraph Gap["Gap Microservices ⚠️ — needs spike"]
        RNF["rnf ⚠️\nPlaylist resolver · SOV engine\nmedia processing dispatch\nrnf.prod.vrtly.app"]
        State["state ⚠️\nScreen state service\nHot path for both APIs\nstate.prod.vrtly.app"]
        YTD["youtube-downloader ⚠️\nYouTube video download worker\nReceives jobs via JMS"]
    end

    FMComAPI -->|"Feign HTTP — playlist resolution\nJMS RNF_MEDIA_PROCESSING — transcoding"| RNF
    PlayerAPI -->|"Feign HTTP /playlist/current/{screenId}"| RNF

    FMComAPI -->|"Feign HTTP ScreenStateClient"| State
    PlayerAPI -->|"Feign HTTP ScreenStateClient\nhot path"| State

    FMComAPI -->|"JMS YOUTUBE_DOWNLOAD"| MQ
    MQ -->|"Job dispatch"| YTD
    YTD -->|"HTTP /internal/youtube-downloads/*\nprogress callbacks"| FMComAPI

    FMComAPI -->|"15+ job handlers · port 9999"| XXL
    PlayerAPI -->|"Telemetry cleanup jobs · port 9997"| XXL
```

---

## Gap Services — Needs Follow-up Spike

| Service | Evidence | Priority |
|---|---|---|
| `rnf` (reach-and-frequency / playlist resolver) | Called by both backend APIs; owns SOV logic and media processing | High — critical path for playlist delivery |
| `state` service | Called in hot paths by both APIs via `fm-common` `ScreenStateClient` | High — screen lookup performance risk |
| `youtube-downloader` | Bidirectional with `fmcom-api` via JMS + internal HTTP | Medium |
| `cordova-player` (FireTV shell) | Wraps `html5core`; provides device identity to player app | Medium |
| Roku player app | Special-cased in `fmcom-player-api` (MAC migration, cert override) | Medium |
| Android TV player app | Implied by device type enum in `fmcom-player-api` | Low |
| `fm-common` JAR (v8.9.0 / v8.8.9) | Defines all JMS destinations, Redis key constants, domain models — shared contract layer | High — version skew between APIs is a deployment risk |
| `@vrtly/component-library` | Consumed by `fmcom-vrtly-fe-monorepo` at `^0.8.20` | Low |
| `my.vrtly.app` (patient info-pack portal) | QR code landing page referenced by `html5core` | Low |
| XXL-Job Admin | Single point of failure for all scheduled tasks across both APIs | Medium |

---

## Notable Architectural Risks (surfaced during discovery)

- **`private_key.pem` committed to source** in `fmcom-player-api` — CloudFront signing key exposed in repo history.
- **Shared MySQL database** between `fmcom-api` and `fmcom-player-api` — each runs Liquibase migrations independently; schema coordination risk.
- **`fm-common` version skew** — `fmcom-api` on 8.9.0, `fmcom-player-api` on 8.8.9; breaking changes require coordinated deployments with no published compatibility matrix.
- **In-memory session store** (`SessionHolder`) in `fmcom-player-api` — not horizontally safe; ECS scale-out requires ALB sticky sessions or silent WebSocket push drops occur.
- **SHA-1 request signing** between `html5core` and `fmcom-player-api` — deprecated for authentication use cases.
- **Unauthenticated HLS streaming endpoint** — `/player/content/stream/...` explicitly excluded from all security interceptors in `fmcom-player-api`.
