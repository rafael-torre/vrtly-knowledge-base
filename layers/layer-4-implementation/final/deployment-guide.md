---
title: Deployment Guide
layer: implementation
owner: ""
last_updated: ""
relates_to:
  - layers/layer-3-architecture/final/architecture-overview.md
  - layers/layer-4-implementation/final/development-guide.md
status: in_progress
optional: true
---

# Deployment Guide

> **Optional document.** Create this when the deployment process is defined and repeatable, or before a handoff where another team needs to operate the system. Skip it if deployment is managed entirely by CI/CD with no manual steps, or if the client's team owns this knowledge.

How to deploy this system — from a merged PR to a running production environment. This document is written for the person doing the deploy or inheriting operational responsibility: they should be able to follow it without asking anyone for help.

This is not an architecture document. Infrastructure decisions and rationale live in the [Architecture Overview](../../layer-3-architecture/final/architecture-overview.md). This document covers the operational procedure.

---

## Environments

What environments exist, what each is for, and how to access them.

> **Guiding questions:**
>
> - What environments exist — development, staging, production? Are there preview, sandbox, or feature environments?
> - What is each environment for — who uses it, what kind of traffic it serves, what data it holds?
> - How does an engineer get access to each environment? Are there access restrictions or approval processes?
> - What are the URLs or endpoints for each environment?
> - Are there differences in behavior between environments — feature flags, mocked services, different configurations?


| Environment | Purpose | URL / Endpoint | Access | Notes |
| ----------- | ------- | -------------- | ------ | ----- |
| Development | | | Team only | |
| Staging | | | Team + Client | |
| Production | | | Restricted | |


---

## Deployment Process

How a change moves from a merged PR to a running environment.

> **Guiding questions:**
>
> - Is deployment fully automated (triggered by merge), semi-automated (triggered manually after merge), or manual?
> - What triggers a deployment to each environment — a merge to a specific branch, a tag, a manual trigger?
> - Are there any manual steps required before, during, or after a deploy — database migrations, cache invalidation, feature flag updates, smoke tests?
> - What is the deployment order if multiple services must be deployed in sequence?
> - Who is responsible for triggering production deployments? Is there an approval step?
> - How long does a typical deployment take? What does a successful deployment look like?

### Deploying to Staging

Step-by-step procedure for staging deployments.

### Deploying to Production

Step-by-step procedure for production deployments.

---

## CI/CD Pipeline

What the automated pipeline does and where the configuration lives.

> **Guiding questions:**
>
> - What CI/CD platform is used — GitHub Actions, CircleCI, GitLab CI, Buildkite, or other?
> - Where does the pipeline configuration live in the repository?
> - What stages does the pipeline run — lint, test, build, deploy? In what order? Which are parallel?
> - What does each stage do? What does failure in each stage mean?
> - Are there separate pipelines for different environments or branches?
> - Are there pipeline steps that run only on certain branches or events — for example, a deploy step that only runs on `main`?


| Stage | Trigger | What It Does | On Failure |
| ----- | ------- | ------------ | ---------- |
| | | | |


---

## Rollback Procedure

How to recover from a bad deployment.

> **Guiding questions:**
>
> - What is the primary rollback mechanism — reverting the deploy in the CI/CD tool, rolling back a container image, or deploying a previous Git tag?
> - Are database migrations reversible? What is the process for rolling back a migration?
> - Who can initiate a rollback? Is there an approval step?
> - How long does a rollback take? What is the expected recovery time?
> - Are there any scenarios where rollback is not possible — irreversible migrations, third-party state changes — and what is the mitigation for those?

### When to Roll Back

### How to Roll Back

Step-by-step procedure.

### When Rollback Is Not Possible

Document any known scenarios where reverting is not straightforward and what to do instead.
