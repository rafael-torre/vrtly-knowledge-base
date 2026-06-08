---
name: skill-correct-course
description: 'Analyze misalignment between layers and propose corrective steps. Use when the user detects drift or misalignment.'
---

# Correct Course

## Purpose
Detect and resolve misalignment between documentation layers — when a downstream layer has drifted from upstream decisions, or when requirements have changed mid-project.

## Inputs
- Any layer final documents identified as misaligned
- User description of the detected problem or change signal

## Outputs
- Correction plan in the affected layer's intermediate/ folder

## Steps (TODO)
1. Identify the change signal (requirement change, discovered constraint, user feedback)
2. Trace impact downstream: which layers are affected?
3. Propose minimal correction steps per affected layer
4. Draft correction plan with specific document changes
5. Write plan to affected layer's intermediate/ folder
6. Prompt user to apply corrections and re-promote affected docs
