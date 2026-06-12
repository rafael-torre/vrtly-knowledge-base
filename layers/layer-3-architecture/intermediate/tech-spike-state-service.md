---
title: "Tech Spike — State Service (Screen State Service)"
last_updated: 2026-06-12
---

# Tech Spike: State Service (Screen State Service)

## What This Service Does

The state service (`state-service`) is a purpose-built stateful service that acts as the **authoritative screen registry and in-process message broker** for the Vrtly digital-signage platform. It is not a thin data proxy — it owns two distinct, mission-critical capabilities that would otherwise require external infrastructure:

**1. Screen state authority.** The service holds the complete, live snapshot of every `Screen` entity in a JVM-resident `ConcurrentHashMap`. Reads return from memory in microseconds; writes are applied in-memory immediately (with optional deferred persistence) and flushed to MySQL on a 1-minute schedule or on demand when a deployment is signaled. All other services that need screen data — `fmcom-api`, `fmcom-player-api`, the RNF service — call this service via Feign clients (`ScreenStateClient`, `InstanceStateClient` from `fm-common`) rather than querying MySQL directly. This makes state-service the **single source of truth for screen state at runtime**.

**2. In-process JMS broker.** The service implements a lightweight publish/subscribe and queue broker entirely in-memory using `ConcurrentHashMap` and `ConcurrentLinkedQueue`. Other services (player-api in particular) connect to this broker via HTTP long-poll rather than directly to Amazon MQ. The broker persists its message state to Elasticsearch on shutdown and restores it on startup, providing durable messaging without relying on ActiveMQ for player-to-platform communication.

Beyond these two core roles, the service also owns:

- **Authentication and token management** for both organization users and patients, using a custom token model stored in MySQL (not Redis). It issues access + secret token pairs, verifies them, handles refresh, and broadcasts `UserAccessChangedMessage` on every auth event over JMS so all services stay in sync.
- **Elasticsearch concurrency governance**: state-service is the designated coordinator that receives instance registration / unregistration / backlog / performance-failure events from all services over JMS, computes per-instance query budget allocations, and broadcasts `ElasticsearchLimitsAllocated` messages back to all registered instances.
- **Deployment signaling**: a `DeploymentService` lifecycle component that, on startup, calls `/deployment/start` on itself (via `StateFeignClient`) to flush any dirty in-memory screen state to MySQL immediately, preventing data loss across rolling deployments.
- **Future job scheduler host** (design proposal in `doc/scheduler-design.md`): the doc describes a design to retire XxlJob by making state-service the distributed cron coordinator, dispatching jobs to executors in other services over JMS via a new `@JobHandler` annotation registered through `fm-common`.

The service runs on port **9092** and is reachable at `state.dev.vrtly.app` / `state.prod.vrtly.app`. It is deployed on AWS ECS (EC2 launch type) in an `awsvpc` network.

---

## Tech Stack & Key Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| Spring Boot | 3.3.2 | Core web framework (Jakarta EE namespace) |
| Java | 17 | Runtime |
| Spring Data JPA + Hibernate | Boot-managed | ORM for MySQL; `open-in-view: false` (correct setting) |
| MySQL Connector/J | 9.6.0 | JDBC driver for MySQL |
| Liquibase | 4.26.0 | Schema migration management; master changelog in `fm-common` |
| Spring Data Redis | Boot-managed | Provides `RedisTemplate<String, Object>`; used by `fm-common` `RedisServiceModule` (auth cache, lock service) |
| Spring Cloud OpenFeign | 2023.0.3 (via BOM) | `StateFeignClient` — self-call for deployment signaling; `fm-common` Feign clients for upstream |
| Spring ActiveMQ | Boot-managed | JMS producer/consumer for inter-service messaging (Amazon MQ broker) |
| MapStruct | 1.5.5.Final | Compile-time DTO/entity mappers (`ScreenMapper`, `PermissionMapper`) |
| Lombok | Boot-managed | Boilerplate reduction |
| jackson-datatype-jsr310 | Boot-managed | JSR-310 (`java.time`) serialization support for Jackson |
| `fm-common` | 8.7.8 | Internal shared library from AWS CodeArtifact; provides all `MySql*Module`, Elasticsearch modules, JMS constants + messaging service, Redis modules, `ScreenStateClient`/`InstanceStateClient`, throttle service, system param service, Salesforce notification, organization-user-login module |
| Spring Boot Actuator | Boot-managed | Full health/metrics endpoints (`management.endpoints.web.exposure.include: '*'`) |
| Spring Boot Validation | Boot-managed | Bean validation (`@Valid`, `@Size`) on controller parameters |
| H2 | Boot-managed (test scope) | In-memory DB for unit tests |
| Maven Checkstyle Plugin | 3.3.0 | Enforced style rules on `validate` phase (`failOnViolation: true`) |
| Checkstyle | 10.10.0 | Style ruleset engine |
| Spring Boot Security | Boot-managed (transitive) | `BCryptPasswordEncoder` bean; no `SecurityFilterChain` defined — all endpoints are effectively open |

---

## Main Modules / Packages

| Package | Purpose |
|---|---|
| `ai.vrtly.state` (root) | `StateServiceApplication` — standard Spring Boot entry point; no `@EnableFeignClients` here (delegated to `BasicConfig`) |
| `config` | `BasicConfig` — wires JPA entity scan, JPA repo scan, Feign client scan all scoped to `ai.vrtly.state.*`; `ImportConfig` — explicit `@Import` of ~30 `fm-common` modules; `RedisConfig` — `RedisTemplate<String, Object>` bean; `SecurityConfig` — `BCryptPasswordEncoder` bean only; `SchedulingConfig` — `@EnableScheduling`; `AsyncConfig` — `ThreadPoolTaskExecutor` (core 4, max 16, queue 500) named `asyncExecutor`; `WebConfig` — MVC customization |
| `web` | REST controllers: `ScreenController`, `InstanceController`, `BrokerController`, `DeploymentController`, `AuthController`, `ElasticsearchLimitController`, `AdviceController` (global exception handler). HTTP scratch files for local testing also live here. |
| `service/screen` | Core screen subsystem: `ScreenStateService` (interface + `SmartLifecycle`), `ScreenExtendedService` (interface), `ScreenPersistenceService` (interface), and their implementations in `impl/` |
| `service/impl` | `AuthServiceImpl` — full auth lifecycle including token CRUD, role + permission loading, JMS broadcast on every auth event; `DeploymentServiceImpl` — `SmartLifecycle` that signals other services on startup/stop |
| `service/jms` | `BrokerService` interface + `BrokerServiceImpl` — the in-process message broker (queues + topics + client offsets); `BrokerConversionUtils` — Elasticsearch serialization/deserialization for broker state snapshots |
| `service/elasticsearch` | `ElasticsearchLimitAllocator` — per-instance concurrency budget calculator; `ElasticsearchLimitCoordinatorService` — JMS listener/publisher driving the allocation protocol; `ElasticsearchLimitInitializer` — `@PostConstruct` seeding of system params; `ElasticsearchPerformanceFailureHandler` — reactive budget decrease on heap/disk pressure; `ElasticsearchServiceWeightsProvider` — service-level weight table for allocation |
| `service/mapper` | `ScreenMapper` (MapStruct) — `MySqlScreen` to/from `ScreenDto`; `PermissionMapper` (MapStruct) — `MySqlUserPermission` to/from `PermissionDto` |
| `feign` | `StateFeignClient` — Feign client pointing at `${service.discover.state}` (itself in production) for deployment-start self-call and screen update relay; `BrokerStateClientImpl` — implements `fm-common`'s `BrokerStateClient` interface by delegating to `BrokerService` |
| `model/mysql` | Local JPA entities not in `fm-common`: `MySqlUserDetails` (simplified `user` table projection), `MySqlUserToken` (`user_token` table), `MySqlPatient` (patient auth), `Authenticatable` (interface) |
| `model/dto` | `BrokerStateDto` — transfer object for broker state replication (queues, topics, client offsets) |
| `model/projection` | Spring Data projections for complex queries: `ScreenAndOffset`, `ScreenDetailsProjection`, `ScreenIdProjection`, `ScreenIdDeviceGroupAndPaidProjection`, `DateDeviceGroupCountProjection`, `YearWeekDeviceGroupCountProjection`, `UserTokenAccessProjection` |
| `repository` | `ScreenRepository` (JPA, 50+ query methods); `UserDetailsRepository`, `UserTokenRepository`, `PatientRepository`, `RoleRepository`, `UserRoleRepository`, `UserPermissionRepository` |
| `service` (base) | `SyncOpService<T>` — per-key mutex primitive using `ConcurrentHashMap` + `synchronized(locks)` + `wait/notifyAll`; `DeploymentSupportService` — interface with static `AtomicBoolean deployment` shared across all service implementations |
| `exception` | `TableLockTimeoutException` — wraps `MySQLTransactionRollbackException` from MySQL lock timeouts; `AuthErrors` — static `AuthTokenDto` constants for error responses |
| `util` | `AsyncExecutorUtil` — static accessor for the `asyncExecutor` thread pool; `SortUtils` — Spring `Sort` parser |

---

## External Integrations

| Integration | Mechanism | Direction | Notes |
|---|---|---|---|
| **Amazon MQ (ActiveMQ)** | Spring JMS (`ssl://b-451110...mq.us-west-2.amazonaws.com:61617`), via `fm-common` `JmsModule` + `MessagingService` | Bidirectional | Outbound: publishes `UserAccessChangedMessage` on `Destinations.ALL_USER_ACCESS_CHANGED` on every auth event; publishes `ElasticsearchLimitsAllocated` on `Destinations.ELASTICSEARCH_LIMITS_ALLOCATED`. Inbound: subscribes to `ELASTICSEARCH_INSTANCE_REGISTERED`, `ELASTICSEARCH_INSTANCE_UNREGISTERED`, `ELASTICSEARCH_QUOTA_REQUEST`, `ELASTICSEARCH_PERFORMANCE_FAILURE`. `BROKER_PREFIX` env var scopes destination names per environment (dev prefix `"dev"`, prod empty). |
| **MySQL** | JPA/Hibernate (`jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}`), Liquibase-managed schema | Outbound (read/write) | Shared `fm_store` DB with all other services. Owns `user_token` table locally; reads `user`, `screen`, `role`, `user_role`, `user_permission`, `organization`, and ~15 other tables via `fm-common` modules. Pool: 10 connections min-idle, 10 max. JPA query timeout 15 s, lock timeout 1 s. `ddl-auto: validate`. |
| **Redis** | Spring Data Redis (database 4 dev, database 2 prod; SSL in non-local envs) | Outbound | Used by `fm-common` `RedisServiceModule` (distributed lock service, `LockService`) and token/session cache. State-service itself does not directly interact with Redis beyond what `fm-common` modules do. |
| **Elasticsearch** | `spring-data-elasticsearch` via `fm-common` modules | Outbound (read/write) | Writes broker state snapshots to `ElasticBrokerMessages` index on shutdown (fallback if self-Feign fails). Reads cluster node stats (disk/JVM) via `ElasticClusterMgmtRepository` for performance-failure handling. Also writes to `ElasticScreenStatusReport` index via `fm-common`. State-service is a registered throttle participant (`service-id: state`, initial-limit: 1 dev / 3 prod). |
| **Self-call via Feign (`StateFeignClient`)** | Spring Cloud Feign pointing at `${SERVICE_DISCOVER_STATE}` (its own public URL) | Outbound (self) | Used in two places: `DeploymentServiceImpl.start()` calls `GET /deployment/start` on itself so that the newly started instance can trigger a flush of dirty screen state from a peer about to stop; `ScreenStateServiceImpl.processRemaining()` calls `POST /screen/update/{screenId}` on itself to relay unflushed cache entries during graceful shutdown. Creates a self-dependency that can fail if the load balancer is not yet ready. |
| **`fmcom-api` and all consumers** | Inbound HTTP (REST) via `fm-common` `ScreenStateClient` / `InstanceStateClient` | Inbound | Callers invoke `/screen/**` endpoints to read and write screen state. `fmcom-api` calls `ScreenStateClient` methods that map to `ScreenController` routes (`getById`, `getByMac`, `create`, `update`, `updateMac`, etc.). `InstanceStateClient` calls `GET /ping` for liveness and `GET /deployment/start` on deployment. |
| **`fmcom-player-api` (broker clients)** | HTTP long-poll via `POST /broker/consume` (up to 22 s hold per request) | Inbound | Player-api instances use `BrokerStateClient` (backed by this service) to publish and consume JMS-like messages without connecting to Amazon MQ directly. Each player-api instance identifies itself with a `clientId`. Topic offsets are tracked per-client in memory. |
| **Amazon ECS / AWS SSM Parameter Store** | Task definition `secrets` block | Deploy-time | DB, Redis, Elasticsearch, and (prod only) broker credentials are injected via SSM Parameter Store at container start. Dev broker URL/credentials remain as plaintext environment variables in the dev task definition. |
| **AWS CloudWatch Logs** | `awslogs` log driver | Outbound | Logs shipped to `/aws/ecs/{env}-vrtly-state/var/log`. |
| **Salesforce** | `fm-common` `SalesforceNotificationServiceModule` | Outbound (conditional) | Called from `ScreenPersistenceServiceImpl.save()` after every screen persist (`salesforceNotificationService.screen(saved.getId())`). Gated by `salesforce.enabled` feature flag inside `fm-common`. |
| **Amazon MQ — ES limit topics** | JMS via `fm-common` `MessagingService`; `@PostConstruct` subscription in `ElasticsearchLimitCoordinatorService` | Inbound | Subscribes on startup to four ES-limit coordination destinations. State-service is the only consumer of these topics; all other services publish to them. |

---

## Key Data Entities / Domain Models

| Entity | Location | Description |
|---|---|---|
| `MySqlScreen` | `fm-common` `MySqlScreenModule` | The physical display device entity. Canonical definition lives in `fm-common`; state-service wraps it with a 50+ method `ScreenRepository` and holds every instance in an in-memory `ConcurrentHashMap<Long, ScreenDto>`. Key fields: `id`, `mac`, `organizationId`, `roomId`, `hardwareType` (`ScreenType`), `contentType` (`ScreenContentType`), `subscription` (`ScreenSubscription`), `deviceGroup` (`DeviceGroup`), `lastDisplay`, `dateActivated`, `dateCreated`, `enabled`, `demo`, `tvStatus`, `sponsorBrandId`, `mode`, `secret`, `ipAddress`, `name`. |
| `ScreenDto` | `fm-common` `common.model.dto` | Wire-format and cache-format representation of a screen. The in-memory cache stores `ScreenDto` objects, not JPA entities, avoiding Hibernate proxy issues. Field-level updates are applied via reflection (`ReflectionUtils.setField`) with `JsonUtils.convert` for type coercion. |
| `MySqlUserDetails` | `ai.vrtly.state.model.mysql` | Local simplified projection of the `user` table (`id`, `email` as `username`, `password`, `removed`, `enabled`, `organizationId`, `lastLogin`). Not the full `fm-common` `MySqlUser`. Used only for authentication in `AuthServiceImpl`. |
| `MySqlUserToken` | `ai.vrtly.state.model.mysql` | `user_token` table. Stores issued access + secret token pairs with `AuthType` (USER or PATIENT), `userId`, `expire`, `created`, `used`. Managed solely by this service; expiry cleanup runs daily at 05:00 UTC. |
| `MySqlPatient` | `ai.vrtly.state.model.mysql` | Patient auth entity. Looked up by `phoneHash` for phone-based authentication (`AuthType.PATIENT`). |
| `BrokerStateDto` | `ai.vrtly.state.model.dto` | Serialization envelope for broker state replication: `Map<String, Queue<String>> queued` (queue snapshots), `Map<String, Queue<String>> topics` (topic snapshots with offset metadata), `Map<String, ClientsBrokerDto> clients` (per-client topic offsets and disconnect flags). Passed via `POST /broker/state` for cross-instance hand-off and stored in Elasticsearch `ElasticBrokerMessages` on shutdown. |
| `ElasticBrokerMessages` | `fm-common` `ElasticBrokerMessagesModule` | Elasticsearch document used as a durable snapshot of broker state across restarts. Written when `BrokerServiceImpl.stop()` cannot reach its own Feign endpoint; read and deleted on `BrokerServiceImpl.start()`. |
| `ElasticScreenStatusReport` | `fm-common` `ElasticScreenStatusReportModule` | Elasticsearch index for screen status event history; imported by `ImportConfig`. |
| `MySqlOrganization` | `fm-common` `MySqlOrganizationModule` | Organization entity (PROVIDER / BRAND / INVENTORY). Referenced by `ScreenRepository` queries for join-based filters (status, demo, customerType, whiteLabelId). Not owned or mutated by state-service. |
| `MySqlRoom`, `MySqlOrganizationAddress` | `fm-common` | Joined in `findAllByEnabledIsTrueAndDemoIsFalse` and `selectAddressesByScreenIdIn` queries to produce `ScreenOrganizationRoomDto` and `ScreenOrganizationAddressRoomDto` projections. |
| `MySqlAdCampaignScreen` | `fm-common` `MySqlAdCampaignScreenModule` | Imported to support `selectAllByAdCampaignId` — returns screens assigned to a given ad campaign. |
| `MySqlScreenBrand` | `fm-common` (referenced via `ScreenRepository` JPQL) | Join table between screens and sponsor brands. Used in brand-scoped screen-ID queries (`selectScreenIdsByBrandId`, `selectIdsByBrandIdAndStatusIn...`). |
| `MySqlSystemParam` | `fm-common` `SystemParamServiceModule` | Key-value system configuration table. Stores `ELASTICSEARCH_MAX_CONCURRENT_QUERIES` and `ELASTICSEARCH_MIN_SHARE_PER_INSTANCE` which are read/written at runtime by the ES limit subsystem. |
| `ScreenDetailsProjection` | `ai.vrtly.state.model.projection` | Custom Spring Data projection returned by the `getScreenDetails` query. Combines screen fields, organization feature flags (`orgFeatures`), room name, screen settings (`telemetryExtInterval`, `failedPayment`, `enableStallDetection`), a computed `paid` boolean (complex `CASE WHEN` logic), `contentType`, `subscription`, `mode`, and `utcOffset`. Used by `GET /screen/config/{screenId}`. |

---

## Notable Patterns, Risks & Observations

**1. State-service is the authoritative screen registry — MySQL is the backing store, not the runtime source of truth**
`ScreenStateServiceImpl` holds every `ScreenDto` in a `ConcurrentHashMap<Long, ScreenDto>`. On every `GET /screen/id/{id}` or `GET /screen/mac/{mac}`, the service returns from this map without touching MySQL. MySQL is only consulted on first access (cache miss) and written on a 1-minute deferred flush of dirty entries. `fmcom-api` also imports `MySqlScreenModule` directly into its own `ImportConfig`, giving it raw JPA access to the same `screen` table. Any write `fmcom-api` makes directly to MySQL bypasses the in-memory cache in state-service, creating a divergence between what state-service serves and what is on disk. There is no write-path enforcement at the network or DB level. The split is the authority boundary ambiguity identified as an open question in the system map.

**2. The in-memory screen cache has no size bound and no eviction policy**
The `ConcurrentHashMap<Long, ScreenDto> cache` and `Map<String, Long> macIds` grow without limit as screens are loaded. There is no LRU, TTL, or max-size policy. In a production environment with thousands of screens, a cold-start (e.g., crash + restart) triggers a wave of MySQL lookups that populates the entire cache into heap. No monitoring of cache size is apparent in the codebase. This is a hidden OOM risk at scale.

**3. `SyncOpService` uses a shared monitor for all screen-ID locks — global bottleneck under concurrent writes**
`SyncOpService<T>` maintains a `Set<Long> locks` and blocks callers with `locks.wait()` until the target key is removed. All operations for all screen IDs share a single `synchronized(locks)` monitor. A long-running `persistenceService.save()` for one screen ID blocks the lock acquisition of any other screen ID for the duration. Under high-throughput update bursts (e.g., the player fleet updating `lastDisplay` on thousands of screens), this is a global serialization point. A `ConcurrentHashMap<Long, Object>` with per-key `synchronized(lockObject)` would eliminate this contention without changing semantics.

**4. Deployment self-call via Feign creates a startup ordering hazard**
`DeploymentServiceImpl.start()` (a `SmartLifecycle`) immediately calls `stateFeignClient.deploymentStart()` which resolves to `https://state.*.vrtly.app/deployment/start` — the load balancer URL for this same service. If the newly started ECS instance has not yet passed health checks, or if DNS propagation is slow, this self-call may fail. The failure is caught and logged but not retried, meaning the previous instance does not get the flush signal and its dirty screen state may be lost between deployments. This is a data-loss window on every rolling deployment.

**5. No `SecurityFilterChain` — all endpoints are publicly accessible within the VPC**
`SecurityConfig.java` declares only a `BCryptPasswordEncoder` bean. There is no `WebSecurityConfig` or `SecurityFilterChain`. Every endpoint — including `/auth/authorize`, `/screen/create`, `/broker/consume`, `/broker/publish`, and `/elasticsearch/limit/max` — is unauthenticated at the HTTP layer. Security relies entirely on network-level VPC isolation. Any host with network access to the ECS task can read or mutate screen state, modify ES budget limits, or impersonate any other service. The `doc/scheduler-design.md` calls this out explicitly as a blocking gap that must be resolved before the scheduler admin UI can be implemented.

**6. The in-process message broker provides at-most-once delivery — silent message loss on ungraceful shutdown**
`BrokerServiceImpl` implements its broker entirely in heap memory. If state-service is OOM-killed or receives SIGKILL, all undelivered topic messages and unread queue entries are lost. The Elasticsearch fallback snapshot is only attempted during a clean `stop()` call — it does not run on a crash. The design accepts this risk in exchange for the operational simplicity of not routing player-api through Amazon MQ directly.

**7. Broker state replication via Feign self-call is fragile during rolling deployments**
During `BrokerServiceImpl.stop()`, the service calls `stateFeignClient.update(state)` on `POST /broker/state` — targeting the load balancer URL. During a rolling deployment, the call may land on the stopping instance itself rather than the newly started one, leaving broker state unreplicated. The Elasticsearch fallback runs only on Feign failure, so silent routing to the wrong instance (HTTP 200 returned but state not replicated) would cause loss without triggering the fallback. This is structurally the same hazard as observation 4.

**8. `AuthServiceImpl` broadcasts a JMS message on every auth event — async executor queue is the only backpressure**
Every auth operation (`authorize`, `verify`, `refresh`, `upgrade`, `logout`, `logoutAll`) calls `AsyncExecutorUtil.detach(() -> messagingService.send(...))`. The async executor is configured with a queue capacity of 500. Under a high-concurrency auth storm (e.g., player fleet reconnecting after an MQ outage with thousands of simultaneous verify calls), the queue saturates and the default `AbortPolicy` silently drops subsequent dispatch attempts. Downstream services that rely on `ALL_USER_ACCESS_CHANGED` to invalidate cached tokens will miss those notifications without any error surfaced to the caller.

**9. `ScreenExtendedServiceImpl` always hits MySQL even when data is in cache**
Most list queries follow the pattern: query MySQL, map to DTO, then call `this.update(dto)` which replaces the result with the cached version if one exists. MySQL is always hit regardless of cache state. This doubles the DB load on every list endpoint — the DB query is wasted whenever the cache has a fresher version. For high-frequency callers like the RNF playlist-generation pipeline, this is a systemic over-read of the DB.

**10. Token table growth: `user_token` rows survive 30 days after 30-minute expiry**
Tokens expire 30 minutes after issuance but are only deleted from `user_token` 30 days later (`EXPIRE_AUTHORIZATION_DAYS = 30`). Every auth event creates a new token row. In a fleet with frequent player-api re-auths, the table accumulates millions of rows. If the queries `findAllByTypeAndUserId` and `findAllByAccessEquals` lack appropriate indexes, they degrade to full table scans as the table grows. The `@UpdateTimestamp` `used` field and `access` column are the primary lookup keys — their index coverage in the actual schema (visible only via Liquibase changesets in `fm-common`) needs verification.

**11. `DeploymentSupportService.deployment` is a JVM-wide static flag — causes a write storm during deployments**
`DeploymentSupportService.deployment` is a `static final AtomicBoolean` declared on the interface, shared across all implementing beans. When `DeploymentServiceImpl.started()` sets it `true`, all subsequent `ScreenStateService.update()` calls force immediate DB writes (`if (force || deployment.get())`). This persists for 5 minutes (hard-coded `DELAY_BEFORE_DEPLOYMENT_CANCEL_MIN = 5`). If the player fleet sends thousands of `lastDisplay` updates during a deployment window, every one triggers a synchronous DB write. No damping or batching mechanism exists during this window.

**12. Elasticsearch throttle coordinator makes state-service a single point of failure for ES quota management**
State-service is the only service that subscribes to ES-limit JMS topics and broadcasts `ELASTICSEARCH_LIMITS_ALLOCATED`. If state-service is down or its JMS subscriptions fail to register (slow startup), no instance can register, and all `fm-common` throttle clients fall back to `initial-limit` (1 query/instance in dev, 3 in prod). A state-service outage lasting more than a few minutes will effectively throttle all other services to their minimum ES quota, degrading search, analytics, and content indexing platform-wide.

**13. `fm-common` version pinned at `8.7.8` — one minor version behind `fmcom-api` at `8.9.0`**
`pom.xml` declares `<common.version>8.7.8</common.version>` while `fmcom-api` uses `8.9.0`. Both services exchange serialized DTOs (`ScreenDto`, `AuthTokenDto`, JMS message types) that are defined in `fm-common`. A field present in `8.9.0` but absent in `8.7.8` will be silently dropped on deserialization at the state-service end. There is no version-compatibility matrix or compatibility test visible in the codebase.

**14. Broker client expiry is purely time-based — reconnecting clients miss messages silently**
`BrokerServiceImpl.cleanup()` evicts `ClientDetails` after 5 minutes of inactivity. A player-api instance that is quiet for 5 minutes (pod restart, GC pause) will have its topic offsets evicted. On reconnect, it is assigned a fresh offset from the current tail and silently misses all messages delivered during the gap. This is undocumented at-most-once delivery; callers may assume at-least-once.

**15. Hardcoded broker credentials in dev task definition**
`tasks/dev-task-definition.json` contains `BROKER_USER: "devops"` and `BROKER_PASSWORD: "aAhuX2RbTJGp5ZksRA7JX8Vtm"` as plaintext environment variables, matching the defaults in `application.yml`. Production correctly uses SSM Parameter Store for all broker credentials. Any developer with access to the task definition JSON or the dev ECS console can read these credentials and connect directly to the Amazon MQ broker.

---

## Open Questions

1. **Authority boundary for screen writes**: `fmcom-api` imports `MySqlScreenModule` directly and can write to the `screen` table without going through state-service. Is there a documented policy that all screen writes must route through state-service? If not, which writes legitimately bypass it, and how does state-service's cache stay consistent in those cases?

2. **What do `ScreenStateClient` and `InstanceStateClient` in `fm-common 8.7.8` actually call?** The Feign client interfaces defined in `fm-common` are what `fmcom-api` and `fmcom-player-api` use to call state-service. Their exact endpoint signatures need to be confirmed against `ScreenController` and `InstanceController` routes, especially given the `fm-common` version gap (`8.7.8` here vs `8.9.0` in `fmcom-api`).

3. **Is this service on the JMS bus for any topics other than ES-limit topics?** The only JMS subscriptions visible in the code are the four ES-limit `@PostConstruct` subscriptions in `ElasticsearchLimitCoordinatorService`. State-service publishes to `ALL_USER_ACCESS_CHANGED` on auth events but does not appear to consume it. Is there any other JMS topic or queue this service is expected to subscribe to that is configured elsewhere?

4. **What is the observed RPS on `POST /screen/update/{screenId}` in production?** The player fleet presumably calls this endpoint frequently to update `lastDisplay`. The `SyncOpService` per-key lock contention and the deferred-flush design are only safe at certain throughputs. Understanding the actual load is essential for assessing whether the 1-minute flush window and the global `synchronized(locks)` are viable at scale.

5. **Does the `processRemaining()` self-Feign call during shutdown succeed in practice?** During `SmartLifecycle.stop()`, state-service calls its own load-balancer URL to flush dirty cache entries to a peer. If ECS drains the connection before invoking `stop()`, this call will fail silently. Has this shutdown hand-off been tested under realistic ECS rolling-deploy conditions?

6. **What is the cold-start behavior for the screen cache?** On a fresh start with an empty cache, all screen lookups trigger MySQL queries. In a deployment where both the old and new instances briefly overlap, the new instance's cache is empty. How does the cache warm up — lazily on first request, or is there a pre-load mechanism?

7. **`MySqlPatient` fields and production usage**: The `MySqlPatient` entity is referenced in `PatientRepository` and `AuthServiceImpl` for phone-hash-based authentication. Its field definition was not fully read in this spike. Is patient authentication actively used, and what is the patient token lifecycle?

8. **Is there a monitoring alert for when the ES throttle allocator is using fallback defaults?** `ElasticsearchLimitAllocator.getTotalBudget()` silently falls back to `48` if the system param is missing. With no alert, an operator would not know the allocator has lost its configured budget. Is there an observability hook on this fallback path?

9. **Has a decision been made on the Spring Security scope that unblocks the scheduler design?** `doc/scheduler-design.md` lists the absence of a `SecurityFilterChain` as a blocking decision for the scheduler admin UI. The design describes two filter chain options. Has a direction been chosen, and is this scheduled for a specific sprint?

10. **How is `fm-common` version governance managed across services?** State-service is at `8.7.8`, `fmcom-api` at `8.9.0`. Is there a compatibility matrix or automated integration test that validates that services on different `fm-common` versions can exchange messages safely? What is the upgrade cadence policy?
