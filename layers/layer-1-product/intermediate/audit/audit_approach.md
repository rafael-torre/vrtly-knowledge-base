# Audit approach
## How we would approach the first weeks

---

### Weeks 1–2: build context and assess

**Ecosystem and architecture**
Understand the full platform: 6 runtimes, 4 backend services, content delivery flow, and how failures surface operationally.

**Active fleet: three workstreams**
We scope to the ~50% of the fleet that stays. Legacy hardware being phased out would be out of scope. The plan defines three parallel workstreams: html5core, Roku, and Android. Each needs a clear owner and the right access.

**Active firefight (VT-5083)**
Running across three backend services right now. We'd assess whether it needs to settle before Phase 1 can start cleanly.

**80% telemetry in one month: evaluation**
Map what specifically needs to be built to get there, and whether that is realistic given where things stand today. Scoped to the 50% of the fleet that stays after the legacy phase-out.

**Release process and how testing works today**
Understand the current release process and QA practice. No canary deploys, no rollback path today. Assess the risks before assuming what can be improved.

**QA scope definition**
We do not yet know what is viable. Emulators, canary on real devices, or something else. Define what QA can realistically do to validate the 80% telemetry phase.

---

### Week 3: find the gaps and deliver our read

**Gaps in the plan**
Identify where the plan is under-specified or does not have enough behind it to execute.

**Phase 1 to Phase 2 sequencing**
Assess whether the order holds, or whether something needs to happen in parallel or in a different order.

**First recommendations**
Identify the most effective starting point across telemetry, release process, and QA. What to address first and why.

**Our assessment**
Deliver a clear read: what is solid, what is at risk, and where to start.

---

*This runs from kickoff.*

**Preconditions to start:** Full access to active repos and environments, and a product demo.

**Starting point:** A first Q&A session with your team.
