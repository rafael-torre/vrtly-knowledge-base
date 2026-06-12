---
title: "Platform Capabilities Overview"
last_updated: 2026-06-12
---

# Platform Capabilities Overview

## What This Platform Does

Vrtly is a two-sided marketplace that connects healthcare practices with pharmaceutical and healthcare brands. Practices install display screens in their waiting rooms and manage what plays on them. Brands buy access to those screens to run advertising and distribute educational materials to clinicians and patients. The platform handles everything in between: uploading and processing media, assembling what plays on each screen at any given time, delivering it to physical devices, and reporting back on what played and how audiences engaged.

Layered on top of the ad delivery function is a second product mode — interactive clinical consultations — in which a clinician walks a patient through a curated set of content during an appointment. Patients can also receive follow-up educational materials via a QR code on the screen that leads to a branded landing page. This makes Vrtly simultaneously an advertising platform, a clinical education tool, and a patient engagement channel, all running on the same screens and managed through the same portals.

---

## Platform Users and Roles

**Practice Administrators (Providers)**
Staff at a healthcare practice responsible for setting up and managing the waiting-room screens. They register and activate physical display devices, organize and upload content, control which brands are permitted to advertise in their space, and initiate or review clinical consultation sessions. They may be on a free tier with limited capability or a paid tier with broader access.

**Brand Managers (Sponsors)**
Employees of pharmaceutical or healthcare brands running campaigns on provider screens. They upload creative assets, configure campaign goals and scheduling, distribute consult materials to practices, and review campaign and engagement performance. Their access to the platform is commercially tied to relationships with individual practices.

**Patients**
End users who see content on waiting-room screens and may interact with QR codes to access educational materials on their own devices. The platform generates encrypted links that direct patients to a separate public-facing destination. Authentication in that flow appears to use a one-time code sent via SMS.

**Platform Operators (Administrators)**
Internal staff who oversee the health of the platform: managing organizations, monitoring device and content issues, resolving billing matters, and accessing diagnostic dashboards not visible to providers or brands. This role has elevated access beyond what either commercial user type can see.

---

## Capability Areas

### Screen and Device Management

Providers can register physical display devices to their practice account by scanning a pairing code shown on the screen. Once activated, each device is associated with the practice and begins receiving content. If a device restarts or loses power, it re-registers automatically on boot — but playback does not resume until a network connection is available. The platform requires an active internet connection on every startup to load content; there is no local cache or offline fallback. Until connectivity is restored, the screen displays a waiting state and cannot play content.

The platform keeps the screen awake while the app is running — the display will not sleep or dim during playback without an explicit OS-level power event.

The platform identifies each physical device by its hardware model and a unique device identifier, which feeds device-level diagnostics and status reporting. The confirmed hardware platform for display devices is Amazon FireTV.

Providers can maintain a library of registered screens, organize them, and control what content appears on each one.

**Who uses it:** Practice Administrators
**Key behaviors:** Pairing a new screen, reviewing which screens are active, associating screens with a practice account

---

### Content Upload and Processing

Providers can upload video files or pull in content from social media accounts (such as Instagram or Facebook posts) or from YouTube. Uploaded content is automatically processed into formats suitable for playback across different network conditions — this happens without any action required from the uploader.

Once processing is complete, content becomes available for use in playlists. If processing fails or the content cannot play reliably on a given screen, the platform removes it from rotation on that screen automatically.

Brands can also upload creative assets for their advertising campaigns through their own portal.

**Who uses it:** Practice Administrators (for general and social content), Brand Managers (for campaign creative)
**Key behaviors:** Uploading a video, linking a social media account, adding a YouTube video, waiting for content to become available

---

### Playlist and Programming Management

Providers can organize their approved content into sequences that control what plays on their screens. The platform also automatically inserts brand advertising into the rotation based on commercial agreements and scheduling rules. The logic that determines which brand content plays, at what frequency, and on which screens is governed by the platform and is not directly configurable by the provider.

Brands define how much of the available screen time they want to occupy across the provider network, and the platform allocates slots accordingly. This allocation engine is the core of the marketplace — it is the mechanism by which brand spend translates into screen time at specific practices.

The scheduling engine is aware of each practice's operating hours and only schedules content during business hours. Within those hours, the engine further adjusts the content mix based on patient traffic volume at different times of day — periods of high patient volume are treated differently from quieter periods. This means a brand's content is weighted toward the moments when the most patients are in the waiting room, without any manual configuration from the provider or brand.

**Who uses it:** Practice Administrators (programming their own content), Brand Managers (configuring campaign targeting and share of screen time), Platform Operators (oversight)
**Key behaviors:** Building a content sequence, setting a campaign budget and target, reviewing scheduled plays

---

### Campaign Management

Brand Managers can create and manage advertising campaigns with defined goals, budgets, date ranges, and target metrics — either a fixed number of views or a percentage of screen time. Campaigns are associated with creative assets and distributed across the screens of enrolled practices.

The architecture confirms campaign entities exist with both impression-based and time-share-based targeting options. The detail of what targeting parameters brands can configure beyond these basics — such as practice specialty, geography, or audience profile — is not confirmed from what the platform exposes today and requires clarification with the client.

**Who uses it:** Brand Managers
**Key behaviors:** Creating a campaign, uploading creative, setting target impressions or time share, reviewing campaign status

---

### Clinical Consultations

In consultation mode, a clinician can trigger an interactive presentation on the waiting-room screen during a patient appointment. The screen shifts from passive signage to a guided slide-by-slide experience. Each step is tracked, so practice and brand reporting can reflect actual clinical engagement — not just passive viewing.

Brands can create and distribute consultation materials to practices. Providers can manage which consultation content is available on their screens. The architecture shows this as a deeply embedded capability, not a bolt-on feature — the same display device handles both ad playback and consultation delivery.

Some consultation endpoints in the platform appear to be in the process of being phased out or replaced, suggesting active development in this area.

**Who uses it:** Practice Administrators (managing available consultation content), Clinicians at the practice (running a consultation during an appointment), Brand Managers (distributing consultation materials)
**Key behaviors:** Triggering a consultation session, navigating through a consultation, reviewing per-step engagement

---

### Patient Information Packs

During or after a consultation, the platform can display a QR code on the screen that a patient can scan with their phone. That QR code leads to a branded educational materials page where the patient can access downloadable content relevant to their care. The QR link is generated in a secure way that ties it to the specific content being shown.

There is a separate patient-facing destination for this flow that is distinct from the provider and brand management portals. Patient authentication in that destination appears to use a one-time code sent by text message.

**Who uses it:** Patients (accessing materials), Clinicians and Providers (generating the QR experience), Brand Managers (creating info-pack content)
**Key behaviors:** Generating a QR code on screen, patient scanning and receiving materials, tracking which info-packs were accessed

---

### Analytics and Reporting

The platform collects data throughout the content lifecycle: what played on which screen, for how long, at what quality, and whether the content was part of an ad campaign, a consultation, or a standard playlist. This data feeds reporting surfaces available to both providers and brands.

For providers, the reporting covers screen activity and consultation engagement. For brands, it covers campaign delivery: how many times their content was shown and how consultations they distributed performed.

The platform also generates proof-of-play records for brand campaigns — a verified log of what played, on which screens, and when — and SOV compliance reports that confirm each brand received the share of screen time it was contracted for. These are distinct from standard impression counts and are relevant to brand procurement and legal verification workflows.

The connection between passive ad impression data and active consultation engagement data — giving a brand a unified view of ROI across both channels — is not confirmed from the current architecture view. Whether a brand can see both in a single report is an open question.

**Who uses it:** Brand Managers (campaign and consultation performance), Practice Administrators (screen and engagement activity), Platform Operators (platform-wide diagnostics)
**Key behaviors:** Reviewing impression counts, reviewing consultation completion rates, viewing screen activity summaries

---

### Subscription, Billing, and Hardware Management

Providers subscribe to the platform under a tiered model, with different tiers unlocking different capabilities — including screen limits, consultation access, and the ability to accept custom branded content. Stripe handles subscription billing and payment processing.

The platform also has a hardware ordering and fulfillment capability: practices can order display devices directly, and the platform manages shipping. This suggests Vrtly operates a hybrid model — selling or provisioning the physical hardware alongside the software subscription — though whether a practice must purchase hardware from Vrtly or can use their own compatible device is not confirmed.

**Who uses it:** Practice Administrators (subscribing, upgrading, ordering hardware), Platform Operators (billing management, order fulfillment)
**Key behaviors:** Subscribing to a plan, upgrading a tier, placing a hardware order, receiving a device

---

### Platform Administration

Platform Operators have access to diagnostic and operational tools not available to providers or brands. This includes monitoring which content has been removed from rotation due to playback failures, reviewing system-level performance data, managing organization accounts, handling billing exceptions, and scheduling automated platform maintenance tasks.

**Who uses it:** Platform Operators
**Key behaviors:** Reviewing flagged content, managing organizations and users, accessing platform-wide diagnostics

---

## Open Questions for the Client


1. **Is the boundary between provider and brand access enforced on the server, or only in the browser?** Routing a logged-in user to the correct portal is currently done client-side. Whether the server rejects requests from a brand attempting to use provider-only functions — and vice versa — is not confirmed. If enforcement is only in the browser, a technically capable user could access functions they should not.

2. **Does the reporting surface give brands a unified view of ad impressions and consultation engagement?** Brands invest in both passive campaign placements and active consultation content distribution. Whether the platform connects those two data streams into a single ROI view per campaign is not confirmed. If it does not, brands have no way to measure the full value of their presence on the platform.

3. **How visible is content quality and quarantine status to providers and brands?** When a piece of content is automatically removed from rotation on a screen due to repeated playback failures, neither the provider nor the brand appears to receive a notification or see a status indicator in their portal. A sponsor whose content stopped playing has no diagnostic path to understand why their impressions dropped.

4. **What is the reliability expectation for network connectivity at practice venues, and is offline resilience a platform requirement?** The platform requires a live internet connection on every device startup to load content — there is no local cache or offline fallback on the display device. A device that reboots while offline will remain non-functional until connectivity is fully restored. For venues where network reliability cannot be guaranteed (or where reboots may occur during off-hours), this is a meaningful gap. The client should confirm whether offline resilience is a product requirement, and if so, what the acceptable recovery window is.

5. **What is the current state and strategic direction of the consultation feature?** Some consultation-related functions appear to be marked for removal or replacement, while the broader feature is clearly active and embedded deeply in the platform. Is consultation a core differentiator being actively invested in, or a capability that is being wound down or redesigned?

6. **What targeting controls do brands actually have when configuring a campaign?** The allocation engine is confirmed to enforce share-of-voice percentage targets and impression-based goals, respects campaign date ranges, and distinguishes between paid and freemium tiers. What remains unconfirmed is whether brands can target by practice specialty, patient demographic, geography, or other practice-level attributes — and whether any such filters are enforced at the allocation level or only applied at campaign setup.
