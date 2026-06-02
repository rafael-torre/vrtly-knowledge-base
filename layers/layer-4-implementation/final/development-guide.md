---
title: Development Guide
layer: implementation
owner: ""
last_updated: ""
relates_to:
  - layers/layer-3-architecture/final/architecture-overview.md
  - layers/layer-3-architecture/final/tech-stack-rationale.md
status: in_progress
---

# Development Guide

How we work on this codebase. This document captures the conventions, patterns, and workflows that every engineer on this project needs to know — the knowledge that would otherwise live in people's heads, scattered across Slack threads, or buried in PR comments.

This is not a company-wide standards document. It covers what is **specific to this project**: where we deviate from defaults, which patterns we've adopted and why, and how this team operates day-to-day. Global engineering standards (linting rules enforced by CI, company-wide PR conventions) are referenced here but not duplicated.

---

## Coding Conventions

Project-specific coding standards and style decisions. These go beyond what linting and formatting tools enforce — they capture the patterns and idioms this team has agreed on that tools cannot check automatically.

> **Guiding questions:**
>
> - What naming conventions do we follow for files, functions, variables, and types? Do any differ from language or framework defaults?
> - Are there architectural patterns we apply consistently — how do we structure modules, where does business logic live, how do we handle shared utilities?
> - How do we handle errors — what is the error propagation strategy, where do errors get logged vs. surfaced to users?
> - What are the rules around comments and documentation in code — when are they required, what should they explain?
> - Are there patterns we explicitly avoid — anti-patterns or shortcuts that are tempting but that we've decided not to use?
> - Where do we deviate from framework conventions or community defaults, and why?

---

## Testing Strategy

How we test this project — what gets tested, at what level, and what good looks like.

> **Guiding questions:**
>
> - What are the three testing levels for this project — unit, integration, end-to-end — and what does each cover?
> - What is the coverage expectation? Is there a minimum threshold enforced in CI? What areas are exempt and why?
> - What testing frameworks and libraries are in use? (Reference the Tech Stack Rationale for the choices — document the usage patterns here.)
> - How do we handle test data — fixtures, factories, seeded databases, mocks? What is the policy on mocking external services?
> - Where do tests live relative to the code they test? What naming conventions do test files follow?
> - Are there categories of tests that are slow or expensive to run? How does the team manage those — are they gated behind a flag, run only in CI, or excluded from local runs?
> - What is the approach to testing infrastructure or deployment changes?

---

## Branch Strategy & PR Workflow

How code moves from an engineer's machine to production.

> **Guiding questions:**
>
> - What is the branching model — trunk-based, feature branches, GitFlow, or something else?
> - What are the naming conventions for branches?
> - What does a PR need before it can be merged — number of approvals, passing CI, linked ticket, filled-out description?
> - What belongs in a PR description? Is there a template? What should reviewers always be told?
> - What is the policy on commit history — do we squash on merge, rebase, or merge commits?
> - How are draft PRs used — for work in progress, for early feedback, or not at all?
> - How are hotfixes handled — is there a separate process for urgent production fixes?
> - Who can merge? Are there protected branches?

---

## Key Implementation Patterns

The technical patterns this project uses consistently. These are decisions that have been made — engineers should follow them rather than re-evaluate from scratch on each feature.

> **Guiding questions:**
>
> - What is the data access pattern — repository pattern, active record, direct ORM queries, raw SQL? Where is it applied?
> - How is authentication and authorization enforced at the code level — middleware, decorators, service layer checks? Where does the check happen?
> - How is validation handled — at the API boundary, in the service layer, at the model level, or all three?
> - How does the project handle async operations — async/await patterns, background jobs, queues? What are the conventions around each?
> - Are there patterns for cross-cutting concerns — logging, tracing, caching — that all engineers should follow?
> - What is the pattern for API responses — are there standard response shapes, error formats, pagination conventions?
> - For frontend: what is the state management approach? How is data fetching handled? What is the component composition pattern?

---

## Project-Specific Tooling

Scripts, generators, and CLI tools that are specific to this project. This section covers tools that are not obvious from the tech stack alone — things an engineer would not know about without being told.

> **Guiding questions:**
>
> - Are there code generators or scaffolding scripts — for creating new features, modules, or components?
> - Are there custom scripts for common tasks — seeding the database, resetting local state, running a subset of tests?
> - Are there project-specific CLI tools or Makefile targets engineers should know about?
> - Are there tools that must be run before committing or pushing — pre-commit hooks, local linting scripts?
> - Are there tools for working with the database locally — migration runners, schema introspection, data inspection?


| Tool / Script | Command | What It Does |
| ------------- | ------- | ------------ |
| | | |
