---
title: "Tech Spike — HTML5 player app (FireTV/WebView)"
last_updated: 2026-06-09
---

# Tech Spike: HTML5 player app (FireTV/WebView)

## What This Service Does

The `html5core` player is a Vue 3 single-page application that runs inside a WebView on Amazon FireTV (via Cordova), LG webOS, Samsung Tizen, iOS, and standard web browsers. Its primary role is to act as the display engine for Vrtly's digital signage platform: it contacts a backend API server on startup, registers the device, fetches and plays ordered content playlists (video, image albums, YouTube), and maintains a persistent WebSocket connection to the server for real-time commands (config pushes, playlist reloads, heartbeats, report requests, and deactivation). The app is deployed as a static bundle to an AWS S3 bucket and served via CloudFront.

A secondary operating mode called "Consultations" (Consults) transforms the player into an interactive presentation tool for healthcare practitioners. In this mode the device's remote control or touch interface is used to navigate a curated slide deck (video, image, YouTube) for a patient consultation session, with per-step progress tracked back to the backend API. A third feature area, "Info Packs," allows the player to surface a QR code that links a patient to downloadable content packages, with the link payload encrypted server-side via a dedicated CMS endpoint.

---

## Tech Stack & Key Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| Vue 3 | ^3.4.15 | Reactive UI framework; Composition API throughout |
| Pinia | ^2.1.7 | Centralized state management; every domain concern is a Pinia store |
| Vite | ^5.0.11 | Build tooling, dev server, HMR |
| TypeScript | ~5.3.0 | Type safety across all source files |
| `@vitejs/plugin-legacy` | ^5.4.1 | Transpiles output to ES5 + polyfills for Chrome 53–69 (webOS/Tizen) |
| `core-js` | ^3.38.0 | Polyfill runtime for old browser targets |
| `crypto-js` | ^4.2.0 | Client-side AES-CBC + SHA-1; used for request signing and payload decryption |
| `jsonpath-plus` | ^9.0.0 | De-references `$ref` pointers in JSON responses from the API |
| `uuid` | ^11.0.3 | UUID generation (usage context: telemetry/sessions) |
| `zod` | ^3.25.76 | Schema validation (imported but usage limited; type guards hand-written in most stores) |
| `@vue-youtube/core` + `vue-lite-youtube-embed` | — | YouTube iframe player integration |
| `@vueuse/core` | ^14.0.0 | Utility composables |
| `unplugin-auto-import` / `unplugin-vue-components` | — | Dev-time auto-import of Vue APIs and components |
| `vite-plugin-static-copy` | ^1.0.1 | Copies Cordova, webOS, Tizen, FireTV, web home stubs into dist |
| Python `boto3` | runtime install | Manual / CI S3 upload script (`s3_upload.py`) |

---

## Main Modules / Packages

| Path | Purpose |
|---|---|
| `src/App.vue` | Root component; orchestrates activation state machine, screen routing (Activation / Welcome / Connected / Player), reinit on server switch |
| `src/main.ts` | App bootstrap; registers Pinia, YouTube manager, `v-grid-item` directive, `GlobalFocusPlugin` |
| `src/store/device.ts` + `src/store/device-impl/` | Device detection strategy pattern; six implementations: Cordova (FireTV), iOS, Tizen, TizenHosted, webOS, Browser |
| `src/store/checkActivation.ts` | Polls `player/registerDevice` on 3-second intervals until activation confirmed; returns an activation code for QR display or a session key on success |
| `src/store/security.ts` | AES-CBC encryption/decryption using `crypto-js`; key is double-encrypted (server-provided key is itself encrypted with `'friendmediamedia'` as both key and IV) |
| `src/store/config.ts` | Fetches and holds org/screen config from `player/config`; triggers playlist reload on `contentType` change |
| `src/store/currentApiServer.ts` | Multi-environment server switcher (PROD / ALPHA / DEV / QA); persisted to localStorage; provides `http`, `ws`, `wss`, `api`, `qr`, `app` URL roots |
| `src/store/playlists.ts` | Playlist loading logic: SOV (Schedule of Values) from `player/playlist/current`, Custom Playlist mode from `player/custom-playlist/{id}`, Dynamic slot resolution from `player/custom-playlist/brand/{id}` |
| `src/store/playbackController.ts` | Central playback state machine: playlist array, current index, play/pause/next/prev, consults mode vs default mode, CC (closed captions) override |
| `src/store/playbackWatchdog.ts` | Heartbeat-driven recovery: if playback state hash does not change for 10s → pressNext, 20s → resetPlaylist, 30s → `window.location.reload()` |
| `src/store/websocket.ts` | Persistent WebSocket client; handles CONFIG, CONTENT_CHANGED, HEARTBEAT, REPORT, DISCONNECT message types; auto-reconnect on close/error |
| `src/store/telemetry/` | Structured telemetry subsystem: `TelemetryData` class hierarchy (DeviceInfo, Interaction, Playback, PlaybackWatchdog, ConnectionState), `telemetryQueue` (localStorage-buffered batch sender via WebSocket), `telemetryPlaybackSender` (per-content event queue) |
| `src/store/playedContentReport.ts` | Records content playback starts to localStorage; submits to `report/content` HTTP endpoint every 7 minutes or on WebSocket REPORT command |
| `src/store/plan.ts` | Sends upcoming playback schedule (next 10 items) to `player/plan` whenever the content index changes |
| `src/store/consults/` | Consultation feature: `consultsDataStore` (brands, consultations, details, tracking via `player/consult/*`), `consultsFlowStore` (setup wizard state machine: user → brand → consult), `models.ts` (ConsultContent, ConsultTrackRequest/Response, etc.) |
| `src/store/info-packs/` | Info Pack selection and QR link generation: `infoPacksDataStore` (loads from `player/info-pack`), `infoPacksSetupFlowStore` (selection flow), `models.ts` (InfoPack, InfoPacksResponse) |
| `src/store/autoUpdate.ts` | On every playlist reload, fetches `/build.json` and calls `window.location.reload()` if build hash differs |
| `src/store/network.ts` | Tracks online/offline browser events; suppresses telemetry spam when offline |
| `src/store/debugSettings.ts` | Detects prod vs beta S3 bucket from `window.location.href`; exposes redirect helpers and watchdog overlay toggle |
| `src/store/serverLogger.ts` | Dead code: `sendIssue()` has an early `return` making it a no-op; `overloadConsole()` wraps console methods but is also effectively disabled |
| `src/FECommunication/` | VAM (Video Asset Manager) preview mode: `postMessage` channel between the player (in an iframe/popup) and the Vrtly web app; receives `SEND_CONTENT`, sends `READY` / `RECEIVE_CONTENT` |
| `src/utils/api.ts` | `apiRequest()`: wraps `fetch`, adds device serial + timestamp + SHA-1 signature, handles encrypted responses (AES decryption via `security` store), de-references `$ref` JSON pointers |
| `src/utils/useApi.ts` | Higher-level typed API wrapper; accepts a typeguard for response validation |
| `src/utils/qrCodeBuilder.ts` | Builds encrypted Info Pack QR code URLs by calling `api.vrtly.ai/cms/encrypt` |
| `src/composables/` | `useGridNavigation`, `useMultiAreaNavigation` (D-pad focus management), `usePagination`, `useRam`, `useScreenDimensions`, `useTimedFlag`, `useUrlParams` |
| `src/plugins/globalFocus.ts` | Vue plugin for remote-control focus management |
| `src/directives/v-grid-item.ts` | Custom directive wiring DOM elements into the grid navigation system |
| `src/components/player/content-players/` | `VideoPlayer.vue`, `PicturePlayer.vue`, `YoutubePlayer.vue` — leaf content renderers |
| `src/components/player/PlayerScreen/` | Main playing screen; mounts content players and overlays |
| `src/components/player/consults/` | ConsultsManager + selection overlays (user, brand, consultation, exit, last slide) |
| `src/components/player/info-packs/` | InfoPacksManager, selection overlay, QR scan display |
| `src/components/activation/` | ActivationScreen (QR code display), ConnectedScreen, WelcomeScreen |
| `src/components/views/` | FullScreenView, BusyView, ExitConfirmationView, InternetConnectionView, TileGridView |
| `src/components/settings/` | DevDialog (developer settings panel), DeviceInfo, PlaylistGrid |
| `public/` | Platform-specific home page stubs (FireTV, webOS, Tizen, iOS, web), Cordova integration JS, webOS SDK JS |
| `vite-plugins/createBuildJsonPlugin.ts` | Generates `dist/build.json` (git hash + SHA-1 of build date) at bundle time for auto-update detection |
| `bitbucket-pipelines.yml` | CI/CD: build + type-check → manual deploy to S3 + CloudFront invalidation (beta branch) or auto deploy (prod branch) |

---

## External Integrations

| Integration | Endpoint / Protocol | Notes |
|---|---|---|
| **Vrtly Player API** | `https://player.vrtly.ai/` (HTTP REST) | Primary backend; all `player/*` routes: registerDevice, config, playlist/current, custom-playlist, consult/*, info-pack, plan, report/content |
| **Vrtly CMS API** | `https://api.vrtly.ai` (HTTP REST) | Used for `cms/encrypt` (Info Pack QR payload encryption) and QR code image generation (`cms/qr-code/generate-qr-code`) |
| **Vrtly WebSocket** | `wss://player.vrtly.ai/ws` | Persistent duplex channel; receives server-push commands; sends heartbeat, telemetry, and content reports |
| **Vrtly Web App** | `https://my.vrtly.ai` | VAM preview mode target; also the activation URL shown to users |
| **Amazon S3** | `html5core` / `html5core-beta` buckets | Static hosting for the app bundle; deployed via `s3_upload.py` and Bitbucket Pipelines |
| **AWS CloudFront** | CDN in front of S3 | Cache invalidated on each deploy via Bitbucket pipeline |
| **Amazon S3 (subtitles)** | `friendmedia-cms.s3.amazonaws.com` | Subtitle (VTT/SRT) files served from a separate CMS bucket; accessed by VideoPlayer via dev proxy in development |
| **YouTube IFrame API** | `youtube.com` | YoutubePlayer component via `@vue-youtube/core`; video IDs come from playlist `YoutubeContent.videoId` |
| **Cordova Native Bridge** | `window._cordovaNative` | FireTV shell communication; provides device UUID, model, platform, shell version; `cordova-plugin-app-version` for version |
| **webOS SDK** | `webOSTV.js` (bundled in `public/webos-integration/`) | webOS device detection and info |
| **Tizen SDK** | `window.tizen` global | Tizen device detection; separate `TizenHostedDevice` for browser-hosted Tizen mode |
| **iOS WKWebView bridge** | `window.webkit.messageHandlers` | iOS-specific device integration (`src/types/ios.d.ts`) |

**Gap:** The repos directory does not contain the Vrtly backend API service(s) that handle the `player/*` and `cms/*` routes. All API contracts are inferred from the client-side call sites. The Cordova shell (`cordova-player` repository) is also referenced in the README but not present in this repo — the relationship between these two repos is a gap for the system map.

---

## Key Data Entities / Domain Models

| Entity | File | Description |
|---|---|---|
| `Content` | `src/types/content.ts` | Base type for all playable items: `type` (Video/Picture/Youtube), `url`, `duration`, `ordinal`, `contentId`, `brandId`, `qrLink`, `ctaText` |
| `VideoContent` | `src/types/content.ts` | Extends `Content`; adds `subtitleUrl` |
| `PictureContent` | `src/types/content.ts` | Extends `Content`; no additional fields |
| `YoutubeContent` | `src/types/content.ts` | Extends `Content`; adds `videoId` |
| `PlaylistInfo` | `src/store/playlists.ts` | Playlist metadata: `id`, `name`, `contentAmount`, `cover`, `selected` |
| `_Content1` / `_Content2` | `src/store/playlists.ts` | Internal server-response shapes (prefixed `_`); mapped into `Content` subtypes during `_parsePlaylist()` |
| `ConsultContent` | `src/store/consults/models.ts` | Slide in a consultation deck: `id`, `type` (VIDEO/IMAGE/YOUTUBE), `src`, `thumbnail`, `position`, `listId`, `qrCodeUrl`, `ticker` |
| `ConsultDetails` | `src/store/consults/models.ts` | Full consultation with ordered `ConsultContent[]` and linked `infoPackIds` |
| `ConsultTrackRequest/Response` | `src/store/consults/models.ts` | Step-tracking for active consultation sessions; `step`, `steps`, `username`, `startTime` |
| `Brand` | `src/store/consults/models.ts` | Brand entity: `id`, `name`, `logo`, `coverPic`, `consultNum` |
| `InfoPack` | `src/store/info-packs/models.ts` | Info pack: `id`, `infoPackId`, `name`, `brandId`/`orgId` affiliation, `contentSize` |
| `InfoPacksResponse` | `src/store/info-packs/models.ts` | Paginated response wrapper (Spring-style page metadata) |
| `BuildInfo` | `src/store/autoUpdate.ts` | `git_hash`, `build_date`, `build_hash` from `/build.json` |
| `Report` / `HistoryElement` | `src/store/playedContentReport.ts` | Content playback events buffered locally and submitted to `report/content` |
| `PlanElement` | `src/store/plan.ts` | Upcoming playback schedule element: `start` (ISO 8601), `contentId`, `duration` |
| `TelemetryData` subclasses | `src/store/telemetry/telemetry.ts` | Typed telemetry events: DeviceInfo, Interaction, Playback, PlaybackWatchdog, ConnectionState; batched via WebSocket |

---

## Notable Patterns, Risks & Observations

**Architecture Patterns**
- The Pinia store layer is the entire application logic layer. There are no separate service classes; business logic, API calls, and state mutations are co-located inside store `actions`. This is acceptable for a player of this size but creates single-responsibility violations (e.g., `playlists.ts` fetches, parses, and imperatively drives `playbackController`).
- Device platform detection uses a strategy pattern (`DeviceImpl` interface + ordered probe list in `device.ts`), which is clean and extensible.
- The `encodeURIComponent` in `src/utils/api.ts` is a custom, hand-rolled implementation that only replaces single occurrences of each special character (no `replace(/ /g, ...)` with a regex global flag). This is a correctness bug: if a URL parameter value contains more than one instance of a reserved character (e.g., two `&` symbols), only the first is encoded. This could corrupt signed request URLs.

**Security Concerns**
- The AES-CBC encryption in `src/store/security.ts` uses a hardcoded string `'friendmediamedia'` as both the default secret and the IV for the outer decryption step. The IV is not random, which makes the scheme deterministic and reduces effective security to key secrecy alone.
- The `encryptBuf` and `encryptString` methods in `security.ts` are marked `// unused ???` in comments — dead code that should be audited before any future encryption refactor.
- Request signing uses `SHA-1(serialNum + timestamp)`. SHA-1 is considered cryptographically weak. The `sort` flag logic (`timestamp < serialNum ? sha1(timestamp + serialNum) : sha1(serialNum + timestamp)`) does lexicographic string comparison, not numeric, which is an inconsistency worth reviewing.

**Reliability Patterns**
- The `playbackWatchdog` provides a graduated self-healing loop (skip → reload playlist → reload app at 10s / 20s / 30s thresholds). This is a sound pattern for unattended display hardware, though the 30-second full `window.location.reload()` may cause visible disruption on slow devices.
- The `autoUpdate` mechanism polls `/build.json` on every playlist reload (not on a timer), which is opportunistic — updates are applied only when the playlist naturally reloads. This is intentional design, but an update deployed while a screen is mid-consult will not be applied until the consultation ends.
- Telemetry is buffered in `localStorage` and flushed over WebSocket in batches of 30 or on a 5-minute timer. If the WebSocket drops permanently, telemetry accumulates without bound in localStorage (no cap or TTL on the buffer).

**Technical Debt**
- `src/store/serverLogger.ts` — `sendIssue()` has an unconditional `return` on line 38, making the entire server-side logging feature dead code. The `overloadConsole()` method also calls `sendIssue` indirectly but is never invoked. This is infrastructure that was either disabled for shipping or abandoned mid-development.
- The `src/store/plan.ts` store (`usePlan`) has `activate()` and `deactivate()` lifecycle hooks but it is unclear from the store list whether it is actually activated anywhere in the component tree. Its absence from `App.vue` initialization suggests it may be dormant.
- YouTube content parsing in `_parsePlaylist` hard-codes a fallback URL (`https://www.youtube.com/embed/M7lc1UVf-VE?...`) in the `YoutubeContent` node construction, then overrides it with the actual `videoId`. This is a leftover placeholder that confuses intent.
- Server environment names (PROD, ALPHA, DEV, QA) are string-compared in multiple places; the `ServerType` enum is defined in `currentApiServer.ts` but not always used as a type constraint.

**Multi-Platform Build Complexity**
- The `@vitejs/plugin-legacy` target list includes `Chrome >= 53` to cover webOS and Tizen devices, while production FireTV runs Chrome 120 (Android 11 WebView). Maintaining one bundle for both constraint tiers increases bundle size for modern targets. The comment on `modernTargets` ("uncommenting breaks Tizen") suggests this tradeoff has been encountered and consciously deferred.
- Platform-specific home page stubs in `public/` (FireTV, webOS, Tizen, iOS, web) each contain independent HTML entry points. Their relationship to the Vite SPA entry (`index.html`) is not immediately clear from the source — these appear to be shell launch pages that load the Cordova/webOS SDK before delegating to the Vue app.

**Missing Test Infrastructure**
- There are no test files in the repository. No unit, integration, or end-to-end test framework is configured in `package.json`. For a player running on unattended hardware where watchdog-driven app resets are the primary reliability mechanism, the absence of automated tests is a material risk.

---

## Open Questions

1. **Cordova shell relationship**: The README states the player is embedded in a `cordova-player` repo. What is the exact versioning and deployment contract between the two? Does the Cordova shell always load the app from S3, or can it bundle a local copy? This affects the auto-update story.

2. **`usePlan` activation**: Is `src/store/plan.ts` (`usePlan`) actually activated in the running app? A search for `usePlan()` in component files would confirm whether plan reporting is live or dormant.

3. **`serverLogger` status**: Is the server-side issue reporting feature intentionally disabled, or is it awaiting an API that is not yet available on all environments? The hardcoded alpha URL inside the store suggests a staged rollout that never completed.

4. **Subtitle delivery**: Subtitles are proxied through `friendmedia-cms.s3.amazonaws.com` in dev. In production, does the player fetch subtitles directly from S3? Is this bucket publicly accessible, or are signed URLs used? CORS configuration for this bucket is not visible in the player codebase.

5. **Encryption key lifecycle**: The security key returned by `player/registerDevice` (code `10002`) is stored only in memory (Pinia state). What happens to in-flight encrypted API responses if the app is reloaded or the device is power-cycled before re-activation? Does the backend re-issue the same key on the next `registerDevice` call?

6. **Telemetry buffer overflow**: The telemetry queue in localStorage has no size cap. What is the expected behavior if the WebSocket is offline for an extended period? Is there a max-age or max-size policy planned?

7. **ChromeCast / other platforms**: The device-impl strategy list does not include ChromeCast or Android TV native. Is there a roadmap for these platforms, and would they require a new `DeviceImpl`?

8. **`is_vam_preview` URL parameter security**: The VAM preview mode is activated by a URL parameter (`is_vam_preview=true`). The `postMessage` origin check uses `appUrl` derived from `servers.json`. Has this been reviewed for CORS/frame injection risk in production deployments where the player URL is publicly accessible?
