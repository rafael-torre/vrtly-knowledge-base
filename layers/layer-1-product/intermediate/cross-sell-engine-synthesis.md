---
title: "Cross-Sell Engine Synthesis — CPO Brief (May 2026)"
last_updated: "2026-06-01"
source: "raw-inputs/vrtly_cross_sell_engine_1.pdf"
---

# Cross-Sell Engine Synthesis — CPO Brief (May 2026)

Source: Internal CPO brief authored by Joe Schooler, May 18 2026. Two-page technical product overview of the Automated Cross-Sell Engine. Treated as a primary product input, not a final document.

---

## Overview

→ *maps to: `final/product-brief.md`, `final/features/`*

The Automated Cross-Sell Engine turns Vrtly's existing screen presence in aesthetics practices into a revenue-optimization layer by integrating with clinic EMR/booking systems. By ingesting appointment and invoice data, Vrtly can identify which patient is in the clinic, what they have historically purchased, and — modeled against patterns across all Vrtly-connected practices — predict what they are likely to buy next. The system then uses that signal to serve the right content on the right screen at the right moment, and attributes resulting purchases back to the content that influenced them.

---

## The Five-Step Flow

→ *maps to: `final/features/cross-sell-engine.md` (or equivalent feature spec)*

**Step 0 — Service Catalog Normalization**

Practices use inconsistent names for the same treatment (e.g., "Botox 20u forehead", "BTX glabella", "wrinkle relaxer upper face"). Vrtly maps every practice's service menu onto a single proprietary canonical taxonomy. Network effects apply: the more practices join, the more accurate the mapping becomes. See [Service Classifier](#service-classifier--how-it-works) section for detail.

**Step 1 — Cross-Sell Path Discovery**

Vrtly reads every booking and invoice record to surface the practice's actual cross-sell patterns — e.g., *Injectables → Skin Care · 96 guests · avg $1,063 second visit · 40 days between visits*. Described as a novel insight for most practices based on Vrtly's UX research panels.

**Step 2 — Practice Goal Setting**

Practices select what they want to grow: fill low-demand appointment slots (e.g., Tuesday Botox), convert patients from one category to another (e.g., Injectables → Skin Care), or re-engage lapsed high-value patients (90-day-lapsed VIPs).

**Step 3 — Smart Playlists**

A propensity-to-buy model (gradient-boosted decision trees — XGBoost / LightGBM) selects content for each day's patient cohort based on the practice's goals and identified cross-sell patterns. Playlists are generated automatically; no manual scheduling required.

**Step 4 — Clinic-Aware Screen Delivery**

Screens are aware of the day's schedule in real time: who is in the lobby, who is in which treatment room, and what each patient came in for. Content adapts to match. A Scheduler view demonstrating this is live in the current working prototype.

**Step 5 — Attribution**

Every patient who was exposed to a piece of content and subsequently purchased the advertised service is matched back to the content. This closes the loop: screens receive credit for the sales they influenced, giving practices and brands a measurable ROI signal.

---

## EMR Integration — Zenoti

→ *maps to: `final/product-brief.md`, `final/features/`*

Zenoti is the first EMR connector. Current live status:

- **Deployments:** 2 centers live
- **Data volume:** ~5,000 appointments cached
- **Revenue under management:** ~$1.3M

The integration is the data foundation for Steps 1, 3, 4, and 5 above. Additional EMR connectors are implied as future work but not specified in this document.

---

## Service Classifier — How It Works

→ *maps to: `final/features/cross-sell-engine.md`, `final/domain-glossary.md`*

The classifier normalizes practice service catalogs into Vrtly's canonical taxonomy via a five-stage pipeline designed to minimize model inference costs:

1. **Ingest.** Pull raw service name strings from the EMR (Zenoti).
2. **Match.** Exact and fuzzy matching against Vrtly's proprietary canonical taxonomy, combined with the practice's prior confirmed mappings and network-wide aliases. Most items resolve at this stage with no LLM call.
3. **Custom classification with Claude Haiku 4.5.** Residuals that did not match in Step 2 are sent to a customized Claude Haiku 4.5 instance. The prompt includes the practice's confirmed mappings as in-context examples. Output: category, confidence score, and alternates.
4. **Human review.** Items below the confidence threshold surface in a one-click yes/no UI. Every confirmation is persisted per-practice and propagated as an alias across the network.
5. **Nightly enrichment.** An agent searches Google overnight on stubborn unknowns and surfaces additional context to the modeling layer. Internal experiments show ~40% improvement in classification accuracy across the long tail.

---

## Technology Notes

→ *maps to: `final/features/` (implementation-facing notes for Layer 3 handoff)*

| Component | Technology | Notes |
|---|---|---|
| Propensity-to-buy model | XGBoost / LightGBM (gradient-boosted decision trees) | Powers smart playlist generation (Step 3) |
| Service classifier LLM | Claude Haiku 4.5 (Anthropic) | Custom-tuned with per-practice confirmed mappings as in-context examples |
| Nightly enrichment | Agent with Google Search access | Targets stubborn unresolved service names; ~40% lift on long-tail classification |
| Prototype | Live at prototypes.vrtly.ai | Scheduler view (Step 4) confirmed live |
| Patent | Provisional patent filed | No patent ID referenced in this document |

---

## Key Terms

→ *maps to: `final/domain-glossary.md`*

| Term | Definition |
|---|---|
| Cross-sell path | An observed sequence of service purchases within a patient cohort — e.g., Injectables → Skin Care — including guest count, average second-visit revenue, and days between visits |
| Canonical taxonomy | Vrtly's proprietary normalized list of aesthetics services, shared across all connected practices |
| Propensity-to-buy model | A gradient-boosted decision tree model that scores which services a given patient is likely to purchase next, based on historical patterns across the Vrtly network |
| Smart playlist | An automatically generated content schedule for a given day's patient cohort, built by the propensity model against the practice's stated goals |
| Clinic-aware | Describes a screen that has real-time access to the day's appointment schedule and adapts content to the patient currently in front of it |
| Attribution | The process of matching a patient who was exposed to a content item to a subsequent purchase of that item — the system by which screen influence on revenue is measured |
| Human review queue | The one-click UI where low-confidence classifier outputs are surfaced for staff confirmation; confirmations persist per-practice and propagate network-wide |
| EMR connector | The integration layer between Vrtly and a practice's electronic medical record / booking system (currently: Zenoti) |
| Nightly enrichment agent | An automated agent that runs overnight and queries Google to resolve service names the classifier could not confidently categorize |

---

## Open Questions / Gaps

→ *flags for gap analysis or feature spec clarification*

- The propensity model (Step 3) is described at the output level but the training data, update cadence, and cold-start behavior for new practices are not specified. These are required inputs for the Layer 3 feature technical spec.
- Step 2 (goal setting) describes three goal types — slot fill, category migration, and lapsed VIP re-engagement — but the UX for configuring these goals is not described. It's unclear whether this is a self-serve interface or requires Vrtly staff configuration.
- Attribution (Step 5) requires matching content exposure to purchase; the matching mechanism (e.g., patient ID linkage, time-window-based attribution, probabilistic vs. deterministic) is not described.
- The document references "every other practice on Vrtly" as the basis for network-level modeling. The minimum network size required for the propensity model to produce reliable predictions is not stated — relevant for understanding the product's scalability threshold and cold-start risk.
- Additional EMR connectors beyond Zenoti are implied but not named. Roadmap and timeline are absent from this document.
