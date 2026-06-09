---
title: "Roundtable — Architecture Discovery"
last_updated: 2026-06-09
---

# Roundtable: Architecture Discovery

## Participants
- Winston — System Architect
- John — Product Manager

---

## Discussion Transcript

**Winston:** Let me walk you through what we found. At the highest level, Vrtly is a two-sided marketplace platform: providers on one side managing waiting-room screens, sponsors on the other running advertising campaigns. The system connects them through a content lifecycle pipeline — upload, transcode, playlist resolution, and delivery to physical devices. We have four fully analyzed services and about a dozen that are referenced but not yet documented.

**John:** Before you go further — when you say "two-sided marketplace," what does that actually mean in practice for each side? What can a provider do that a sponsor cannot, and vice versa?

**Winston:** Good question. The split is clean in the architecture. Providers use the VPM portal — they manage their physical screens, organize content into playlists, control which brands appear in their waiting rooms, and track patient engagement through consult and info-pack flows. Sponsors use the VAM portal — they create ad campaigns, upload creative assets, configure share-of-voice targets, and distribute branded consult materials to providers. Both portals are separate Vue 3 applications in the same monorepo but they share no route space and have distinct data access patterns. The routing decision — PROVIDER goes to VPM, SPONSOR goes to VAM — is made client-side based on `organization.type` in localStorage at login.

**John:** That last part is a flag for me. If that routing is entirely client-side and based on a value in localStorage, what prevents a sponsor from manually navigating to the provider portal? Is there server-side enforcement of which portal each org type can access?

**Winston:** The navigation guard in VPM's `permission.ts` redirects sponsors out, but you're right — it's client-side only. There is a `TokenBasedAuthenticationFilter` on the backend that authenticates every request, but the API-level authorization between provider and sponsor access scopes is not fully visible from the current analysis. Whether the backend enforces org-type boundaries on specific `/cms/**` endpoints, or whether it relies on the frontend gating, is an open question. We'd need to spike the authorization model in `fmcom-api`'s controller layer.

**John:** OK. That's a material product risk. If the boundary is only enforced in the browser, a savvy sponsor could access provider-only screens or content management functions. Let's flag that for the client.

**Winston:** Agreed. Now, here's the first architectural observation with direct product implications. The platform has a sophisticated server-side ABR mitigation engine in the player API. It's a six-stage escalation ladder — HLS full quality down through lower-resolution MP4 variants and ultimately to quarantine — and it operates autonomously based on telemetry from the devices. The system monitors playback decode failures and network degradation, then automatically degrades the content variant served to a specific screen without any operator action. When it reaches QUARANTINE, content stops playing on that screen entirely.

**John:** Does a provider ever see this happening? Is there any surface in the portal where they know a piece of content has been quarantined or that their screen is playing at degraded quality?

**Winston:** There is a diagnostics dashboard — it reads MITIGATION events from Elasticsearch — but it appears to be in the admin layer of `fmcom-api`, not in VPM. From the analysis, there is no confirmed user-facing surface in the provider portal that exposes playback quality status or quarantine state per screen or per content item.

**John:** That is a significant product gap. Providers are paying for screen-time and sponsored content. If a piece of content is silently quarantined because of a bad transcode, the provider has no idea why their screen has stopped showing it, and the sponsor has no idea their content stopped running. The analytics side of this is also broken — impressions and played-content reports still flow to Elasticsearch, but if content is quarantined and not actually playing, are those impression counts accurate?

**Winston:** That is a valid concern. The telemetry pipeline reports playback events, and the escalation ladder advances based on decode failures — so quarantined content should have near-zero playback events. But whether the advertiser-facing campaign reporting in VAM surfaces quarantine state as a reason for underperformance versus a general low-impression count, I cannot confirm from the current analysis. The ad campaign reporting lives in `fmcom-api`'s analytics index, and we have not spiked the reporting surface in VAM in detail.

**John:** So an advertiser could be looking at underperforming campaign numbers and have no diagnostic path to understand why. That is a product problem. What does the architecture say about how campaigns are structured? When a sponsor sets up a campaign, what controls do they actually have?

**Winston:** Campaigns in the architecture are defined by `AdCampaign` entities with a `targetType` of either REACH or SHARE_OF_VOICE, a CPM, requested impressions or percentage of time-on-screen, and a date range. The actual playlist slot resolution — which content plays at what time on which screen — is handled by the `rnf` service, which we have not yet analyzed. That service is the authoritative playlist resolver for both the CMS and the device-facing APIs. Both backend services call it via Feign HTTP, and `fmcom-api` sends media processing dispatch to it over JMS.

**John:** Wait — `rnf` is unanalyzed and it owns the core value proposition of the platform? SOV rules, ad slot assignment, audience targeting — all of that lives in a service we haven't looked at?

**Winston:** Correct. `rnf` — reach-and-frequency — is the most critical gap in this architecture review. We know it exists at `rnf.prod.vrtly.app`, that both backend services depend on it for playlist resolution, that the frontend env config for VAM references it, and that media processing jobs are dispatched to it via the message bus. But the algorithm it uses to assign slots, how it enforces SOV rules, how it handles targeting constraints or scheduling, and what happens when it is unavailable — all of that is unknown.

**John:** And the `PlaylistCurrentServiceLocal` in the player API — is that a fallback if `rnf` goes down?

**Winston:** It exists as a local playlist assembly path, but the analysis did not confirm whether it acts as a true circuit-breaker fallback to `rnf` or serves a different flow — possibly consult mode or custom playlists. Its relationship to the `rnf` dependency under degradation is unclear.

**John:** That's a resilience question the client needs to answer. If `rnf` is down, does content stop playing on every screen in the network? That is a catastrophic single point of failure for an operator. What is the SLA on `rnf`, and is there monitoring on it?

**Winston:** Not documented in the analyzed services. And there's a compounding factor: `fmcom-api` pins `fm-common` at version 8.9.0 and the player API pins it at 8.8.9. That shared internal library defines the JMS destination names, the Redis key constants, the domain model contracts between all services including `rnf`. A version skew of one minor version is present right now, and there is no documented compatibility matrix.

**John:** So you're telling me that two of the four core services are running different versions of the library that defines their shared data contracts, and nobody has documented which version of what is compatible with what. In a platform where playlist resolution goes through that shared contract, that is both a reliability risk and a deployment coordination risk.

**Winston:** Yes. And it gets more direct in product terms. The second observation I want to surface is the Consult and Info Pack feature set. The architecture reveals a full secondary product mode — Consultations — that transforms the display device from passive signage into an interactive tool for healthcare practitioners. In that mode, a clinician navigates a curated slide deck in the waiting room during a patient appointment. Per-step progress is tracked back to the API.

**John:** I know about Consults as a feature. But is it architecturally independent from the ad platform, or is it coupled?

**Winston:** It is deeply coupled, not independent. The `html5core` player runs both modes in the same application. The VPM and VAM portals both have consult management surfaces. The player API has a `ConsultController` and `ConsultService` handling active consult sessions. InfoPacks extend this — there is a full flow for generating encrypted QR codes that link to a patient-facing landing page (`my.vrtly.app`) for downloadable educational materials. What this implies is that Vrtly is not purely an advertising platform. There is a patient engagement and clinical education product layer embedded in the same technical platform, and it creates its own integration surface: the player app calls a separate CMS API endpoint just to generate QR encryption payloads, which is the only cross-domain call from a display device to the CMS backend.

**John:** That is something I want to probe more. The consult flow and info-pack flow have their own analytics: per-step tracking, visit statistics, content engagement per info-pack version. Is that data exposed to sponsors in the VAM portal? Because if a pharmaceutical brand creates consult materials, they presumably want to know how many times a clinician ran that consultation and whether patients engaged with the info-pack.

**Winston:** The data flows into Elasticsearch — consult tracking events, info-pack visit counts, impression reports. VAM has consult and info-pack management pages. But whether the campaign-level reporting in VAM links consult engagement data back to sponsor ROI metrics — that is a product question the architecture cannot answer without examining the VAM reporting layer in detail.

**John:** That is a gap for me. Brands are likely evaluating this platform partly on the consult distribution capability, not just passive ad impressions. If the reporting surface does not connect ad spend to consult delivery and patient engagement, sponsors have no way to measure the full value of the platform. That is a product-layer gap, but the architecture needs to confirm whether the data connections even exist.

**Winston:** Here is another architectural detail with product implications. The device registration flow uses a pairing model — the device displays a QR code, the provider administrator scans it in VPM to associate the screen with the organization. That activation state is polled by the player app every three seconds. Once activated, the device receives a session secret that is stored in memory only and lost on reload.

**John:** Lost on reload — so every time the device restarts, it goes through the full three-second-polling activation loop again?

**Winston:** Yes. The device re-registers and receives a new session secret on each boot. The MAC address is the persistent device identity. This has product implications for installation: a device that loses power — or crashes, which the watchdog handles by reloading the page — will have a visible activation polling screen and QR code displayed until the backend returns the session config. For a waiting-room screen, that is visible patient-facing downtime.

**John:** How long does re-registration take in practice? Is there a known SLA on the registration endpoint?

**Winston:** Not documented. And there is a compounding concern here: the `state` service — another unanalyzed gap — is called in hot paths by both backend APIs for screen lookups. If the state service is slow or unavailable, the registration flow could stall. We do not know the fallback behavior.

**John:** So we have two unanalyzed services — `rnf` and `state` — that sit in critical paths for core product flows: playlist delivery and device registration. That is a risk I would want the client to prioritize in the next spike phase.

**Winston:** Agreed. One more architectural observation relevant to the business model. There is evidence of multi-tier organization support in the data model: `OrganizationType` can be PROVIDER, BRAND, or INVENTORY, and `CustomerType` can be FREEMIUM or PREMIUM. The `ProviderSponsor` entity represents a contract between a brand and a provider, driving the `customerType` lifecycle. The `OrganizationFeaturesType` in the frontend defines feature entitlements across `FREE`, `BRAND_ONLY`, `PLUS`, and `PRO` tiers, including max screen limits, consult capabilities, and custom content.

**John:** That tiering model is interesting. So the platform has a freemium provider tier and a set of paid tiers, and different feature sets are gated by tier. Is that enforced server-side on the API, or is it client-side?

**Winston:** Feature flags are fetched from `/cms/systemParam/list` and cached in the frontend Pinia store. The frontend gates UI affordances by those flags. Whether the server-side API enforces tier-based access control on individual operations — preventing a FREEMIUM provider from calling endpoints that only PLUS or PRO customers are entitled to — is not confirmed from the current analysis.

**John:** That is a monetization risk, not just a security risk. If feature gating is client-only, a provider on the free tier could access premium functionality via direct API calls. And if the flags are memoized on the client with no TTL, a provider who just downgraded would continue to see premium features until they reload.

**Winston:** The memoization point is confirmed in the frontend spike. Flags are fetched once per session and cached indefinitely. A server-side flag change does not reach the client until a hard reload.

**John:** That is a billing and entitlement gap. Let me ask a different question. The architecture shows a YouTube downloader service, Meta social sync, Twilio OTP for patients. Who are those integrations for — providers, sponsors, or patients?

**Winston:** YouTube content upload is provider-facing — providers can add YouTube videos to their content library. Social sync via Meta is also provider-facing — pulling Instagram or Facebook posts as content. Twilio OTP is patient-facing — it is used for patient authentication in the consult or info-pack flows, likely when a patient interacts with a QR code. The `my.vrtly.app` public portal is the patient-facing side, but it is entirely unanalyzed. We know the player generates encrypted QR code URLs that point to it, but what the patient experience looks like, what the session model is, and whether any patient data is collected or stored are all unknown.

**John:** That last point is significant from a compliance and product standpoint. This is a healthcare platform. If patient data is being collected through the info-pack QR flow — even just a phone number for OTP — that has HIPAA implications. The architecture cannot tell us that right now, but it is a question we need to put on the table for the client.

**Winston:** Confirmed. The `my.vrtly.app` patient portal is the largest uncharted surface in the platform from a compliance perspective.

**John:** One more product question. The system map shows Stripe for billing and Shippo for hardware shipping. That implies Vrtly is also a hardware vendor — they are shipping physical devices to practices. Is the screen subscription model tied to hardware purchase, or can practices use their own devices?

**Winston:** The data model has `Order`, `OrderItem`, and `Invoice` entities alongside Stripe subscription management. The `Screen` entity has a `hardwareType` field. Shippo handles shipping label generation for hardware orders. The `ProviderSponsor` contract suggests a model where sponsor relationships upgrade provider customers from FREEMIUM to PREMIUM. Whether a provider must purchase hardware from Vrtly or can bring their own device and subscribe independently is not determinable from the architecture alone — it requires a product brief clarification.

**John:** That is a question about the go-to-market model, not just architecture. But the architecture revealing both hardware orders and SaaS subscriptions in the same data model suggests a hybrid model — and that has implications for onboarding, support, and pricing that the product layer needs to define explicitly.

---

## Resolved Points

1. **Two-portal architecture is technically sound but product-gating is client-side only.** VPM and VAM are correctly separated as distinct SPAs with distinct route spaces. However, org-type enforcement (PROVIDER vs SPONSOR) is confirmed to be client-side in the navigation guard, with server-side enforcement of per-org-type API access not confirmed. This should be validated with the client before assuming the boundary is secure.

2. **ABR mitigation is invisible to users.** The server-side escalation ladder (HLS_FULL through QUARANTINE) is architecturally sophisticated, but no user-facing surface in VPM or VAM exposes quarantine state or quality degradation at the screen or content level. Both participants agree this is a product gap that should inform the product spec for the analytics and diagnostics layer.

3. **Consults and Info Packs are a second embedded product, not just a feature.** The architecture shows a full secondary mode — interactive clinical consultations and patient education materials with per-step tracking — that coexists with the ad platform in the same technical layer. This is confirmed by the player app architecture, the provider and advertiser portals, and the patient-facing public portal. Whether this second mode is surfaced as a differentiated product line in the go-to-market is a product-layer question.

4. **`rnf` (reach-and-frequency) is the highest-priority unanalyzed gap.** Both the playlist delivery path and the media processing pipeline depend on it. Neither the resilience model nor the SOV algorithm is documented. Both Winston and John agree this service must be the first spike target in the next phase.

5. **`fm-common` version skew is a deployment coordination risk.** `fmcom-api` at 8.9.0 and `fmcom-player-api` at 8.8.9 share domain model contracts with no published compatibility matrix. Any breaking change in that library requires coordinated deployment across all consumers, and the risk is currently unmanaged.

6. **The platform is hybrid hardware + SaaS.** The presence of Shippo shipping, hardware orders, Stripe subscriptions, and tiered feature entitlements in the same data model confirms a hybrid business model. Product documentation should reflect this explicitly.

---

## Open Questions

### From Winston (Architecture)

1. **`rnf` resilience model**: If the reach-and-frequency service is unavailable, does playlist delivery fail entirely for all screens, or does `PlaylistCurrentServiceLocal` in the player API serve as a genuine circuit-breaker fallback? What is `rnf`'s SLA, and is it monitored? This needs a dedicated spike on the `rnf` service.

2. **`state` service authority boundary**: Both `fmcom-api` and `fmcom-player-api` call `ScreenStateClient` from `fm-common` for screen lookups in hot paths including device registration. Is the `state` service the authoritative screen registry, or is MySQL via `MySqlScreenModule` the source of truth? What is the failure behavior if `state` is unavailable during device re-registration?

3. **Horizontal scaling model for `fmcom-player-api`**: The in-memory `SessionHolder` and `WsSessionHolder` are node-local, meaning WebSocket connections and HTTP requests must land on the same ECS task to work correctly. Does the current ECS deployment use ALB sticky sessions? What is the scaling policy, and how is the silent cross-node drop handled operationally?

4. **Private key rotation**: `private_key.pem` and `prod_private_key.pem` — the RSA keys for CloudFront URL signing — are committed to the player API repository. Even if rotated, the git history retains them. Has remediation been performed, and what is the rotation cadence? Client confirmation required.

5. **`API_CONTENT_ADD` publisher identity**: The system map claims `rnf` publishes `API_CONTENT_ADD` to signal transcoding completion, but `fmcom-api` appears in both the publish and subscribe sets for that JMS destination in the spike evidence. Whether this is a self-loop within `fmcom-api` or an `rnf`-originated event cannot be determined without analyzing `rnf`. This ambiguity affects the content lifecycle data flow narrative.

### From John (Product)

1. **Patient data and HIPAA scope**: The `my.vrtly.app` patient portal is entirely unanalyzed. It receives encrypted QR code payloads from devices, may prompt patient authentication via Twilio SMS OTP, and presumably delivers info-pack content. What patient data is collected, stored, and retained through this flow? Is the platform designed to be HIPAA-compliant, and if so, what is the Business Associate Agreement surface?

2. **Sponsor ROI reporting**: Brands create consult materials distributed to providers and tracked per step. Does the VAM reporting surface connect consult delivery and patient engagement metrics back to campaign spend? If a pharmaceutical brand runs a campaign that includes both passive ad impressions and active consult sessions, can they see unified ROI data for both? This is a core value proposition question the architecture hints at but cannot confirm.

3. **Server-side entitlement enforcement**: Feature flags fetched from `/cms/systemParam/list` gate UI affordances in the frontend, but are they enforced server-side? If a FREEMIUM provider calls a PLUS-tier API endpoint directly, does the server reject the request? The memoization of flags on the client (no TTL, no server-push invalidation) means downgrades are not reflected until hard reload. Client confirmation needed on the entitlement model.

4. **Hardware vs. BYOD onboarding model**: The platform manages hardware orders through Shippo and Stripe, and screens have `hardwareType` fields. Is a provider required to purchase hardware from Vrtly to activate screens, or can they provision any compatible device (FireTV, Roku, Android TV) and subscribe without a hardware order? The answer affects onboarding, pricing, and support scope.

5. **Consult feature adoption and strategic positioning**: The `ConsultController` in the player API has endpoints marked `@Deprecated(forRemoval=true)`, while the broader consult feature appears active. What percentage of deployed screens use the consult mode? Is this a premium differentiator or a standard feature? The architecture suggests it is deeply embedded, but its product positioning relative to the ad platform is unclear.
