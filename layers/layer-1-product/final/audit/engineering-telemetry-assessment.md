---
title: "Vrtly Engineering Assessment"
owner: "DualBoot Partners"
status: draft
last_updated: 2026-06-15
relates_to:
  - layers/layer-3-architecture/intermediate/telemetry-analysis-process.md
  - layers/layer-3-architecture/intermediate/html5core-telemetry-analysis.md
  - layers/layer-3-architecture/intermediate/html5core-telemetry-feasibility-assessment.md
  - layers/layer-1-product/intermediate/audit/html5core-telemetry-80pct-evaluation.md
  - layers/layer-1-product/intermediate/audit/audit_approach.md
---

# Vrtly Engineering Assessment

This document is the consolidated output of the Weeks 1–3 audit engagement. It covers three dimensions: telemetry coverage, release process, and QA. Each section states current state, what was found, and our read.

---

## Context and Scope

The audit scope is the active fleet: the approximately 50% of devices that will remain after the legacy hardware phase-out. Three players are in scope — html5core, Roku, and Android — each requiring its own workstream.

The three dimensions assessed are:

- **Telemetry:** Can blank-screen incidents be diagnosed without physical device inspection? Specifically, is 80% telemetry coverage achievable, in what timeframe, and with what team?
- **Release process:** How does a code change get from commit to device today, and what are the risks in that path?
- **QA:** What can QA realistically validate before a release ships, and what is the current gap?

**Architecture and ecosystem context** is documented in the layer-3 architecture knowledge base — system map, tech spikes for each service, flow documentation. This assessment builds on that foundation and does not repeat it. Readers unfamiliar with the platform should start with `layers/layer-3-architecture/intermediate/system-map.md`.

---

## 1. Telemetry — 80% Coverage

> **Status: TBD — analysis pending for all three players.**

This section will document, per player (html5core, Roku, Android):

- **Evaluation approach:** How flows were mapped, what counts as "covered," and how the blank-screen scenario inventory was used as a reference.
- **Current state:** Baseline signal coverage — blank moment logged, recovery logged, causal context preserved.
- **What needs to be built:** Findings inventory by category (instrumentation gaps, kill zones, structural), with fixability assessment.
- **Viability and timeline:** Whether 80% coverage is achievable, in what timeframe, and under what definition of coverage.
- **Team required:** Roles and effort needed for implementation, separate from release overhead.

---

## 2. Release Process

> **Status: TBD — analysis pending.**

This section will document:

- **Current release flow:** How a code change in html5core, Roku, or Android goes from commit to device today. Who triggers a release, what the promotion steps are, and how long each step takes.
- **Known facts (from audit brief):** No canary deploys. No rollback path. Releases go out to the full fleet.
- **Key gaps:** What is missing or at risk in the current process — automated test gates, staged rollout capability, rollback mechanism.
- **Recommendations:** What to address and in what order, given the telemetry implementation work that will be shipping through this same pipeline.

---

## 3. QA Approach

> **Status: TBD — analysis pending.**

This section will document:

- **Current QA scope and practice:** What is tested today before a release ships, and how.
- **QA constraints:** Known constraint: 1 QA engineer for device regression. No reliable staging environment. Regression pass requires physical devices (FireTV, webOS, Tizen).
- **What QA can realistically validate:** Emulators, canary on a real-device subset, or full-fleet regression only. What coverage each option provides.
- **Recommendations for the telemetry phase:** What QA needs to validate specifically for the telemetry instrumentation changes, and what the minimum viable QA bar looks like given current capacity.

---

## 4. Telemetry Changes — Delivery Timeline

> **Status: TBD — depends on Sections 1, 2, and 3.**

This section is distinct from Section 1 (implementation timeline). Implementation timeline = how long it takes to build and validate the code. Delivery timeline = how long it takes for those changes to be observable in production on devices — which is gated by the release process and QA capacity.

This section will document, per player:

- **Player change delivery:** Release cadence, regression cycle duration, and fleet rollout milestones.
- **Backend change delivery:** Independent deployment path and sequencing constraints.
- **Combined delivery view:** End-of-month milestones across both player and backend changes, with scenario coverage projections.

---

## 5. Open Questions

> To be populated as analysis progresses.
