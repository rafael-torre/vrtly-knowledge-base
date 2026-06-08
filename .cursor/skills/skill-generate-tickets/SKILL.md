---
name: skill-generate-tickets
description: 'Generate tickets from a Layer 3 feature technical spec and create them on the configured board. Use when a technical spec is ready for implementation.'
---

# Generate Tickets

## Purpose
Extract implementation tickets from a Layer 3 feature technical spec. Each ticket gets title, description, acceptance criteria, dependencies, labels, and a separation-of-concerns note. Tickets are reviewed before creation, then created on the configured board and referenced back in the technical PRD.

## Inputs
- Layer 3 feature technical spec in final/ (status: consensus)
- Layer 3 architecture overview (for cross-cutting constraints)
- .companion.yaml board configuration (board.type, board.project_id)

## Outputs
- Ticket definitions (reviewed in conversation before creation)
- Tickets created on configured board (TODO: board connector)
- ## Tickets section appended to Layer 3 technical PRD with ticket IDs and URLs

## Steps (TODO)
1. Validate prerequisites (Layer 3 technical spec in final, board config present)
2. Extract requirements (functional, non-functional, implementation constraints)
3. Generate ticket definitions (title, description, AC, dependencies, labels)
4. User review — show all tickets, allow edits before creation
5. Create tickets on board (reads board.type from .companion.yaml — TODO: implement connector)
6. Write ticket references back to technical PRD ## Tickets section
