---

## title: "Business Overview — Vrtly"
layer: business
owner: ""
last_updated: "2026-06-02"
relates_to: []
status: in_progress

# Business Overview — Vrtly

---

## Company Identity and History

Vrtly is a **point-of-care (POC) advertising and marketing platform for medical aesthetics**. Its core product is a Smart TV and tablet app installed in aesthetic practices — medspas, dermatology clinics, and plastic surgery offices — that delivers brand content to patients during the 45–90 minutes they spend in waiting and treatment rooms. Vrtly operates as a two-sided marketplace: brands pay to reach patients at the moment decisions are made; practices get free or low-cost digital signage in return.

The company has roots in **FriendMedia**, a digital signage company founded in the San Ramon, CA area (CB Insights: 2013; co-founder profiles suggest 2016). The current Vrtly brand, platform, and team took shape around **2022** (LinkedIn founding year), when the company pivoted fully into medical aesthetics POC advertising. The entire current technology stack was built in approximately five quarters from that point. Vrtly is incorporated as **Vrtly, Inc.**, headquartered at 2603 Camino Ramon, Suite 460, San Ramon, CA 94583, with a distributed team spanning California, Canada, Ukraine, and South Africa. As of early 2026, the company has approximately **16–18 employees** and is actively hiring area sales representatives across major US markets.

Vrtly describes itself as the **"All-in-One Media Network"** for medical aesthetics and uses the tagline **"The Point of Care is the Point of Decision."** Its public positioning frames the POC as the largest blind spot in aesthetics brand spend — brands invest heavily in Meta and Google to build awareness, but lose the consumer at the moment they are physically inside a clinic where 80% of decisions happen. The tone is confident and data-forward, targeting both brand marketing teams and practice owners.

---

## Business Model

Vrtly earns revenue through two streams that reflect the two sides of its marketplace.

**Brand advertising (primary — ~90% of revenue):** Aesthetic brands pay to distribute content across the Vrtly practice network. The base product is a platform subscription billed per practice per month (tiered from $5/practice/mo down to $1/practice/mo at scale), plus paid ad campaigns that boost share of voice (SOV) on practice screens at a CPM-based rate. ⚠️ *CPM pricing is internally inconsistent across sources: the Q1 2025 investor deck cites $30 CPM at 80% SOV on free screens; the 2026 brand sales deck quotes $20 CPM (promo $10). The $20 CPM figure appears to be the current go-to-market price.* Practices that host brand content receive it free; the brand absorbs the cost. Average revenue per practice across the network is approximately **$350/month**.

**Practice subscriptions (secondary — ~10% of revenue):** Practices can pay for upgraded tiers that give them greater control over their screens. The publicly marketed paid tier is **Vrtly Plus at $99/month** (unlimited brand-backed screens, full scheduling control). A higher **Vrtly Pro** tier (100% custom content, consultation tools, Info Packs) is in early access as of mid-2026. An additional bundled offer — the **Vrtly Success Suite** at $5,000/year — is co-sold with brand partners and includes hardware (3 screens/tablets), concierge setup, and guaranteed SOV.

The value chain runs: brands fund the network → practices get free digital signage → patients receive brand content at peak receptivity → brands measure conversion. The platform takes a cut of brand spend without requiring hardware sales or physical distribution.

---

## Customer Segments

Vrtly operates a two-sided marketplace with three distinct groups, two of which are direct customers.


| Segment                     | Description                                                                                                                                                                                                                                                                                                                                                                                                                               | Relative Importance                          |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| **Brands (Advertisers)**    | Medical aesthetics product companies — injectables, devices, skincare — that pay to distribute content and run campaigns across the practice network. Current library: 270+ brands. Named examples: Hydrafacial, Allergan (Botox, Juvederm, Allē), Restylane, Dysport, Revance, CoolSculpting, Galderma, Sculptra, Jan Marini. Also includes **medtech/device companies** that use Vrtly to support device adoption and consumable sales. | **Primary revenue driver** (~90% of revenue) |
| **Practices (Publishers)**  | Medical aesthetic practices — medspas, dermatology clinics, plastic surgery offices — that install the Vrtly app and host brand content on waiting room and treatment room screens. Current network: ~2,000 practices. Acquiring organically at 50+ per month with no marketing spend. Target: 10,000 practices by 2029. Segmented by size: Small (<1,200 sq ft), Medium (<2,400 sq ft), Large (>2,400 sq ft).                            | **Supply side / network asset**              |
| **Patients (End Audience)** | Consumers who receive brand content while inside practices. Not a direct Vrtly customer, but the audience that makes the platform valuable to brands. 70% are interested in new procedures; 7 in 10 have no brand preference at the time of their visit — the cross-sell opportunity Vrtly is built around.                                                                                                                               | **Indirect — audience, not customer**        |


Vrtly's current geographic focus is the USA, with approximately 50,000 addressable aesthetic practices. Planned expansion verticals include hair and beauty (1M US locations), dental (150K), and ophthalmology (20K).

---

## Organizational Structure and Culture

Vrtly is a **small, founder-led team of ~16–18 people** operating in a startup mode. The founding team brings deep domain expertise from medical aesthetics (Allergan, HintMD, CoolSculpting, Revance) and large-platform product and design experience (Apple, Amazon, Google, Zoom). Decision-making is centralized around the executive team; as of 2026 the company is transitioning from pure product-led growth (organic practice signups, no marketing) toward a field sales motion with area reps being hired across Florida, Texas, Southern California, New York/NJ, Chicago, and Arizona.

**Core team:**


| Name           | Role                         | Background                               |
| -------------- | ---------------------------- | ---------------------------------------- |
| Vojin Kos      | CEO & Co-founder             | HintMD, Allergan, CoolSculpting          |
| Joe Schooler   | CPO                          | Apple, Amazon, Google                    |
| Mel Love       | Director of Customer Success | HintMD, Revance                          |
| Sergei Vareyko | Principal Engineer           | Altir, Nuance Communications, Gulf Relay |
| David Perez    | Principal Designer           | Apple, Zoom                              |


**Advisors / Board:**


| Name                 | Role                     | Background              |
| -------------------- | ------------------------ | ----------------------- |
| Jay Burns, MD        | Board Member             | Resurrect Skin MD       |
| Aubrey Rankin        | Board Member             | Geneo, HintMD, Allergan |
| Ashley Moulton Hanks | Advisor & Board Observer | Google, Verily, Gilead  |


The team operates in a distributed model across the US, Canada, Ukraine, and South Africa.

---

## Existing Systems and Technology Landscape

Vrtly's platform consists of three integrated components delivered as cloud-hosted web applications and native Smart TV/tablet apps:


| System                                       | Purpose                                                                                                                                                                                                                                                  | Notes                                                                                                          |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **Vrtly Ad Manager**                         | Brand-facing platform for uploading content, planning and launching ad campaigns, and viewing real-time analytics (impressions, SOV, proof-of-play, QR scans)                                                                                            | Also referred to as "Vrtly Ad Manager Platform" in some materials — single canonical name not yet standardized |
| **Vrtly Ad Exchange**                        | Central AI-powered matching layer that optimizes brand-to-practice content delivery and programmatic ad serving                                                                                                                                          | Internal product name; not surfaced in public-facing materials                                                 |
| **Vrtly Practice Portal / Practice Manager** | Two-part supply-side product: a native Smart TV/tablet app (installed from app stores) that plays content on practice screens, and a web-based management portal at `my.vrtly.ai` where practices configure brands, schedule content, and manage screens | ⚠️ "Practice Manager" and "Practice Portal" used interchangeably — one canonical name needed                   |


**Device platform support:** Roku, Amazon Fire TV, Google TV, Samsung Smart TV, Tablets. Plug-in streaming devices available via concierge for non-Smart TVs. Apple TV and LG not publicly confirmed.

**Intellectual property:** US Patent 6038.001US1 covers Vrtly's core bidirectional selection mechanism — practices select which brands they show, and brands select which practices they target — via a content matching system. Additional patents pending per Jan 2026 press release.

**Legacy:** The company was previously known as **FriendMedia** and previously distributed content via HDMI streaming sticks. The current app-based, no-hardware model launched in 2023–2024.