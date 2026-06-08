---
name: extract-pdf-to-intermediate
description: Extract content from PDF files and synthesize it into a structured intermediate artifact (.md). Use when the user asks to process, extract, or convert a PDF raw input into an intermediate layer document, or when a PDF has no readable text layer.
disable-model-invocation: true
---

# Extract PDF to Intermediate Artifact

Converts an image-based PDF into a structured `.md` synthesis file stored in the `intermediate/` folder of the target layer in the layered documentation framework.

---

## Step 1 — Detect if the PDF is image-based

Use the Read tool on the PDF. If the output is empty or contains only page-number markers like `-- 1 of N --` with no content between them, the PDF has no text layer. Proceed with image extraction.

If the PDF has readable text, extract it directly without the image conversion step.

---

## Step 2 — Convert PDF pages to images

Install PyMuPDF if needed, then run the conversion script:

```bash
pip3 install pymupdf -q
```

```bash
python3 scripts/pdf-to-images.py "/path/to/file.pdf" "/tmp/pdf_slides"
```

This saves one PNG per page as `slide_01.png`, `slide_02.png`, etc. See [scripts/pdf-to-images.py](scripts/pdf-to-images.py).

---

## Step 3 — Read the slides

Use the Read tool on each image file. Batch 10 at a time to stay within context limits:

```
Read /tmp/pdf_slides/slide_01.png
Read /tmp/pdf_slides/slide_02.png
... (up to slide_10.png in one message)
```

Repeat in batches until all pages are read. Note slide numbers — the appendix (if present) often repeats earlier slides with minor variations; flag differences rather than duplicating content.

---

## Step 4 — Synthesize thematically

**Do not** write a slide-by-slide transcript. Organize by **information type**, not by slide order.

Before writing sections, identify which layer the PDF belongs to and what final documents that layer produces. Use `→ maps to:` annotations under each section header to point at the relevant final document in that layer.

**Layer reference:**

| Layer | Final documents |
|---|---|
| 0 — Business | Business Overview, Strategic Goals & Constraints, Stakeholder Map, Competitive Landscape |
| 1 — Product | Product Brief, User Personas, Feature Specs, User Journeys, Success Metrics, Domain Glossary |
| 2 — Design | Design System Reference, Feature Design Specs |
| 3 — Architecture | Architecture Overview, ADRs, Feature Technical Specs, NFRs, Tech Stack Rationale |
| 4 — Implementation | Development Guide, Deployment Guide, Monitoring & Observability |

**Common section types across document kinds:**

| Section | What it captures |
|---|---|
| Overview / Vision | Core concept, tagline, one-liner |
| Problem Space | Pain points, context, supporting data |
| Solution | How the subject addresses the problem |
| System / Architecture | Components, flows, integrations |
| Features / Capabilities | Breakdown of functionality, use cases |
| Users / Stakeholders | Who is affected, roles, goals |
| Competitive / Market Context | Differentiators, comparisons, opportunity |
| Metrics / Outcomes | Quantitative data, case studies, KPIs |
| Business / Operational Model | Revenue, cost structure, processes |
| Roadmap / Future State | Planned capabilities and directions |
| Key Terms | Domain-specific vocabulary |
| Open Questions / Gaps | Contradictions, ambiguities, missing info |

Not every section applies to every document. Drop sections that have no content.

---

## Step 5 — Write the intermediate artifact

**Filename**: use a descriptive, kebab-case name matching the source document.
- `pitch-deck-synthesis.md` for investor decks
- `brand-report-synthesis.md` for brand/partnership documents
- `technical-brief-synthesis.md` for technical documents

**Frontmatter** (minimal — intermediate artifacts do not use the full cascade frontmatter):

```yaml
---
title: "[Document Name] Synthesis — [Date/Version]"
last_updated: "YYYY-MM-DD"
source: "raw-inputs/[filename.pdf]"
---
```

**Output path**: `layers/[layer-folder]/intermediate/[filename].md`

Ask the user which layer the PDF belongs to if it is not clear from context.

---

## Output structure template

```markdown
---
title: ""
last_updated: ""
source: ""
---

# [Document Name] Synthesis

Source: [brief description of the document, slide count, date if shown].

---

## [Section Name]

→ *maps to: `final/[document].md`*

[Extracted and synthesized content]

---

## Open Questions / Gaps

→ *flags for gap analysis*

- [Contradiction or ambiguity found]
- [Missing information]
```

---

## Tips

- **Appendix slides**: Many pitch decks have an appendix that repeats core slides with minor wording differences. Read them all — unique content often lives there. Note discrepancies rather than duplicating content.
- **Tables and financial data**: Reproduce these as markdown tables; they are high-value for downstream final documents.
- **Quoted language**: Preserve exact wording for taglines, value propositions, and domain-specific names — these matter for glossaries and overview documents.
- **Roadmap vs. live features**: Explicitly flag which capabilities are live vs. on the roadmap. Mixing them creates confusion in downstream layers.
- **Multiple document sources**: If the same section is covered by multiple raw inputs, note the source for each claim. Conflicts go in Open Questions.
