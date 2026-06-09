---
title: "Tech Spike — Web platform frontend"
last_updated: 2026-06-09
---

# Tech Spike: Web platform frontend

## What This Service Does

The `fmcom-vrtly-fe-monorepo` is the entire client-facing web layer for the Vrtly platform. It houses four independently deployable Vue 3 single-page applications — vrtly-home (authentication shell), vrtly-practice-manager (VPM, the healthcare provider portal), vrtly-ad-manager (VAM, the brand/advertiser portal), and onboarding — plus a local HTTPS reverse-proxy that stitches all four apps together at `https://localhost:8080` for development. Each SPA is deployed independently to AWS S3 with a CloudFront distribution fronting it; the four apps share a single backend API at `api.dev.vrtly.app` / `api.vrtly.app`.

The platform connects two sides of a two-sided marketplace: healthcare practices (organizations of type `PROVIDER`) manage their waiting-room screens, brand-sponsored content playlists, patient consults, and info-packs through VPM; pharmaceutical/healthcare brands (organizations of type `SPONSOR`) create and manage advertising campaigns, upload creative content, and distribute consult materials through VAM. The onboarding app handles new practice sign-up, while vrtly-home handles authentication, business selection, and routing to the correct downstream SPA.

## Tech Stack & Key Dependencies

**Core framework**
- Vue 3.3 (Composition API throughout) — reactive component model
- Vue Router 4 — SPA routing with `createWebHistory`
- Pinia 2 — global state management (replaces Vuex)

**HTTP / API communication**
- Axios 1.8.4 — HTTP client with custom interceptors for token refresh, loading overlays, and error toasts
- `@vrtly/api` (internal workspace package) — centralised API client layer wrapping Axios; all requests pass through `packages/api/request/index.ts`

**UI component layer**
- Element Plus 2.9 — primary UI widget library (tables, forms, dialogs, drawers, loading overlay)
- `@vrtly/component-library` 0.8.x (external private npm package, served from AWS CodeArtifact) — Vrtly's own design-system component library; imported via `@vrtly/component-library/scss` for global styles

**Build / toolchain**
- Vite 7 — bundler for all four SPAs
- TypeScript 5.8 — strict typing across all apps and packages
- Vitest 4 — unit test runner (tests concentrated in `packages/utils` and `apps/onboarding`)
- ESLint 9 (flat config) + `eslint-plugin-vue` + `typescript-eslint` — linting
- Prettier — formatting
- simple-git-hooks + lint-staged — pre-commit quality gate

**Utilities**
- `@vueuse/core` 10 — `useStorage` (reactive localStorage), `useMemoize` (token-refresh deduplication)
- dayjs — date formatting and diff calculations
- mitt — lightweight event bus (used in player communication composition)
- sass 1.84 — CSS pre-processing

**Infrastructure dependencies**
- AWS S3 + CloudFront — static asset hosting and CDN for each SPA
- AWS CodeArtifact — private npm registry hosting `@vrtly/component-library`
- Bitbucket Pipelines — CI/CD; OIDC-federated AWS credentials; deploys via Atlassian `aws-s3-deploy` and `aws-cloudfront-invalidate` pipes

**Third-party integrations (client-side)**
- Stripe (subscription management; no client-side Stripe.js present — flows through backend `/cms/stripe*` endpoints)
- Google Places API (address autocomplete in settings and onboarding; `GooglePlaceInput.vue` component duplicated in VPM and Onboarding)
- Facebook / Instagram OAuth (social content linking via redirect-back pattern, handled in vrtly-home `/link/facebook` and `/link/instagram`)
- YouTube Data API (queried server-side via `/cms/dashboard/content/queryYoutube`)
- Intercom (toggled via `layoutStore.changeIntercomStatus()` in VPM navigation guards)

## Main Modules / Packages

### Apps

| App | Base path | Port (dev) | Purpose |
|-----|-----------|------------|---------|
| `apps/vrtly-home` v1.4.0 | `/` | 8081 | Auth shell: sign-in, forgot/set password, social account linking, business selector, SPA routing gateway |
| `apps/vrtly-practice-manager` v4.12.0 | `/provider` | 8082 | Healthcare provider portal (VPM): screens, playlists, content, brands, consults, info-packs, subscription management |
| `apps/vrtly-ad-manager` v0.9.0 | `/brands` | 8083 | Advertiser portal (VAM): brand management, campaign planning/execution, content library, consult distribution, info-packs |
| `apps/onboarding` v1.3.0 | `/onboarding` | 8084 | New practice signup wizard: user registration, business registration, brand selection, screen setup, Stripe checkout |
| `apps/proxy` | — | 8080 | Local dev HTTPS proxy (Express + http-proxy-middleware); not deployed |

### Shared Packages (`packages/`)

| Package | Purpose |
|---------|---------|
| `packages/api` | Axios request wrapper + all backend API call functions, one file per domain. Shared across all apps. |
| `packages/types` | TypeScript type declarations for all domain entities. Consumed by apps and `packages/api`. |
| `packages/compositions` | Shared Vue composables: `useUserActions`, `useConsultContent`, `useInfoPacksList`, `usePreview` |
| `packages/utils` | Pure utilities: formatters, validation, constants, player helpers, store helpers, consult helpers |
| `packages/components` | Shared Vue components: content drawers, dialogs, info-pack preview, org-switcher. Consumed by VPM and VAM. |
| `packages/pages` | Shared page-level components: Info Pack wizard (shared between VPM and VAM via `@vrtly/pages/info-pack/WizardPage.vue`) |

### Key directories within VPM (`apps/vrtly-practice-manager/src/`)

| Directory | Purpose |
|-----------|---------|
| `api/` | App-local API clients for screen-specific endpoints not yet promoted to `packages/api` (screen, screenNew, screenContent, room, order) |
| `store/` | Pinia stores: screens, brands, brandsScreens, playlists, consultInfoPacks, subscription, social, user, features, preview, layout |
| `compositions/` | App-local composables: brands, consults, content, infoPacks, members, playlist, playerCommunication, screens, orgFeatureBlocked |
| `pages/` | Route-level page components organized by domain: screen, playlist, consult, info-pack, brand, tools, subscription, downgrade, setting |
| `permission.ts` | Global navigation guard: enforces auth, v4 enablement check, onboarding step gate, downgrade redirect |

### Key directories within VAM (`apps/vrtly-ad-manager/src/`)

| Directory | Purpose |
|-----------|---------|
| `store/` | Pinia stores: advertiser, brands, businesses, features, social, user |
| `pages/` | Route-level pages: campaign (planner, wizard, overview), content (library, create), consult, info-pack, brand, settings |
| `components/sidebars/` | Persistent brand/content/settings sidebars rendered via Vue Router named outlets |

## External Integrations

| Integration | How it is used | Evidence |
|-------------|---------------|---------|
| **Vrtly backend API** (`api.dev.vrtly.app` / `api.vrtly.app`) | All data access goes through REST calls to `/cms/*` endpoints. Authentication uses custom `access`/`secret` header tokens (not standard Bearer). | `packages/api/request/index.ts`, all `packages/api/*.ts` files, `.env.development` files |
| **AWS S3 + CloudFront** | Each SPA is built and deployed as a static bundle to a dedicated S3 bucket behind a CloudFront distribution. `npm run build` per app, then S3 upload + cache invalidation. | `bitbucket-pipelines.yml` |
| **AWS CodeArtifact** | Hosts `@vrtly/component-library` private npm package. Auth token fetched via OIDC before `npm ci`. Domain: `vrtly`, account `515289352310`, region `us-west-2`. | `bitbucket-pipelines.yml` |
| **Stripe** | Subscription management for practices (screen-count-based billing, promo codes, invoice preview). Stripe Checkout sessions generated server-side; client redirects to Stripe-hosted page. No `stripe-js` loaded directly. | `packages/api/stripeSubscription.ts`, `apps/vrtly-practice-manager/src/store/subscription.ts` |
| **Google Places API** | Address autocomplete in practice settings (`GooglePlaceInput.vue`) and onboarding. Loaded via the Google Maps JS SDK. Component is duplicated in both VPM and Onboarding apps rather than living in `packages/components`. | `apps/vrtly-practice-manager/src/pages/setting/components/GooglePlaceInput.vue`, `apps/onboarding/src/components/GooglePlaceInput.vue` |
| **Facebook / Instagram OAuth** | Social account linking for pulling social posts as content. OAuth redirect-back handled by vrtly-home at `/link/facebook` and `/link/instagram`. Server exchanges code for account token. | `apps/vrtly-home/src/pages/LinkSocialAccount.vue`, `packages/api/socialAuth.ts` |
| **YouTube** | Provider can add YouTube videos as content. Backend proxies the YouTube Data API and returns metadata. | `packages/api/youtube.ts` — POST to `/cms/dashboard/content/queryYoutube` |
| **Intercom** | In-app support widget toggled by route meta (`hideIntercom`). Layout store manages visibility state. | `apps/vrtly-practice-manager/src/store/layout.js`, `permission.ts` |
| **Vrtly public portal** (`my.dev.vrtly.app/public`, `my.qa.vrtly.app/public`) | Info-pack QR code landing page URL referenced as `VITE_INFOPACK_URL`. URLs are encrypted server-side before embedding. | `.env.development` for VPM and VAM |
| **Reach & Frequency service** (`rnf.dev.vrtly.app`) | Forecasting/planning UI in VAM references this URL. Gap: no repo for this service found in the repos/ directory. | `apps/vrtly-ad-manager/.env.development` — `VITE_REACH_AND_FREQUENCY_URL` |

**GAP — services not found in repos/**
- `rnf.dev.vrtly.app` (Reach & Frequency) — referenced in VAM env config; source repo not present.
- The Vrtly public portal / info-pack consumer (`my.*.vrtly.app/public`) — referenced by both VPM and VAM; source repo not present.
- The backend API (`api.*.vrtly.app`) — all `/cms/*` calls go here; no backend repo present in this audit.

## Key Data Entities / Domain Models

All domain types are declared in `packages/types/` and imported via the `@vrtly/types` workspace alias.

| Entity | File | Key fields |
|--------|------|------------|
| `UserType` | `organization.d.ts` | `id`, `name`, `email`, `role`, `access` (short-lived token), `secret` (refresh token), `showSubscription` |
| `OrganizationType` | `organization.d.ts` | `id`, `name`, `logo`, `type: "PROVIDER" \| "SPONSOR"`, `onboarding.step`, `v4Enabled` |
| `LocationType` / `LocationWithAddressType` | `organization.d.ts` | Physical practice location, includes UTC offset and address; a provider org can have multiple locations |
| `ScreenType` | `room.ts` | `id`, `mac`, `online`, `roomId`, `subscription: ScreenSubscription`, `mode: ScreenMode`, `lastConnected`, `hardwareType` |
| `RoomType` | `room.ts` | Groups screens by room (`WAITING`, `TREATMENT`, `OTHER`) |
| `BrandType` / `ExtendedBrandListType` | `brand.d.ts` | Pharmaceutical/healthcare brand; has `brandType`, `demo`, `published`, `onBoard`, category linkage |
| `ConsultType` / `ConsultVersionType` | `consult.d.ts` | Multi-version educational content presentation. Each consult has branches and versions with status (`DRAFT`, `ACTIVE`, `ARCHIVED`), content items, info-pack links, and statistics |
| `ConsultContentItemType` | `consult.d.ts` | Individual slide in a consult: `type: IMAGE\|VIDEO\|YOUTUBE\|SOCIAL_NETWORK_POST`, `playTime`, `locked`, `qrCodeUrl` |
| `InfoPackType` / `InfoPackVersionType` | `info-pack.d.ts` | Patient take-home information packets with versioning, QR code distribution, and visit/content statistics |
| `ContentListType` / `ContentItemType` | `content.d.ts` | Uploadable media (VIDEO, ALBUM/images, YOUTUBE, SOCIAL_NETWORK_POST); tracks `transcodingStatus`, `scheduleStatus`, `quarantined` state |
| `PlaylistListType` | `playlist.d.ts` | Ordered list of content items assigned to screens |
| `CampaignType` / `CampaignListType` | `campaign.d.ts` | Ad campaign: `targetType: REACH\|SHARE_OF_VOICE`, `cpm`, `requestedImpressions`, `requestedPercent`, date range, status |
| `SubscriptionType` / `StripeCustomerPlan` | `stripeSubscription.d.ts` | Stripe-backed subscription; tracks trial, grace period, quantity (screens), `cancelAt` |
| `OrganizationFeaturesType` | `organizationFeatures.d.ts` | Feature entitlements per tier (`FREE`, `BRAND_ONLY`, `PLUS`, `PRO`): `brandConsults`, `customContent`, `maxScreensLimit`, `screensLimitDowngraded` |
| `FeatureFlagType` / `ConfigParam` | `index.d.ts` | Server-side feature flags fetched from `/cms/systemParam/list`, stored in Pinia `useFeaturesStore` |

## Notable Patterns, Risks & Observations

**Authentication model — custom token scheme, not standard OAuth/JWT**
The platform uses a bespoke `access`/`secret` dual-token scheme injected as raw HTTP headers (`config.headers.access`, `config.headers.secret`) rather than standard `Authorization: Bearer` or cookie-based sessions. Tokens are persisted in `localStorage` (via `@vueuse/core`'s `useStorage`). The refresh flow uses `useMemoize` to deduplicate concurrent refresh calls, and retries up to depth 3. This is a non-standard pattern that complicates security analysis and interoperability. Token secrets in localStorage are readable by any JavaScript on the page, raising XSS risk.

**Monorepo consolidation is incomplete**
The root `package.json` has a `build` script containing only `echo 'TODO: create consolidated monorepo build'`. There is no unified dist artifact — each app is built and deployed independently. The CI/CD pipeline reflects this correctly, but the monorepo's primary promise (unified build) is not yet delivered.

**Duplicate Axios request clients**
There are two distinct Axios instances: one in `packages/api/request/index.ts` (the shared client) and a near-identical one in each app's `src/utils/request.ts` (e.g., `apps/vrtly-practice-manager/src/utils/request.ts`). The app-local clients add an `orgId` injection regex for legacy `/cms/setting|dashboard|guide` routes. This duplication means bug fixes and interceptor changes must be applied in multiple places. VPM's local API files (`src/api/screen.ts`, `screenNew.ts`, etc.) use the app-local client while most other calls use `@vrtly/api`.

**Stripe webhook/polling race condition**
The `waitForTier` function in VPM's subscription store polls the backend on a 750ms interval for up to 60 seconds waiting for a Stripe webhook to reconcile tier changes. This is a documented risk with a code comment noting the async reconciliation. If the webhook is delayed or drops, the UI will proceed with stale data. There is no user-visible error on timeout.

**State persistence via localStorage — fragile and security-sensitive**
User credentials (`access`, `secret`), organization, location, and social network state are all stored in `localStorage` under plain keys (`user`, `organization`, `locationId`, `locations`, `organizationId`). Sign-out only clears these keys locally and calls the logout API; if the server session or token is valid elsewhere, there is no server-side invalidation confirmation visible in the client code.

**Feature flag system is memoized globally but not reactive**
`useFeaturesStore.getFlags` is wrapped in `useMemoize`, meaning flags are fetched once per session and cached indefinitely. If flags change server-side, no update reaches the client until a hard reload. There is no TTL or invalidation mechanism.

**Duplicate component implementations**
`GooglePlaceInput.vue` exists in both `apps/vrtly-practice-manager/src/pages/setting/components/` and `apps/onboarding/src/components/`. These should be consolidated into `packages/components`.

**Test coverage is sparse for the main apps**
Unit tests exist only in `apps/onboarding/src/components/__tests__/` (8 component tests) and `packages/utils/` (formatter, helper, consult unit tests). VPM (v4.12.0, the most complex app) and VAM have zero test files. This is a significant quality risk for a production system of this complexity.

**Layout.js is not TypeScript**
`apps/vrtly-practice-manager/src/store/layout.js` is a JavaScript file in an otherwise TypeScript codebase. This bypasses type checking for layout state (which controls Intercom visibility).

**Player communication uses polling intervals with partial retry logic**
`usePlayerCommunication` in VPM and VAM sends content to the embedded player iframe or popup via `postMessage`, retrying up to 3 times at 500ms intervals. If the iframe never signals `RECEIVE_CONTENT`, the system silently gives up after 3 retries with only a `console.warn`. There is no user-facing feedback on failure.

**v4Enabled versioning gate**
VPM's navigation guard checks `organization.v4Enabled`. If false, the user is redirected to `/` (the vrtly-home shell) with a redirect to an "outdated" stub page. This implies a migration in progress from an older (v3?) version of the platform, with some orgs still on the legacy path.

**Onboarding step gate in navigation guard**
VPM redirects organizations mid-onboarding (steps: `registration`, `addContent`, `screenSetup`) to `/onboarding` for most routes. This logic lives in `permission.ts` on the client — server-side enforcement of onboarding completion is not visible from this codebase alone.

**SPONSOR org type routing**
When a SPONSOR organization (i.e., a brand/advertiser) hits the VPM root (`home` route), they are redirected to `/brands` (VAM). The check is client-side only, relying on `organization.type` in localStorage.

**Separate deployment pipelines, no atomic rollout**
Each of the four SPAs is deployed independently, including on the `develop` and `main` branches. A breaking API contract change could be deployed to the backend while only some SPAs have been updated, creating a partial-deployment window.

## Open Questions

1. **Reach & Frequency service**: `VITE_REACH_AND_FREQUENCY_URL = 'https://rnf.dev.vrtly.app'` is referenced in VAM's dev env but no usage was found in the VAM source code during this audit. Is this a WIP integration, a deprecated URL, or consumed by a component not yet visible?

2. **v4Enabled migration**: What percentage of orgs still have `v4Enabled: false`? Is the legacy path (`deprecated` redirect) actively maintained, and what is the migration timeline?

3. **Onboarding step server-side enforcement**: Is the onboarding step gate enforced server-side (API returns 403 for mid-onboarding orgs), or does enforcement rely entirely on the VPM client navigation guard?

4. **Stripe webhook reliability**: The `waitForTier` polling approach caps out at 60s. What happens operationally if the webhook never arrives? Is there a manual reconciliation process?

