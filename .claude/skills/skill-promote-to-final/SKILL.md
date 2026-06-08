---
name: skill-promote-to-final
description: 'Validate and promote an intermediate document to the corresponding final/ path with correct frontmatter and metadata cascade. Use when the user indicates readiness to move content to final.'
---

# Promote to Final

## Purpose
The single gate from intermediate/ to final/. Validates that all quality checks have passed (editorial review, adversarial review, upstream layer in consensus), writes the document to the correct final/ path with proper frontmatter, and runs update-metadata.sh to cascade needs_review to related docs.

## Inputs
- Source intermediate/ document path
- Review findings (from skill-review-prose, skill-review-adversarial, or skill-review-edge-cases)
- Upstream layer final/ documents to verify consensus status

## Outputs
- Promoted document in the corresponding final/ path (status: needs_review)
- Cascade: related docs updated to status: needs_review via update-metadata.sh

## Steps (TODO)
1. Identify source intermediate/ document
2. Validate upstream layer: check that Layer N-1 final/ has at least one doc with status: consensus
3. Validate editorial quality: confirm skill-review-prose has been run (or run it now)
4. Validate adversarial quality: confirm skill-review-adversarial has been run (or run it now)
5. Prepare final/ path: layers/layer-N-<name>/final/<same-relative-path>
6. Write document with frontmatter: status: needs_review, last_updated: today, relates_to populated
7. Run: bash companion/hooks/update-metadata.sh <final-path> <project-root>
8. Confirm promotion complete; show path and cascaded docs
