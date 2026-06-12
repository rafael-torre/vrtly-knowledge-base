---
title: "Pre-Existing Risk Register — Vrtly Platform"
last_updated: 2026-06-12
---

# Pre-Existing Risk Register — Vrtly Platform

> **Scope and intent:** This document records technical risks and concerns identified during the architecture discovery audit of the four Vrtly production repositories (June 2026). All items listed here were present in the codebase prior to any DBP engagement. This register exists to ensure DBP is not held accountable for pre-existing conditions, to inform the engagement scope, and to surface issues the client should be made aware of before work begins.
>
> Source: tech spikes and system map produced in the architecture discovery phase (`layers/layer-3-architecture/intermediate/`).

---

## Security Risks

### S1 — Auth tokens stored in localStorage (XSS exposure)
**Severity:** High

The platform uses a bespoke `access`/`secret` dual-token scheme injected as raw HTTP headers on every API request. Both tokens are stored in `localStorage` — not in `HttpOnly` cookies. Any JavaScript running on the page (including third-party scripts) can read these tokens.

Since all four SPAs (vrtly-home, VPM, VAM, onboarding) share the same origin and the same `localStorage` keys (`user`, `organization`, `locationId`), a single XSS vulnerability in any one app exposes credentials valid across the entire platform.

**Affected:** All four frontend apps via the shared Axios client in `packages/api/request/index.ts`.

---

### S2 — No server-side session invalidation on logout
**Severity:** High

Sign-out only clears localStorage keys locally and calls the logout API endpoint. There is no confirmation of server-side token invalidation visible in the client code. If the access or secret token remains valid on the server, a stolen token continues to work after the user has signed out.

**Affected:** All frontend apps.

---

### S3 — CloudFront private key committed to source repository
**Severity:** Critical

`src/main/resources/private_key.pem` and `prod_private_key.pem` are checked into the `fmcom-player-api` repository. These RSA private keys are used to sign CloudFront URLs for all content delivery to devices. Anyone with read access to the repository can generate valid signed URLs for any content asset.

**Affected:** `fmcom-player-api`.

---

### S4 — Device request signing uses SHA-1 (cryptographically deprecated)
**Severity:** Medium

The `html5core` player app authenticates device API requests by computing `SHA-1(serialNumber + timestamp)` with a 300-second replay window. SHA-1 is deprecated for authentication use cases and is considered cryptographically weak. The replay window means a captured request can be reused for up to 5 minutes.

**Affected:** `html5core` → `fmcom-player-api`.

---

### S5 — AES-CBC encryption key stored in memory only, lost on reload
**Severity:** Medium

The AES-CBC key used to decrypt `fmcom-player-api` responses is itself double-encrypted using the hardcoded string `'friendmediamedia'` as both key and IV. The decrypted key is stored only in Pinia memory — lost on page reload, requiring re-registration. The hardcoded encryption seed is visible in source.

**Affected:** `html5core`.

---

### S6 — Unauthenticated HLS streaming endpoint
**Severity:** Medium

The endpoint `/player/content/stream/{store}/{id}/{res}/{filename}.m3u8` in `fmcom-player-api` is explicitly excluded from all security and session interceptors. This endpoint rewrites HLS master playlists as part of ABR mitigation and is publicly reachable without credentials. CloudFront signed URL protection is absent on this path.

**Affected:** `fmcom-player-api`.

---

### S7 — Cross-app token sharing via shared localStorage origin
**Severity:** Medium

Auth tokens and org state are shared across all four SPAs via `localStorage` keys with fixed names. All apps run under the same origin. A compromised third-party script loaded by any one app can read the tokens used by all others. There is no per-app token scoping or isolation.

**Affected:** All frontend apps.

---

### S8 — `state-service` has no HTTP security layer — all endpoints are unauthenticated within the VPC
**Severity:** High

`SecurityConfig.java` in `state-service` declares only a `BCryptPasswordEncoder` bean. There is no `WebSecurityConfig` or `SecurityFilterChain` configured. Every endpoint — including `/auth/authorize`, `/screen/create`, `/broker/consume`, `/broker/publish`, and `/elasticsearch/limit/max` — is unauthenticated at the HTTP layer. Any host with network access to the ECS task (any service inside the VPC, or a developer machine with VPN access) can read or mutate screen state, issue auth tokens, inject messages into the broker, or override Elasticsearch quota limits. The service's own design doc (`doc/scheduler-design.md`) lists this absence of a `SecurityFilterChain` as a blocking gap before a scheduler admin UI can be implemented.

**Affected:** `state-service`.

---

### S9 — Amazon MQ broker credentials committed in plaintext in dev and QA task definitions
**Severity:** High

`dev-task-definition.json` and `qa-task-definition.json` in both `reach-n-feq` and `state-service` contain `BROKER_USER: "devops"` and `BROKER_PASSWORD: "aAhuX2RbTJGp5ZksRA7JX8Vtm"` as plaintext environment variables, matching the defaults in each service's `application.yml`. These task definitions are committed to version control. Dev and QA use the same physical Amazon MQ broker endpoint (`ssl://b-451110d0-....mq.us-west-2.amazonaws.com:61617`) as production. Any developer with repository access or ECS console access can use these credentials to connect to the broker and publish or consume any JMS queue or topic, including `ALL_USER_ACCESS_CHANGED`, `RNF_GENERATE`, and `API_CONTENT_ADD`. Production correctly uses SSM Parameter Store secrets.

**Affected:** `reach-n-feq`, `state-service`.

---

### S10 — `AuthService.AUTH_RESULT` is a `ThreadLocal` on an interface — latent auth context leakage
**Severity:** Medium

`AuthService.AUTH_RESULT = new ThreadLocal<>()` is declared as a static field directly on the `AuthService` interface in `fm-common`. If this `ThreadLocal` is not explicitly cleared after use in a thread-pool context (e.g., the `asyncExecutor` in `state-service`, the Spring MVC request thread in any service), it will carry authenticated user state from one request to the next request processed by the same thread. In services that reuse threads across different organizational tenants, this is a latent privilege escalation vector. No `remove()` call was observed in the auth filter path during the spikes.

**Affected:** `fmcom-api`, `fmcom-player-api`, `state-service` (all services using `AuthModule` from `fm-common`).

---

### S11 — Fastjson 1.2.83 is a transitive dependency of `fm-common` consumed by all backend services
**Severity:** Medium

`fm-common` depends on `com.alibaba:fastjson:1.2.83`. Fastjson has a well-documented history of critical remote code execution CVEs. Version 1.2.83 was a security-focused patch release in 2022 and is now over three years old. Any CVE discovered in Fastjson after 1.2.83 would affect all four backend services simultaneously, since they all consume `fm-common` as a compile-time dependency. The library cannot be easily removed: domain entity methods call `JSONObject` directly in `cmsInfo()` / `adminInfo()` implementations.

**Affected:** `fmcom-api`, `fmcom-player-api`, `reach-n-feq`, `state-service` (all `fm-common` consumers).

---

## Reliability Risks

### R1 — Stripe subscription tier relies on polling, no error on timeout
**Severity:** Medium

After a Stripe subscription change, the VPM subscription store polls the backend every 750ms for up to 60 seconds waiting for a Stripe webhook to reconcile the tier. If the webhook is delayed or dropped, the UI proceeds with stale tier data. There is no user-visible error on timeout and no documented manual reconciliation process.

**Affected:** `fmcom-vrtly-fe-monorepo` (VPM), `fmcom-api`.

---

### R2 — In-memory session store is not horizontally safe
**Severity:** High

`fmcom-player-api` holds WebSocket device sessions in an in-memory `SessionHolder` / `WsSessionHolder`. When running multiple ECS task replicas, HTTP requests can land on a node that does not hold the device's WebSocket connection. Cross-node WebSocket pushes are silently queued in `unsentNotice` and never delivered. Correct operation requires sticky sessions (ALB session affinity) or acceptance of silent message loss.

**Affected:** `fmcom-player-api`.

---

### R3 — Separate deployment pipelines, no atomic rollout
**Severity:** Medium

Each of the four SPAs is deployed independently via separate Bitbucket Pipeline steps. A breaking API contract change deployed to the backend while only some SPAs have been updated creates a partial-deployment window where some frontend apps are broken. There is no coordinated rollout mechanism.

**Affected:** `fmcom-vrtly-fe-monorepo`, `fmcom-api`.

---

### R4 — Shared MySQL database with independent Liquibase migrations
**Severity:** High

`fmcom-api` and `fmcom-player-api` share a single MySQL RDS instance (`fm_store`) and each runs Liquibase schema migrations independently. A schema change deployed by one service can break the other before it is updated. There is no documented coordination process or migration compatibility matrix.

**Affected:** `fmcom-api`, `fmcom-player-api`.

---

### R5 — XXL-Job admin is a single point of failure for all scheduled tasks
**Severity:** Medium

Both `fmcom-api` (15+ jobs: Stripe sync, social sync, ad slot generation, transcription repair, etc.) and `fmcom-player-api` (telemetry cleanup) register jobs with a single shared XXL-Job admin server at `https://jobs.prod.vrtly.app/job-admin/`. If this server is unavailable, all scheduled tasks across both services stop running.

**Affected:** `fmcom-api`, `fmcom-player-api`.

---

### R6 — Feature flags are cached indefinitely with no invalidation
**Severity:** Low–Medium

`useFeaturesStore.getFlags` is wrapped in `useMemoize`, meaning feature flags are fetched once per session and cached indefinitely. If flags change server-side, no update reaches the client until a hard reload. There is no TTL or push-based invalidation mechanism.

**Affected:** `fmcom-vrtly-fe-monorepo` (VPM, VAM).

---

### R7 — Player postMessage communication silently gives up after 3 retries
**Severity:** Low

`usePlayerCommunication` in VPM and VAM sends content to the embedded `html5core` iframe via `postMessage`, retrying up to 3 times at 500ms intervals. If the iframe never responds with `RECEIVE_CONTENT`, the system gives up with only a `console.warn`. There is no user-facing error.

**Affected:** `fmcom-vrtly-fe-monorepo` (VPM, VAM).

---

### R8 — `state-service` is a single point of failure for screen state, authentication, ES quota, and broker relay
**Severity:** High

`state-service` owns four platform-critical capabilities simultaneously: (1) the authoritative in-memory registry of all screen state, (2) the sole auth token issuer and verifier for both users and devices, (3) the Elasticsearch query budget coordinator that broadcasts limits to all services, and (4) the in-process JMS broker proxy used by `fmcom-player-api`. An outage of this single service causes: all screen lookups to fail (cached in `fmcom-api` only until TTL), all auth verification to fail, all services to fall back to their minimum ES quota (1 query/instance in dev, 3 in prod), and player-api broker messaging to stall. There is no circuit-breaker configured on `ScreenStateClient` in `fm-common`. The service has no redundancy strategy documented beyond ECS task restarts.

**Affected:** `fmcom-api`, `fmcom-player-api`, `reach-n-feq`, `state-service`.

---

### R9 — `reach-n-feq` calls `System.exit(-1)` on a state-service ping failure — kills in-flight transcodes
**Severity:** High

`FeignConfig.connectionCheck()` in `reach-n-feq` runs on a 1-minute `@Scheduled` timer and calls `System.exit(-1)` if the `InstanceStateClient.ping()` call to `state-service` fails. A transient network hiccup, state-service rolling deployment, or ECS health-check flap will terminate the RNF JVM entirely. Any in-flight video transcode is immediately interrupted; the shutdown hook marks claimed rows as `FAILED`. ECS will restart the container, but re-transcode of failed items requires manual intervention. There is no retry, no backoff, and no monitoring differentiation between transient and permanent unavailability.

**Affected:** `reach-n-feq`.

---

### R10 — Screen state authority is split: `fmcom-api` can bypass `state-service` and write directly to MySQL
**Severity:** High

`state-service` holds the authoritative in-memory `ConcurrentHashMap` of all screen state, serving all reads from memory without touching MySQL. However, `fmcom-api` also imports `MySqlScreenModule` from `fm-common` and has a direct JPA connection to the same `screen` table. Any write `fmcom-api` makes directly to MySQL bypasses the in-memory cache in `state-service`. The cache will then serve stale data until the next eviction or cache miss triggers a reload. There is no write-path enforcement at the network or DB level, and no documented policy about which writes must route through `state-service` and which may go direct.

**Affected:** `fmcom-api`, `state-service`.

---

### R11 — `state-service` in-process broker delivers at-most-once and silently evicts clients after 5 minutes of inactivity
**Severity:** Medium

`BrokerServiceImpl` in `state-service` implements the JMS broker entirely in heap memory. Message state is only persisted to Elasticsearch during a clean `stop()` call — a SIGKILL or OOM-kill loses all undelivered messages with no recovery path. Additionally, `BrokerServiceImpl.cleanup()` evicts `ClientDetails` after 5 minutes of inactivity. A `fmcom-player-api` pod that is quiet for 5 minutes (pod restart, GC pause, network blip) will have its topic offsets reset and silently miss all messages delivered during the gap. The broker's delivery guarantee is at-most-once, but callers may assume at-least-once behavior given that the design deliberately mirrors ActiveMQ semantics.

**Affected:** `state-service`, `fmcom-player-api`.

---

### R12 — `reach-n-feq` is the sole executor for all video transcoding and PDF conversion — no redundancy
**Severity:** High

`reach-n-feq` runs a single `UnifiedVideoPipeline` with three thread pools (download, transcode, upload) that process every video transcode and PDF-to-image conversion job on the platform. Content cannot be delivered to screens until it has been transcoded. The pipeline depends on a shared EFS volume at `/mnt/efs` for staging; EFS unavailability causes the entire pipeline to stop. The `prod-perf` ECS service appears to be a separate bulk-transcoding instance but operates independently and is not documented as a failover. There is no hot standby, no job queue dead-letter mechanism, and no documented runbook for a transcoding backlog.

**Affected:** `reach-n-feq`, all content delivery to devices.

---

## Code Quality Risks

### Q1 — VPM and VAM have zero unit tests
**Severity:** High

The most complex app in the monorepo (VPM, v4.12.0) and VAM have no test files whatsoever. The only tests in the codebase are 8 component tests in `apps/onboarding` and unit tests in `packages/utils`. Changes to VPM or VAM cannot be validated automatically before deployment.

**Affected:** `fmcom-vrtly-fe-monorepo`.

---

### Q2 — Duplicate Axios request clients
**Severity:** Medium

There are two near-identical Axios instances: the shared client in `packages/api/request/index.ts` and a legacy per-app client in each app's `src/utils/request.ts`. Bug fixes, interceptor changes, and token refresh logic must be applied in multiple places. VPM's local API files use the app-local client while most other calls use the shared one.

**Affected:** `fmcom-vrtly-fe-monorepo`.

---

### Q3 — `fm-common` version skew spans three backend services with no compatibility matrix
**Severity:** Medium–High

The four backend services run on three different `fm-common` versions: `reach-n-feq` at `8.9.1` (current source), `fmcom-api` at `8.9.0`, `fmcom-player-api` at `8.8.9`, and `state-service` at `8.7.8`. This shared internal library defines JMS payload types, Elasticsearch index names, Redis key constants, domain entity fields (`ScreenDto`, `AuthTokenDto`), and Feign client interfaces exchanged at runtime between services. A field present in `8.9.x` but absent in `8.7.8` is silently dropped on deserialization at the `state-service` end. There is no compatibility matrix, no CHANGELOG, and no integration test visible in any CI pipeline that validates cross-version message exchange. Upgrading `state-service` from `8.7.8` to `8.9.1` requires careful diff analysis to assess what 16 patch-to-minor versions may have changed in shared DTOs.

**Affected:** `fmcom-api`, `fmcom-player-api`, `reach-n-feq`, `state-service`.

---

### Q4 — Redis key collision risk between services
**Severity:** Medium

`fmcom-api` and `fmcom-player-api` share a Redis ElastiCache cluster. Redis key constants are defined in `fm-common`, and the two services use different logical database indexes (DB 4 dev / DB 2 prod for player-api; default for fmcom-api). If namespacing is not consistently enforced in `fm-common`, key collisions between services are possible.

**Affected:** `fmcom-api`, `fmcom-player-api`.

---

### Q5 — Monorepo build is a stub
**Severity:** Low

The root `package.json` `build` script contains only `echo 'TODO: create consolidated monorepo build'`. There is no unified build artifact. Each app is built and deployed independently, which is operationally correct today but means the monorepo's primary promise is undelivered.

**Affected:** `fmcom-vrtly-fe-monorepo`.

---

### Q6 — `layout.js` is not TypeScript in an otherwise typed codebase
**Severity:** Low

`apps/vrtly-practice-manager/src/store/layout.js` is a plain JavaScript file. This bypasses type checking for the layout store, which controls Intercom visibility and navigation state across VPM.

**Affected:** `fmcom-vrtly-fe-monorepo` (VPM).

---

### Q7 — `GooglePlaceInput.vue` is duplicated across apps
**Severity:** Low

The Google Places address autocomplete component is duplicated in both `apps/vrtly-practice-manager/src/pages/setting/components/` and `apps/onboarding/src/components/`. Bug fixes or API changes must be applied in both places.

**Affected:** `fmcom-vrtly-fe-monorepo`.

---

## Architecture / Infrastructure Risks

### A1 — `SPONSOR` org routing is client-side only
**Severity:** Medium

When a SPONSOR organization hits the VPM root, they are redirected to `/brands` (VAM) based on `organization.type` read from `localStorage`. This check is entirely client-side. If the localStorage value is stale or tampered with, a SPONSOR user can access provider-facing routes. There is no server-side enforcement visible in the frontend codebase.

**Affected:** `fmcom-vrtly-fe-monorepo`.

---

### A2 — Onboarding step gate is client-side only
**Severity:** Medium

VPM redirects mid-onboarding organizations to `/onboarding` for most routes, based on `onboarding.step` values in localStorage. Whether the backend enforces onboarding completion (e.g., returning 403 for mid-onboarding orgs) is not visible from the frontend codebase.

**Affected:** `fmcom-vrtly-fe-monorepo`.

---

### A3 — `rnf` (playlist resolver / SOV engine) is a critical dependency with a hard-exit failure mode
**Severity:** High *(gap resolved — see tech-spike-rnf.md; risk re-rated based on findings)*

`reach-n-feq` is now fully analyzed. It owns playlist generation, Share-of-Voice enforcement, all video transcoding, PDF-to-image conversion, analytics reporting, and Salesforce CRM sync. A `rnf` outage stops playlist delivery to all devices, blocks all content transcoding, and stalls all analytics jobs. The most operationally dangerous design decision is the `System.exit(-1)` on state-service ping failure (see R9): a transient state-service issue causes RNF to kill itself, compounding an outage cascade across both critical services simultaneously. `rnf` is also the publisher of `API_CONTENT_ADD` after transcoding — an RNF outage silently halts content lifecycle propagation to `fmcom-api`.

**Affected:** `fmcom-api`, `fmcom-player-api`, `reach-n-feq`, all display devices.

---

### A4 — Non-standard auth scheme complicates security tooling and audits
**Severity:** Medium

The bespoke `access`/`secret` header scheme is not compatible with standard OAuth 2.0 tooling, API gateways, or security scanners that expect `Authorization: Bearer`. This makes third-party security audits, WAF configuration, and future API gateway integration more complex. It also makes it harder to reason about token expiry and scope.

**Affected:** All services.

---

### A5 — No production environment config visible in the repository
**Severity:** Low–Medium

Only `.env.development` files are committed. Production API URLs and CloudFront distribution IDs are injected at pipeline time as Bitbucket deployment variables. Production configuration is not reviewable from the codebase, which complicates incident response and environment parity analysis.

**Affected:** `fmcom-vrtly-fe-monorepo`.

---

### A6 — `fm-common` is a monolithic shared library with no module-level versioning — a single breaking change requires simultaneous redeployment of all services
**Severity:** High

All four backend services are coupled to `fm-common` as a single compiled JAR. There is no module-level API contract, no CHANGELOG, and no mechanism to have two services on different `fm-common` minor versions at runtime. A bug or breaking change introduced in any part of the library — a renamed `ScreenDto` field, a changed JMS payload type, a new Liquibase migration in the Elasticsearch module — requires a coordinated upgrade and simultaneous deployment across all consumers. Rolling updates are not possible while `fm-common` is changing. The library also owns the Liquibase master changelog, meaning a schema migration in `fm-common` cannot be applied independently by a single service. This is the single highest-risk coupling in the backend architecture from a change-management perspective.

**Affected:** `fmcom-api`, `fmcom-player-api`, `reach-n-feq`, `state-service`.

---

### A7 — `state-service` rolling deployment has two data-loss windows with no documented runbook
**Severity:** Medium–High

`state-service` has two structural hazards during every rolling deployment:

1. **Screen state flush:** `DeploymentServiceImpl.start()` calls `stateFeignClient.deploymentStart()` targeting the load balancer URL. If the new instance has not yet passed ECS health checks or DNS is slow to propagate, this self-call fails silently — the previous instance does not flush its dirty in-memory screen state to MySQL, and those updates are lost.

2. **Broker state hand-off:** `BrokerServiceImpl.stop()` calls `stateFeignClient.update(state)` to replicate in-memory broker state to the new instance via the load balancer. During a rolling deployment the call may land on the stopping instance itself (HTTP 200 returned, state not replicated) — the Elasticsearch fallback only fires on Feign failure, so a routing miss causes silent broker state loss.

Both failures are hard to detect without CloudWatch log correlation and have no documented mitigation or runbook.

**Affected:** `state-service`, `fmcom-player-api`.

---

## Open Questions for Client

The following risks have ambiguous ownership or require client clarification before DBP can assess scope:

| # | Question | Related risk |
|---|---|---|
| OQ1 | Is there a plan to migrate auth tokens from localStorage to HttpOnly cookies? | S1, S2 |
| OQ2 | ~~Who owns the `rnf` service?~~ *Resolved — fully spiked.* What is the intended SLA and the documented runbook for RNF outages (especially the `System.exit(-1)` failure cascade)? | A3, R9 |
| OQ3 | Are ALB sticky sessions configured for `fmcom-player-api` ECS tasks? | R2 |
| OQ4 | Has the committed CloudFront private key (`private_key.pem`) been rotated? | S3 |
| OQ5 | Is the Stripe webhook polling timeout (60s) a known operational issue? | R1 |
| OQ6 | Is there server-side enforcement of onboarding step completion and SPONSOR/PROVIDER routing? | A1, A2 |
| OQ7 | What is the process for coordinating `fm-common` version upgrades across services? Is there a compatibility test? | Q3, A6 |
| OQ8 | Is there a plan or timeline to add a `SecurityFilterChain` to `state-service`? The scheduler design doc lists this as a blocking prerequisite. | S8 |
| OQ9 | Have the plaintext broker credentials in dev/QA task definitions (`BROKER_USER: devops`, `BROKER_PASSWORD: aAhuX2RbTJGp5ZksRA7JX8Vtm`) been rotated or moved to SSM? | S9 |
| OQ10 | Is the screen write authority boundary documented? Which writes legitimately bypass `state-service` and go directly to MySQL, and how is cache coherence maintained in those cases? | R10 |
| OQ11 | Is `fmcom-player-api` aware that the in-process broker delivers at-most-once? Are there player-side retry or deduplication mechanisms for missed broker messages? | R11 |
| OQ12 | Is the `prod-perf` ECS service for `reach-n-feq` a permanent parallel environment or an ad-hoc bulk-transcoding instance? What is the access control policy for triggering bulk re-transcodes? | R12 |
