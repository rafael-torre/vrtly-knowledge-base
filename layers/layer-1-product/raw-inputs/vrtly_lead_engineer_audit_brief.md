# Vrtly Lead Engineer Audit Brief

## Purpose of this brief
This document is intended to onboard the lead engineer who will run the initial audit for Vrtly. It is meant to provide the context, priorities, operating posture, and audit expectations needed to enter the account effectively and credibly.

This brief intentionally excludes commercial details.

## Why this matters
Vrtly is not looking for a passive code reviewer. They need a senior technical leader who can quickly understand the business, product, architecture, failure modes, and delivery environment, then establish a practical path forward.

The immediate goal is not only to inspect the codebase. The immediate goal is to build trust by demonstrating strong engineering judgment, identifying the real causes of product quality issues, and producing a credible plan to improve reliability, monitoring, release confidence, and technical execution.

## What Vrtly does
Vrtly operates an advertising platform focused on elective aesthetic and cosmetic medical practices. Their ads are ultimately delivered through screens and related client experiences in doctor office waiting rooms.

The backend and broader ad network matter, but the endpoint experience is where the business succeeds or fails. If smart TV apps go blank, crash, disconnect, or degrade, the business impact is immediate regardless of how good the rest of the platform is.

## Why they are making this change
Vrtly is moving away from Vention. This is now considered a foregone conclusion on their side.

The proximate issue is product quality, especially smart TV app stability, release quality, and the inability of the current team to establish and execute a strong technical strategy.

The deeper issue is trust. Joe believes the current team has underperformed, failed to put in place the right telemetry and QA safeguards, and has required him to personally create engineering plans that should have come from the vendor.

Vention is currently in a short-term make-right phase on the blank-screen issue, but that does not change the longer-term transition away from them.

## What the client needs from us right now
They want proof, not promises.

Before a larger engagement, they want to see that we:
- have the right level of senior talent
- understand the actual technical problem
- can produce a grounded assessment
- can articulate a path to improved product quality and reliability
- are not learning the problem on their dime

The audit is the first trust-building motion.

## The stakeholder you need to be able to engage
### Joe
Joe is the critical technical and product stakeholder.

He is not a passive PM who just wants to hand over tickets. He is highly capable, sharp, and opinionated. He will assess whether you are thinking clearly, whether you can reason across systems, and whether you can talk to him as a peer.

He is looking for someone who can:
- understand the business and product context quickly
- reason about reliability, telemetry, QA, release discipline, and architecture
- distinguish symptoms from root causes
- create a path instead of waiting for perfect requirements
- demonstrate real engineering judgment

Do not approach Joe like a backlog recipient. Approach him like a technical partner.

## The immediate business problem
The central problem is smart TV and endpoint reliability.

The most important current issues include:
- smart TV apps going blank
- application crashes or disconnects
- incomplete telemetry around these failures
- slow root-cause analysis
- weak production quality and release confidence
- recurring regressions in client-side features
- insufficient automation and weak QA rigor

This is not just a code problem.
This is a product quality, observability, and operating model problem.

## Important mindset shift
Do not think of this as “audit the codebase and report issues.”

Think of this as:
- understanding how the product works in the real world
- identifying where failures occur and how they are currently detected or missed
- mapping technical, operational, and process gaps
- assessing where code, architecture, QA, release process, monitoring, and team behavior interact to create recurring incidents
- defining what has to change first to reduce business risk

## The platform landscape
Joe described the player ecosystem as multiple repositories / platform-specific applications:
- android_player for Google TV and their external HDMI device
- roku for RokuOS
- htmlcore_player for FireTV, Samsung (Tizen), and LG (WebOS)
- iOS for iPads and iPhones

This means the audit should not assume one codebase or one platform explains the entire problem.

You should be prepared to reason about:
- shared architectural patterns across players
- platform-specific failure modes
- release and QA differences between players
- how observability and telemetry may differ by environment
- how endpoint failures surface operationally to the business

## What “streaming experience” should mean here
Joe has made it clear that streaming/media-adjacent experience matters and is not optional from his point of view.

That said, the need should be interpreted pragmatically.

The account does not only need someone who understands media playback in theory. It needs someone who can reason through a real-world distributed endpoint problem that may include:
- playback failures
- rendering failures
- app lifecycle issues
- reconnect / retry behavior
- stale state after connectivity loss
- crash handling
- missing heartbeats
- poor remote diagnostics
- weak release safeguards
- bad production observability

The ideal posture is: determine quickly whether the dominant problem is playback/media-specific, platform/app-specific, connectivity-related, observability-related, process-related, or some combination.

## Reliability framing: what likely matters most
The immediate need may not be to eliminate every crash.

The immediate need is to create a system that is:
- observable
- diagnosable
- recoverable
- operationally manageable

In practical terms, that means the audit should strongly consider:
- how failures are detected
- whether devices / apps emit reliable heartbeats
- whether blank screens can be distinguished from app crashes, disconnected clients, content fetch failures, and backend issues
- whether restart / recovery behavior exists and works
- how quickly the team can know a screen is down
- how quickly the team can isolate likely cause categories
- how much of this is currently manual or anecdotal

## Production quality framing
A major client complaint is that features regress or break too often, and release confidence is low.

This means the audit should review not just runtime reliability, but also:
- QA strategy
- automated test coverage in meaningful paths
- regression prevention
- release process discipline
- staging / pre-prod validation
- rollback strategy
- defect escape patterns
- ownership of quality

Joe’s view is that too much of this should already have been automated or systematized.

## What success looks like for this audit
At the end of the audit, Vrtly should feel that we:
- understand their business risk clearly
- understand the product and platform context well enough to be dangerous
- can explain the likely problem domains without hand-waving
- can identify where code problems end and process / observability / release problems begin
- have a credible, phased path forward
- can lead the work rather than react to it

The audit should reduce uncertainty. It should not just catalog issues.

## Deliverables expected from the audit
Produce something that is clear, senior-level, and action-oriented.

Recommended outputs:

### 1. Executive assessment
A concise summary for technical and executive stakeholders that covers:
- what we reviewed
- what we believe the main problem areas are
- what appears to be causing the greatest business risk
- what we recommend doing first

### 2. Technical findings memo
A more detailed document that covers:
- architecture observations
- player/repo observations
- observability and telemetry gaps
- QA / release process gaps
- likely failure domains
- data / logging limitations
- operational concerns
- technical debt or design concerns relevant to reliability

### 3. Priority action plan
A phased plan with near-term and medium-term recommendations, such as:
- instrumentation / telemetry improvements
- uptime monitoring and alerting improvements
- failure classification and reporting
- release quality and QA changes
- reliability hardening workstreams
- one or two well-scoped proof projects or PRDs to demonstrate a different operating model

## Questions the audit should answer
### Business and product context
- What is the most important business risk created by current product quality issues?
- Which endpoint failures have the highest customer or revenue impact?
- How do these issues currently surface internally?
- What are the current KPIs, if any, for uptime, blank-screen incidents, app crashes, and defect escape?

### Architecture and product flow
- How is content delivered from backend to device?
- What are the major dependencies across backend, player, content delivery, and device state?
- Where are failures most likely introduced?
- Which parts of the system are shared versus platform-specific?

### Reliability and observability
- What events are currently logged?
- What client-side telemetry exists?
- Are heartbeats emitted?
- Can the team currently distinguish app crash vs blank screen vs disconnected client vs failed content load?
- How are failures surfaced to operations and support today?
- What is missing that would materially improve detection and diagnosis?

### Connectivity and endpoint operations
- How do devices behave under degraded or intermittent network conditions?
- What happens when apps lose connectivity and reconnect?
- What recovery behaviors exist today?
- Are there known issues around sleep, device lifecycle, power cycling, or remote environments?
- How are remote endpoint states monitored and recovered?

### Production quality and release process
- What test automation exists and where?
- What important flows are untested?
- How often do regressions occur?
- What is the current release process by platform?
- How are releases validated before production?
- How are bugs triaged and owned?

### Team and process
- Where is technical strategy currently weak or missing?
- Are there signs that the team has been treating symptoms instead of building systems?
- What parts of the process rely too much on manual effort or heroics?
- Where does the current operating model fail to produce quality predictably?

## How to work with Joe during the audit
### Do
- ask sharp questions about business impact and operating pain
- reflect back hypotheses clearly and quickly
- distinguish what you know vs what you suspect
- be transparent about where evidence is incomplete
- show systems thinking
- bring structure to the ambiguity
- connect technical changes to measurable business outcomes

### Do not
- wait for perfect PRDs before forming an opinion
- get lost in repo-level detail without relating it to business impact
- over-index on backend elegance while ignoring endpoint reliability
- hand-wave around monitoring or QA
- fake certainty where evidence is weak
- treat this like a normal engineering onboarding

## What to review first
Recommended first-pass sequence:
1. Business and product briefing from Joe
2. Existing documentation, architecture notes, incident context, and release process
3. Repo / player landscape and how each player is deployed
4. Current telemetry, logging, monitoring, and alerting setup
5. Known incident patterns around blank screens, crashes, and regressions
6. QA strategy, automation footprint, and release flow
7. One or two concrete examples of recent customer-impacting failures

## Audit priorities for the first 1-2 weeks
### Week 1
- absorb business and product context
- understand the player ecosystem
- review current architecture and deployment paths
- inspect telemetry and monitoring posture
- identify top gaps in failure detection and diagnosis
- review QA / release process and defect escape patterns
- meet Joe and key client participants in a structured technical working session

### Week 2
- validate or refine hypotheses
- identify likely high-risk failure domains
- outline immediate instrumentation and reliability recommendations
- identify one or two contained proof opportunities
- draft executive assessment and technical findings memo
- review findings with internal delivery and leadership before client presentation

## What good recommendations probably look like
Without pre-judging the code, strong recommendations may involve some combination of:
- better heartbeat and health-check instrumentation
- clearer failure-state classification
- improved client-side logging and crash reporting
- operational dashboards / alerting for endpoint health
- reconnect / recovery strategy improvements
- release gating or test automation improvements
- regression-focused QA priorities
- narrowing which incidents are platform-specific vs systemic
- reducing reliance on manual triage and anecdotal diagnosis

## What not to optimize for initially
Do not optimize for writing a perfect future-state architecture deck.
Do not optimize for broad roadmap ideation before understanding the current reliability problem.
Do not optimize for code cleanliness in isolation.
Do not optimize for proving how much AI can be used.

The immediate value is:
- clarity
- prioritization
- credibility
- reduced risk
- a believable path to improved quality

## Relationship context you should understand
This account has a high trust element around Ryan personally, but that trust will not transfer automatically to delivery. You need to earn it.

Joe is open to moving forward and there is clear upside beyond the immediate problem, including broader platform work and additional funded initiatives. But none of that matters if the first technical motion does not create confidence.

The audit is the bridge.

## Final operating principle
Act like the person responsible for helping Vrtly reduce its biggest business blocker, not like someone performing a generic engineering assessment.

The standard is not “found some issues in the code.”
The standard is “understood the system, understood the business risk, identified the likely causes of poor product quality, and created a credible path forward that a strong technical stakeholder would respect.”