---
title: "Tech Spike — cordova-player (FireTV Shell)"
last_updated: 2026-06-12
---

# Tech Spike: cordova-player (FireTV Shell)

## What This App Does

`cordova-player` is a purpose-built thin-client Cordova wrapper that acts as the native Android shell for the Vrtly application on Amazon FireTV devices. It does not contain the application itself. Its sole job is to containerize and launch a remotely-hosted html5core Vue SPA — served from an S3 bucket — inside a Cordova `InAppBrowser` instance, while bridging the native device capabilities that a plain browser context cannot access. The app package is `ai.vrtly`, currently at shell version `1.0.8`.

The design philosophy is remote-first: zero application logic lives in the APK or AAB that is installed on the device. On every launch, the shell performs a live HTTP fetch against the S3 endpoint to confirm reachability, then opens the hosted URL in a full-screen `InAppBrowser` with no address bar or navigation chrome. All future product iterations — new features, UI changes, bug fixes — are deployed by updating the S3-hosted html5core bundle, not by shipping a new app package to device. A new shell release is only required when native Cordova capabilities change: adding or modifying a plugin, changing signing configuration, adjusting manifest permissions, or bumping the Android platform. This model means the Cordova shell and the html5core application version independently, and the device fleet always runs the latest html5core without requiring an APK update cycle.

---

## Tech Stack & Key Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| Apache Cordova | (CLI) | Core hybrid application runtime; manages the Android WebView and plugin lifecycle |
| cordova-android | `^13.0.0` | Android platform target; Gradle-based build for Android API |
| cordova-plugin-inappbrowser | `^6.0.0` | Opens the remote html5core URL in a full-screen browser overlay; the primary application surface |
| cordova-plugin-device | `^3.0.0` | Exposes native device metadata (UUID, model, platform, version) to the Cordova JavaScript context |
| cordova-plugin-fire-tv | `^1.1.0` | Amazon FireTV-specific integration; handles platform-level behaviors (pause/resume/visibility) unique to the Fire OS environment |
| cordova-plugin-splashscreen | `^6.0.1` | Manages the launch splash screen; configured to show on every launch with a 3000ms delay |
| cordova-plugin-app-version | `^0.1.14` | Exposes the native app version from the build manifest back to JavaScript |
| cordova-plugin-network-information | `github:apache/cordova-plugin-network-information` | Provides network connectivity state; sourced from GitHub HEAD rather than npm |
| cordova-plugin-insomnia | `^4.3.0` | Prevents the FireTV device from sleeping while the app is running (`keepAwake`) |
| phonegap-plugin-mobile-accessibility | `^1.0.5` | Grants `android.permission.ACCESSIBILITY_FEATURES`; required for Fire OS platform compliance |
| ai.vrtly.browserbridge | `file:custom-plugins/ai.vrtly.browserbridge` v1.0.0 | Custom plugin — bridges native Cordova plugin calls from inside the InAppBrowser context back to the host |
| ai.vrtly.raminfo | `file:custom-plugins/ai.vrtly.raminfo` v1.0.0 | Custom plugin — exposes Android system and process-level RAM metrics to the JavaScript layer |
| prettier + @prettier/plugin-xml | `^3.2.5` / `^3.3.1` | Code formatting, including XML config files |

---

## Native Shell Architecture

The runtime model has three distinct layers: the Cordova native shell, the thin `www/` web context, and the InAppBrowser overlay that hosts the real application.

**Boot sequence.** On launch, Cordova renders the `www/index.html` page in its embedded WebView. This page is minimal: it shows a black loading screen with a spinner and a "Please wait" message. The page immediately calls `tryLoadHostedApp()`, which performs a `fetch()` against the production S3 URL (`https://html5core.s3.us-west-2.amazonaws.com/index.html`). If the response is `200 OK`, the shell calls `cordova.InAppBrowser.open()` with the same URL, options `location=no,hideurlbar=yes`, opening a full-screen browser that covers the entire display. If the fetch fails (network error) or returns an HTTP error, the shell reveals an error view with a "Try Again" button that re-runs `tryLoadHostedApp()`. There is no retry loop and no timeout — the fetch is a single attempt.

The `deviceready` event (fired after `www/js/index.js` loads via a dynamically injected `<script src="cordova.js">`) triggers `window.plugins.insomnia.keepAwake()`, locking the screen on. The Cordova integration guard checks for `window._cordovaNative` before proceeding; if this sentinel is absent (e.g., during desktop browser testing), the shell shows a generic error and halts.

**S3 endpoints.** Two S3 bucket endpoints are referenced across the codebase:

| Environment | URL | Config Location |
|---|---|---|
| Production | `https://html5core.s3.us-west-2.amazonaws.com/index.html` | `www/js/index.js`, `config-development.xml`, `config-release.xml` |
| Beta | `https://html5core-beta.s3.us-west-2.amazonaws.com/index.html` | Commented out in `www/js/index.js`; declared as allowed navigation in both config XMLs |

The beta endpoint is wired into the navigation allowlist in both config files but is not the active load target. Switching to beta would require a code change in `www/js/index.js`.

**Responsive scaling.** The `www/` shell UI uses a fixed 1920×1080 design canvas scaled to fit the actual display. On every `resize` event and on initial load, `onWindowResize()` computes a uniform `scale` factor as `Math.min(windowWidth / 1920, windowHeight / 1080)`, then sets five CSS custom properties on `:root` (`--ui-scale`, `--ui-left`, `--ui-top`, `--ui-width`, `--ui-height`). The `.full-screen-view` CSS class applies these as `transform: scale(var(--ui-scale))` with `transform-origin: top left`, centering the scaled canvas with calculated `left`/`top` offsets. This scaling logic applies only to the shell's own error/loading UI — the InAppBrowser overlay is full-screen and manages its own responsive behavior independently.

**Dev vs release configuration.** The primary difference between `config-development.xml` and `config-release.xml` is the cleartext traffic setting: the development config includes `<application android:usesCleartextTraffic="true" />` in the Android manifest, permitting HTTP connections during development. The release config omits this flag, restricting the release build to HTTPS. Both configs point to the same production S3 URL and carry the same splash screen settings and permission declarations. The `version` field in both configs is `0.0.0` as a placeholder — the build script overwrites it at build time from `package.json`.

---

## Custom Plugins

### ai.vrtly.browserbridge

**Purpose.** The InAppBrowser overlay runs in an isolated JavaScript context that has no access to the Cordova plugin API available in the outer `www/` context. `ai.vrtly.browserbridge` solves this by injecting a bridge script into the InAppBrowser page and setting up a message-routing pipeline between the hosted html5core app and native Cordova plugins in the host.

**API surface.**

| Method | Signature | Description |
|---|---|---|
| `BrowserBridge.injectInto` | `(inAppBrowserRef, plugins: string[]) → Promise` | Waits for the InAppBrowser `loadstop` event, injects the bridge script, and registers message listeners for each named plugin |

**Message routing.** The bridge operates as a three-layer relay:

1. **Injection** — On `loadstop`, `BrowserBridge.injectInto()` uses `inAppBrowserRef.executeScript({ file: 'plugins/com.vrtly.browserbridge/www/browser-bridge-inject.js' })` to inject the client-side bridge into the InAppBrowser's page context.

2. **In-page stubs** — `browser-bridge-inject.js` (an IIFE) creates `window.RamInfo` and `window.Device` objects in the InAppBrowser context. Each object exposes a single `getInfo(successCallback, errorCallback)` method. When called, the stub generates a unique `callbackId` (pattern: `<pluginname>_<timestamp>_<random>`), registers the callbacks locally in `window[pluginName]._callbacks`, and sends a `postMessage` to the host via `window.cordova_iab.postMessage({ type: '<PluginName>.getInfo', callbackId })`.

3. **Host relay** — Back in the outer Cordova context, `BrowserBridge.injectInto()` has registered an `inAppBrowserRef.addEventListener('message', ...)` listener for each plugin. When a `<PluginName>.getInfo` message arrives, the listener calls the actual native plugin via `cordova/exec` (service: `pluginName`, action: `'getInfo'`). On success or failure, it calls `inAppBrowserRef.executeScript({ code: window.postMessage({type: '<PluginName>.response', callbackId, success, data}, '*') })` back into the InAppBrowser page. The in-page `window.addEventListener('message', ...)` listener picks up the response, matches the `callbackId` to the stored callbacks, invokes the appropriate callback, and cleans up.

The two plugins wired up in `browser-bridge-inject.js` are `RamInfo` and `Device`. The plugin name in the message type must match the Cordova service name exactly — the bridge uses the plugin name as both the `window.*` stub name and the native service identifier passed to `exec`.

---

### ai.vrtly.raminfo

**Purpose.** Exposes Android system-level and process-level RAM metrics to the JavaScript layer. Intended for diagnostics and performance monitoring of the FireTV shell and the html5core app running within it.

**API surface.**

| Method | Signature | Description |
|---|---|---|
| `RamInfo.getInfo` | `(successCallback, errorCallback) → void` | Calls the native `RamInfoPlugin.getInfo` action and returns a JSON object |

**Response object fields** (all numeric, in bytes unless noted):

| Field | Source | Description |
|---|---|---|
| `totalRam` | `ActivityManager.MemoryInfo.totalMem` | Total device RAM |
| `availableRam` | `ActivityManager.MemoryInfo.availMem` | Available system RAM |
| `usedRam` | `totalMem - availMem` | System RAM in use |
| `memoryThreshold` | `ActivityManager.MemoryInfo.threshold` | Low-memory kill threshold |
| `lowMemory` | `ActivityManager.MemoryInfo.lowMemory` | Boolean — system in low-memory state |
| `appMemoryUsage` | `Debug.MemoryInfo.getTotalPss() * 1024` | Total PSS of this process (bytes) |
| `heapTotal` | `Runtime.totalMemory()` | JVM heap allocated to this process |
| `heapFree` | `Runtime.freeMemory()` | Free JVM heap |
| `heapUsed` | `totalMemory - freeMemory` | JVM heap in use |
| `heapMax` | `Runtime.maxMemory()` | JVM heap ceiling |
| `nativeHeapSize` | `Debug.getNativeHeapSize()` | Native heap total |
| `nativeHeapFree` | `Debug.getNativeHeapFreeSize()` | Native heap free |
| `nativeHeapAllocated` | `Debug.getNativeHeapAllocatedSize()` | Native heap in use |
| `systemMemoryUsagePercent` | Derived | `usedRam / totalRam × 100` (rounded) |
| `appMemoryUsagePercent` | Derived | `appMemoryUsage / totalRam × 100` (rounded) |
| `heapUsagePercent` | Derived | `heapUsed / heapMax × 100` (rounded) |

The plugin is a pure Android Java implementation (`com.vrtly.plugin.RamInfoPlugin extends CordovaPlugin`). It has no iOS or browser platform stubs. The JS wrapper (`www/raminfo.js`) is a single-method pass-through to `cordova/exec`.

---

## Build & Deployment Model

All builds are executed via `build-android.sh`, which accepts a single optional argument (`development` | `release`, defaulting to `development`).

**Config preparation.** The script selects either `config-development.xml` or `config-release.xml`, prepends a `DO NOT MODIFY` comment, writes the result to `config.xml` (the Cordova-consumed file), then uses `sed` to overwrite the `version` attribute with the value from `package.json` (`node -p "require('./package.json').version"`). This means `config.xml` is a generated artifact — the source of truth for config is the `config-development.xml`/`config-release.xml` pair and `package.json`.

**Build outputs.**

| Mode | Steps | Output file |
|---|---|---|
| `development` | `npx cordova build android` (debug) | `out/vrtly-debug.apk` |
| `release` | `npx cordova build android` (debug APK) + `npx cordova build android --release` (signed AAB) | `out/vrtly-debug.apk` + `out/vrtly-release.aab` |

Release builds produce both an APK (for sideloading and ADB testing) and an AAB (for Amazon Appstore or Google Play submission). The AAB is signed using a keystore referenced by `release-signing.properties` (gitignored), which is copied to `platforms/android/app/` before the release build.

**Signing.** The keystore is generated with the JDK `keytool` command (RSA 2048, 10000-day validity). Credentials live in `release-signing.properties` (copied from `release-signing.properties.sample`). Neither file is committed to the repository.

**Environment prerequisites.** The script hardcodes `ANDROID_SDK_ROOT` to `~/Library/Android/sdk`, `JAVA_HOME` to `/opt/homebrew/Cellar/openjdk@17/17.0.14`, and `PATH` addition for `build-tools/35.0.0`. These paths are developer-machine-specific and will fail on any machine where the SDK or JDK is installed to a different location. The README notes that Gradle 8.6 was used during development and that Android build tools must be the exact version specified.

**Output directory.** Both APK and AAB artifacts are written to `./out/`, which the script creates with `mkdir -p`. Existing artifacts are removed before each build (`rm out/vrtly-*.apk 2>/dev/null`).

---

## Integration Contract with html5core

This is the architecturally significant boundary in the system.

### window._cordovaNative sentinel

`www/js/index.js` checks for `typeof window._cordovaNative !== 'undefined'` before bootstrapping. This property is injected by the Cordova native runtime and serves as the guard distinguishing a genuine Cordova WebView context from a plain browser. If absent, the shell displays a generic error and does not attempt to load the hosted app.

### Device information bridge

The `cordova-plugin-device` plugin (installed in the outer Cordova context) exposes `device.uuid`, `device.model`, `device.platform`, and `device.version` to the `www/` JavaScript context. Through the browserbridge relay, html5core can call `window.Device.getInfo(successCallback, errorCallback)` from inside the InAppBrowser and receive this same device metadata. The exact payload is whatever `cordova-plugin-device`'s `getInfo` action returns — the bridge relays it verbatim without transformation.

### Native capability access from html5core

html5core accesses native capabilities exclusively through the `window.RamInfo` and `window.Device` stubs installed by `browser-bridge-inject.js`. These are the only two plugins currently wired. Any new native capability (e.g., network status, app version) would require: (1) adding the plugin name to the `plugins` array in `browser-bridge-inject.js`, (2) adding a corresponding message listener in `BrowserBridge.injectInto()`, and (3) ensuring the native plugin is registered in `config.xml`. The bridge protocol is fixed: `<PluginName>.getInfo` request → `<PluginName>.response` reply; it does not support multiple action types per plugin.

### Versioning relationship

The shell (`package.json` `version: 1.0.8`) and html5core are versioned independently. The shell version is stamped into the Android manifest at build time and is queryable via `cordova-plugin-app-version`. html5core has no version pin to a specific shell version — it receives whatever shell is installed on the device. The hosted app is updated by deploying a new build to the S3 bucket; all devices with the app installed pick up the new html5core on their next launch without any app update step. There is no mechanism in the shell to reject or gate an html5core version — if html5core relies on a bridge capability that exists only in a newer shell, older shells will silently fail when that bridge call is attempted.

### Update delivery model

The `<content src="...">` tag in both `config-development.xml` and `config-release.xml` points directly to `https://html5core.s3.us-west-2.amazonaws.com/index.html`. This tag sets the Cordova WebView's initial URL — it does not serve a local bundle. The `www/js/index.js` then uses `fetch()` and `cordova.InAppBrowser.open()` against the same URL. There is no local fallback HTML, no service worker, no offline bundle, and no caching strategy in the shell. If S3 is unreachable at launch, the user sees "Network Disconnected" with a manual retry button and cannot proceed. Once the InAppBrowser is open, html5core's own caching behavior (if any) governs offline resilience.

---

## Notable Patterns, Risks & Observations

1. **Total dependency on S3 availability for every launch.** The shell cannot start the application without a successful HTTP fetch to `https://html5core.s3.us-west-2.amazonaws.com/index.html`. There is no cached fallback, no service worker, and no offline mode. A regional S3 outage, a DNS failure, or a misconfigured S3 bucket policy produces a hard stop at launch with a manual "Try Again" prompt. In a venue-deployed kiosk scenario (where network reliability cannot be guaranteed), this is a single point of failure with no recovery path short of restoring connectivity.

2. **InAppBrowser security boundary is not enforced by origin allowlist.** The shell opens the InAppBrowser with `location=no,hideurlbar=yes`. If html5core navigates to a third-party URL (e.g., an embedded link or a JavaScript `window.location` assignment), the InAppBrowser will follow it. The `<allow-navigation>` entries in `config.xml` cover the two S3 buckets, but InAppBrowser navigation allowlisting is separate from the Cordova WebView allowlist and may not be enforced depending on the Cordova version and plugin configuration. There is no `beforeload` event handler in the shell to intercept or reject unexpected navigation.

3. **Version skew between shell and html5core has no detection or gating mechanism.** Shell `1.0.8` is deployed on a device. html5core is updated to a version that calls `window.RamInfo.getInfo()` expecting a new response field. The shell has no knowledge that html5core changed, and html5core has no knowledge of which shell version is running. Breaking changes in either direction (html5core expecting new bridge capabilities, or shell removing/renaming a bridge) will manifest as silent runtime failures, not at-install-time validation.

4. **The bridge protocol supports only `getInfo` as the action type.** The `BrowserBridge` listener matches on `event.data.type === pluginName + '.getInfo'` and calls `exec(..., pluginName, 'getInfo', [])`. This hardcodes a single action per plugin. Plugins with multiple actions (e.g., a future plugin that needs both `getInfo` and `watchChanges`) cannot be expressed through the current bridge contract without modifying `browser-bridge.js` and `browser-bridge-inject.js`. The protocol needs extension before additional native capabilities are surfaced.

5. **`cordova-plugin-network-information` is sourced from GitHub HEAD, not a published npm version.** The `package.json` dependency is `"github:apache/cordova-plugin-network-information"`. This means every `npm install` resolves to the current HEAD of that repository. There is no version pin. A breaking change pushed to the Apache GitHub repository will be silently incorporated on next install, with no lockfile protection if `package-lock.json` is not committed and respected. All other community plugins are pinned to semver ranges from npm, making this the only unpinned dependency.

6. **No offline fallback — not even a "you are offline" cached screen.** There is no service worker registered in `www/`, no Cache API usage, and no local html5core bundle bundled in `www/`. The only offline handling is the `catch` block in `tryLoadHostedApp()` which shows "Network Disconnected" and offers a manual retry. A FireTV device that reboots while offline will be completely non-functional until connectivity is restored. This is a meaningful gap for venue kiosk deployments where reboots may occur during off-hours maintenance windows.

7. **Cleartext traffic enabled in development config — easy to accidentally ship.** `config-development.xml` sets `android:usesCleartextTraffic="true"`. The build script selects the config file based on the script argument; the default is `development`. Running `./build-android.sh` with no argument produces a development build with cleartext traffic enabled and writes it to `out/vrtly-debug.apk`. If a developer sideloads this APK to a production device or distributes it informally, cleartext traffic is active in a production context. The release config correctly omits this flag, but there is no CI gate that enforces the release config for distributed builds.

8. **The shell's fetch-then-open startup pattern creates a race condition opportunity.** `tryLoadHostedApp()` fetches the S3 URL to check availability, then calls `cordova.InAppBrowser.open()` with the same URL. Between the `fetch()` response and the `InAppBrowser.open()` call, the S3 content could theoretically change (a deployment in progress). More practically, the `fetch()` returns the HTTP headers only — the body is not read — so S3 could serve a `200` on a partially uploaded or malformed `index.html`. The shell has no content validation; it opens whatever S3 serves.

9. **`cordova-plugin-fire-tv` dependency pins the shell to Amazon's Fire OS ecosystem.** The `cordova-plugin-fire-tv` plugin handles Fire OS-specific lifecycle events (pause, resume, visibility). Its presence in `package.json` means the shell is not straightforwardly portable to standard Android TV or other Android devices without removing or conditionally disabling this plugin. If Vrtly were to expand to non-Fire TV Android hardware, this dependency would need assessment.

10. **RAM monitoring rationale is undocumented.** `ai.vrtly.raminfo` provides 14 memory metrics with high precision (system total/available/used, PSS, JVM heap, native heap, three derived percentages). The plugin is wired through the browser bridge to html5core, suggesting html5core actively queries RAM state. There is no documentation of why RAM monitoring is needed — whether it drives UI adaptation (reducing quality under memory pressure), feeds diagnostic telemetry, triggers a memory-pressure warning to the user, or serves another purpose. Without this context, it is unclear whether the metric set is sufficient or over-specified.

11. **Splash screen is configured to show on every launch, not just first launch.** `SplashShowOnlyFirstTime` is set to `false` in both configs. On every cold start, the user sees the splash for the full 3000ms `SplashScreenDelay` before the loading view appears and the S3 fetch begins. The total time from cold start to visible html5core is: splash delay (3000ms) + S3 fetch RTT + InAppBrowser load time. This is a non-trivial cold-start latency floor on devices where S3 RTT may be 200–500ms and html5core bundle load adds additional time.

12. **The `<content src>` in config XML and the `HOSTED_APP_URL` constant in `index.js` are not automatically kept in sync.** The config XML `<content src>` and the JavaScript constant `HOSTED_APP_URL` in `www/js/index.js` both reference the production S3 URL. The README's comment on `index.js` — `// do not forget to update the meta tag in index.html` — indicates this is a known manual sync requirement. Similarly, `index.html`'s Content Security Policy `connect-src` allowlist names the S3 domain explicitly. A URL change (e.g., switching to the beta endpoint) requires coordinated edits in at least three places with no build-time enforcement that they match.

---

## Open Questions

1. **Update delivery model — confirmed remote-only.** Both `config-development.xml` and `config-release.xml` set `<content src="https://html5core.s3.us-west-2.amazonaws.com/index.html" />` with no local bundle reference. `www/js/index.js` independently fetches and opens the same URL. There is no `www/` bundled html5core, no service worker, and no local fallback. Every launch is a live S3 fetch. The risk this confirms: a device that cannot reach S3 cannot run the application at all.

2. **Versioning contract with html5core — there is no formal contract.** The shell and html5core version independently with no shared contract document, no minimum-shell-version declaration in html5core, and no shell-side version gating. The only implicit contract is the bridge protocol shape (`<PluginName>.getInfo` / `<PluginName>.response`) and the device data fields returned by `cordova-plugin-device`. html5core may add calls to `window.RamInfo.getInfo()` or `window.Device.getInfo()` expecting new fields, and older shells will not provide them. The risk is silent capability mismatch: html5core's graceful-degradation behavior when a bridge call fails or returns unexpected data is not documented in this repository.

3. **Is there an active browserbridge usage in html5core?** `browser-bridge-inject.js` wires `RamInfo` and `Device`. It is not clear from the shell repository whether html5core currently calls these stubs, how frequently, and what it does with the data. The bridge was built for a purpose, but the consumption side is not visible here.

4. **What governs the beta S3 endpoint selection?** The beta URL (`https://html5core-beta.s3.us-west-2.amazonaws.com/index.html`) is present in the navigation allowlist of both configs and was previously the active URL (commented out in `index.js`). There is no environment variable, build flag, or toggle to switch between production and beta at build time without editing `index.js`. Is there an intended workflow for staging html5core releases through beta before promoting to production? If so, the current mechanism requires a code change.

5. **What happens if the InAppBrowser session terminates unexpectedly?** If the InAppBrowser closes (user pressing Back on FireTV, a crash inside html5core, or a `close` event), the shell's loading view is still the active page underneath. There is no `InAppBrowser.addEventListener('exit', ...)` handler in `www/js/index.js` to detect closure and re-launch or show a recovery UI. The user would be left on the "Please wait" screen with no path back to the application.

6. **Is the `cordova-plugin-fire-tv` plugin receiving upstream maintenance?** The plugin is pinned at `^1.1.0` on npm. Amazon's Fire TV web app documentation references have historically been inconsistent, and third-party Cordova plugins for Fire TV have varied maintenance levels. The Cordova 13 platform update may have changed lifecycle event handling in ways that affect this plugin's behavior. There is no test harness in this repository to validate FireTV-specific lifecycle events.
