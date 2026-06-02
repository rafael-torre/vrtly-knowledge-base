---

## title: Domain Glossary
layer: product
owner: ""
last_updated: "2026-06-02"
relates_to:
  - layers/layer-1-product/intermediate/pitch-deck-synthesis.md
  - layers/layer-1-product/intermediate/brand-partnerships-synthesis.md
status: in_progress

# Domain Glossary

Shared vocabulary for the product. This glossary defines domain-specific terms used across all product documentation and downstream layers. It is one of the most valuable documents for AI-assisted development — when every layer uses the same terms with the same meanings, ambiguity is eliminated from requirements through to code.

Update this glossary whenever a new domain term surfaces during product definition. If stakeholders use different words for the same concept, or the same word for different concepts, resolve it here.

---

## Terms

> **Guiding questions:**
>
> - Does this term have a domain-specific meaning that differs from common usage?
> - Do different stakeholders use different words for the same concept?
> - Would a new team member or an AI tool misinterpret this term without context?
>
> Add terms as they surface during product definition. This table grows over time.


| Term | Definition | Context / Notes |
| ---- | ---------- | --------------- |
| **POC / Point of Care** | The physical location inside a clinic where a patient receives or considers a treatment — the primary targeting context for Vrtly content delivery. | Also called "Point of Decision" in brand-facing copy. 80% of aesthetic treatment decisions happen here. |
| **Practice** | A medical aesthetics business (medspa, dermatology clinic, plastic surgery office) that hosts Vrtly screens and delivers brand content to patients. | The supply side of Vrtly's two-sided marketplace. Also referred to as "provider" in some contexts. |
| **Brand** | An aesthetics product or device company (e.g., Hydrafacial, Allergan, Restylane) that advertises through Vrtly. | The demand side of Vrtly's two-sided marketplace. |
| **Platform Brand** | A brand that has paid for the Vrtly Ad Manager platform subscription; receives 2× more ad space than non-platform brands. | Distinct from brands that only run ad campaigns without a platform subscription. |
| **Free Screens** | Practice screens funded by brand advertising; 80% SOV is available to brands; free for the practice to activate. | Practices choose which brands to feature (select ≥2 brands). |
| **Pro Screens** | Paid screens with 100% SOV control for the practice. Priced at $99+/mo. | Used for consultation tools, open house, pricing boards, and full marketing control. |
| **Vrtly Ad Manager** | The brand-facing interface for uploading content, planning campaigns, and viewing real-time analytics. | Also referred to as "Vrtly Ad Manager Platform." One canonical name is needed — see Open Questions. Functions as the Demand-Side Platform (DSP). |
| **Vrtly Practice Portal** | The practice-facing Smart TV app for selecting brands, activating screens, and managing custom content. | Also referred to as "Vrtly Practice Manager." One canonical name is needed — see Open Questions. Functions as the Supply-Side Platform (SSP). |
| **Vrtly Ad Exchange** | Vrtly's central AI-powered matching layer that connects brands to practices programmatically. | Sits between the Ad Manager (DSP) and Practice Portal (SSP). Handles optimization and gold-standard video ad serving. |
| **Smart Playlist** | An AI-curated screen playlist that dynamically selects content based on patient and practice context. | Also written as "SmartPlaylist." Live feature. |
| **Info Pack** | A digital, trackable document (brochure replacement) delivered via QR code; includes patient education materials. | Coming Q2 2026. Cited to have 2–3× higher read rates vs. print. |
| **Consult** | An interactive consultation tool delivered via the Vrtly platform; used at the point of sale within the practice. | Available on platform; also listed as a roadmap campaign format (Info Packs and Consults are paired). |
| **Dwell Time** | The time a patient spends inside the practice during a visit; cited as 45–90 min on average. | The core window available for brand content exposure and POC influence. |
| **Cross-sell** | Selling additional treatments or products to an existing patient already in the practice. | The primary value proposition for brands advertising at POC; existing/repeat consumers drive ~2/3 of industry revenue. |
| **SOV (Share of Voice)** | The percentage of total screen time allocated to a given brand's content. | Brands on paid campaigns receive priority SOV allocation. Platform Brands receive 2× vs. non-platform. SOV is sold in 10% increments for ad campaigns. |
| **Content Refresh Bonus** | An algorithmic boost given to brands that regularly upload new content; increases play frequency. | Incentivises brands to keep content current and reduces stale playlist risk. |
| **Category Dominance** | A premium partnership tier that gives a brand dominant SOV within its product category while limiting competitor presence on the same screens. | Roadmap — launching Q2 2026. Not yet live; do not carry to final feature docs. |
| **Vrtly Success Suite** | A bundled device-sale package ($5,000/yr per practice) co-sold with brand partners; includes 3 screens and 50% reserved SOV for the sponsoring brand(s). | Also called "Device Sale Package." Brands fund or subsidize screen installations in target clinics to secure guaranteed SOV. |
| **Ad Exchange** | See *Vrtly Ad Exchange*. | — |
| **Ads Mode** | A distinct content delivery state on in-practice screens where brand ad content is actively cycling. | Shown in brand deck alongside logos of active brand partners (e.g., Mentor, Galderma, Dysport). |
| **ROFR (Right of First Refusal)** | An early-commitment right offered to brands on upcoming products (Info Packs, Consults, EMR Attribution). | Used as a sales incentive for brands that commit to campaigns early. |
| **Playlist** | The ordered sequence of content items (brand and practice content) displayed on a given screen. | Default allocation: 80% brand content / 20% practice content on free screens. |
| **Medtech / Device Partner Program** | A specific partnership track for medical device companies that sell hardware to practices. Vrtly helps address device adoption barriers by driving in-practice patient demand. | Live product line. Priced at $6,000/yr annual value with $2,500 setup fee. |
| **Proof of Play** | Real-time confirmation that a brand's ad content was served on a specific screen at a specific time. | Part of the Ad Manager analytics offering; referenced as "gold-standard analytics." |
| **Attribution** | Connecting in-clinic content exposure to downstream treatment or purchase outcomes. | Currently a roadmap feature ("Ads-to-Sales Attribution"). EMR integration is the mechanism for 1P attribution data. |
| **Category Flywheel** | The compounding competitive dynamic where early brand presence at POC drives higher conversion, which reinforces clinic preference, which locks out later-arriving competitors. | Strategic framing used in brand sales deck; not a product feature name. |


---

## Acronyms


| Acronym | Expansion | Usage Context |
| ------- | --------- | ------------- |
| **POC** | Point of Care | The in-clinic environment where Vrtly content is delivered and treatment decisions happen. |
| **SOV** | Share of Voice | Percentage of screen time allocated to a brand; the core unit of brand presence on Vrtly. |
| **CPM** | Cost Per Mille (cost per 1,000 impressions) | Vrtly's pricing basis for ad campaigns. Q1 2025 deck uses $30 CPM; 2026 brand deck uses $20 CPM. The $20 CPM should be treated as current standard pricing. |
| **DSP** | Demand-Side Platform | Vrtly Ad Manager — the brand-facing campaign management interface. |
| **SSP** | Supply-Side Platform | Vrtly Practice Portal — the practice-facing screen and brand management interface. |
| **DMP** | Data Management Platform | Vrtly's audience data and segmentation capability (roadmap). |
| **EMR** | Electronic Medical Record | Referenced in context of integrating patient visit data for personalized targeting and attribution (roadmap feature: Vrtly Ads EMR). |
| **RMN** | Retail Media Network | Vrtly's evolving commerce and data ecosystem; encompasses DMP, DSP, and 1P data (roadmap). |
| **CSAT** | Customer Satisfaction Score | Vrtly reports >95 CSAT across active practices. |
| **ROFR** | Right of First Refusal | Offered to early-commit brands on Info Packs, Consults, and EMR Attribution products. |
| **TAM** | Total Addressable Market | Used in market sizing; e.g., aesthetics TAM = 50,000 US locations, $750M ad spend. |
| **DAU** | Daily Active Users | Used internally to track practice engagement; 170% YoY increase reported (2024 vs. 2023). |
| **EBITDA** | Earnings Before Interest, Taxes, Depreciation, and Amortization | Used in 4-year financial projections in pitch deck; 12% margin target for 2026. |

---

## Open Naming Conflicts

The following terms are used inconsistently across source documents and must be resolved before final product documentation is written:

| Conflict | Option A | Option B | Recommendation |
| -------- | -------- | -------- | -------------- |
| Practice-facing portal name | "Vrtly Practice Portal" | "Vrtly Practice Manager" | Align on one canonical name |
| Brand-facing platform name | "Vrtly Ad Manager" | "Vrtly Ad Manager Platform" | "Vrtly Ad Manager" is shorter and used in more places |
| Playlist format name | "Smart Playlist" | "SmartPlaylist" | Standardise casing |
