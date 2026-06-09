---
title: "Pre-Existing Risk Register — Vrtly Platform"
last_updated: 2026-06-09
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

### Q3 — `fm-common` version skew between backend services
**Severity:** Medium

`fmcom-api` pins `fm-common` at `8.9.0`; `fmcom-player-api` pins at `8.8.9`. This shared internal library defines JMS destination constants, Redis key prefixes, and domain model types used by both services. A breaking change in `fm-common` requires coordinated deployment across all consumers. No compatibility matrix is documented.

**Affected:** `fmcom-api`, `fmcom-player-api`.

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

### A3 — `rnf` (playlist resolver) is a critical unanalyzed dependency
**Severity:** High (gap)

Both `fmcom-api` and `fmcom-player-api` depend on the `rnf` service for all playlist resolution via Feign HTTP. `fmcom-api` also uses it for media processing dispatch via JMS. The `rnf` source repository was not included in this audit. Its SLA, failure behavior, and ownership are unknown. A `rnf` outage would stop playlist delivery to all devices.

**Affected:** `fmcom-api`, `fmcom-player-api`, all display devices.

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

## Open Questions for Client

The following risks have ambiguous ownership or require client clarification before DBP can assess scope:

| # | Question | Related risk |
|---|---|---|
| OQ1 | Is there a plan to migrate auth tokens from localStorage to HttpOnly cookies? | S1, S2 |
| OQ2 | Who owns the `rnf` service and what is its documented SLA? | A3 |
| OQ3 | Are ALB sticky sessions configured for `fmcom-player-api` ECS tasks? | R2 |
| OQ4 | Has the committed CloudFront private key (`private_key.pem`) been rotated? | S3 |
| OQ5 | Is the Stripe webhook polling timeout (60s) a known operational issue? | R1 |
| OQ6 | Is there server-side enforcement of onboarding step completion and SPONSOR/PROVIDER routing? | A1, A2 |
| OQ7 | What is the process for coordinating `fm-common` version upgrades across services? | Q3 |
