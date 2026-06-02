---
title: Monitoring & Observability
layer: implementation
owner: ""
last_updated: ""
relates_to:
  - layers/layer-3-architecture/final/nonfunctional-requirements.md
  - layers/layer-3-architecture/final/architecture-overview.md
  - layers/layer-4-implementation/final/deployment-guide.md
status: in_progress
optional: true
---

# Monitoring & Observability

> **Optional document.** Create this once monitoring tooling is in place and the team has defined what "healthy" looks like for the system. The alerting thresholds here should be grounded in the targets defined in the [Non-functional Requirements](../../layer-3-architecture/final/nonfunctional-requirements.md).

What we monitor, what we alert on, and how we understand what the system is doing. This document is the reference for anyone who needs to understand the observability setup — whether that's responding to an alert, building a new dashboard, or handing operations to another team.

---

## What Is Monitored

An overview of the monitoring coverage: which services, endpoints, and infrastructure components are instrumented, and what business metrics are tracked.

> **Guiding questions:**
>
> - Which services and components are monitored — backend API, frontend, background workers, databases, queues?
> - What are the key endpoints or operations with dedicated monitoring? Are there SLIs defined for specific user-facing flows?
> - What infrastructure components are monitored — servers, containers, databases, queues, caches?
> - Are there business-level metrics being tracked — active users, transaction volume, conversion events?
> - What monitoring platform is used — Datadog, Grafana, CloudWatch, New Relic, or other? Where is the configuration stored?


| Component | What Is Monitored | Platform | Notes |
| --------- | ----------------- | -------- | ----- |
| | | | |


---

## Dashboards

What dashboards exist, where they live, and what each one shows.

> **Guiding questions:**
>
> - What dashboards are available? Who is the primary audience for each — engineers, tech lead, client?
> - Where do dashboards live — a specific URL, a shared workspace, a monitoring tool folder?
> - What does each dashboard show — system health, individual service metrics, business KPIs?
> - Is there a primary "system health" dashboard that should be the first thing checked during an incident?
> - Are dashboards defined as code (Grafana JSON, Terraform, etc.) or configured manually in the tool?


| Dashboard | URL / Location | Audience | What It Shows |
| --------- | -------------- | -------- | ------------- |
| | | | |


---

## Alerting

What conditions trigger alerts, who gets notified, and what the expected response is.

> **Guiding questions:**
>
> - What conditions trigger alerts — error rate, latency, availability, queue depth, infrastructure metrics?
> - What are the thresholds for each alert? Are they consistent with the NFR targets?
> - Who receives each alert — on-call engineer, tech lead, a shared channel?
> - What is the notification channel — PagerDuty, Slack, email, or other?
> - Are alerts severity-tiered — critical (immediate response) vs. warning (review within the day)?
> - Are there any known noisy alerts or false positives that require context to interpret correctly?
> - Where is alerting configuration stored — in the monitoring tool, as code, in a config file?


| Alert | Condition / Threshold | Severity | Who Gets Notified | Channel | Notes |
| ----- | --------------------- | -------- | ----------------- | ------- | ----- |
| | | Critical / Warning | | | |


---

## Logging

What is logged, where logs are stored, and how to use them.

> **Guiding questions:**
>
> - What log levels are in use — debug, info, warn, error — and what criteria determine which level is used?
> - What events or operations are always logged — requests, errors, auth events, state changes, background job outcomes?
> - What is the log format — structured JSON, plaintext, or other? Are there required fields in every log entry?
> - Where are logs stored and for how long? Is there a log aggregation platform — Datadog, Cloudwatch Logs, Loki, ELK, or other?
> - How do engineers query logs locally vs. in production? Are there saved searches or common queries worth documenting?
> - Are there any sensitive fields that must never appear in logs — PII, credentials, tokens?


| Service / Component | Log Platform | Retention | How to Access |
| ------------------- | ------------ | --------- | ------------- |
| | | | |
