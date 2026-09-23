# Flow Reliability Dashboard

<p align="center">
  <strong>See the signal. Find the impact. Decide the next step.</strong><br />
  A Salesforce-native reliability dashboard for captured Flow failures.
</p>

<p align="center">
  <a href="https://github.com/jcd1991/flow-failure-monitor/actions"><img src="https://img.shields.io/github/actions/workflow/status/jcd1991/flow-failure-monitor/salesforce-ci.yml?label=CI&style=for-the-badge" alt="CI status" /></a>
  <img src="https://img.shields.io/badge/Salesforce-LWC%20%2B%20Apex-0b5cab?style=for-the-badge&logo=salesforce&logoColor=white" alt="Salesforce" />
  <img src="https://img.shields.io/badge/Captured%20events-grouped%20%2B%20bounded-13b886?style=for-the-badge" alt="Captured events" />
  <img src="https://img.shields.io/badge/MCP-companion%20server-7c3aed?style=for-the-badge" alt="MCP companion" />
</p>

<p align="center">
  <a href="docs/github-demo-walkthrough.md">Five-minute walkthrough</a> ·
  <a href="docs/demo-runbook.md">Demo runbook</a> ·
  <a href="docs/architecture-and-security.md">Architecture & security</a> ·
  <a href="docs/portfolio-readiness.md">Portfolio roadmap</a>
</p>

---

## The product in one sentence

Flow Reliability Dashboard turns explicitly captured Flow faults into counts, trends, grouped fingerprints, affected-record impact, and a focused investigation queue.

It is a reliability view of **captured events**, not an automatic counter of every Flow execution in the org.

![Detect and investigate a Flow failure](docs/media/ffm-detect-investigate.gif)

![Preview and execute a safe recovery](docs/media/ffm-safe-recovery.gif)

_The GIFs are sanitized storyboards of the real portfolio workflow._ Start the live dashboard demo with [`docs/github-demo-walkthrough.md`](docs/github-demo-walkthrough.md).

## What the dashboard answers

```text
How many failures were captured?
Which Flow and element fail most often?
Is the trend rising or falling?
How many distinct records are affected?
Which groups are still open?
What should an admin investigate first?
```

The default view is dashboard-first:

- **Failure events** — captured fault records in the selected 7/30/90-day window.
- **Failure groups** — recurring fingerprints rather than raw interviews.
- **Affected records** — distinct captured record IDs.
- **Open groups** — New, Acknowledged, or Investigating groups.
- **Failure trend** — daily captured-event volume.
- **Top failing Flows and elements** — the fastest path to triage.
- **Impact queue** — event count, record count, status, and representative message.

## How failures enter the dashboard

The package does not silently intercept every Flow. A Flow must send a failure through one of the supported capture paths:

1. An explicit Flow fault connector calls `FFM_LogFlowErrorAction`.
2. A supported publisher sends an `FFM_Failure_Capture__e` platform event.

The capture service redacts sensitive values, fingerprints similar failures, publishes the event, and persists `Flow_Error__c` plus `Failure_Group__c` records. If a Flow has no supported capture path, this dashboard cannot infer that it failed.

```text
Flow fault connector / supported event publisher
                 ↓
       FFM_LogFlowErrorAction
                 ↓
          FFM_Failure_Capture__e
                 ↓
  Flow_Error__c + Failure_Group__c
                 ↓
      Flow Reliability Dashboard
```

## Recovery is intentionally secondary

The dashboard helps an admin decide whether the root cause belongs in Flow metadata or in the data. Recovery is not automatic and does not replay the failed transaction.

From an investigated group, an admin may optionally:

1. Expand **Advanced recovery**.
2. Choose an approved, purpose-built recovery Flow.
3. Run a dry-run to count eligible and skipped records.
4. Simulate with no business change, or explicitly approve the allowlisted demo recovery.

The demo recovery Flow (`FFM_DemoOrderRecovery`) changes only the selected demo Account. A stale or invalid record is rejected before the recovery Flow is invoked. Generic replay and automatic AI recovery are out of scope.

## Five-minute demo

| Moment | What the audience sees | Proof |
| --- | --- | --- |
| **1 · Dashboard** | Counts, 30-day trend, top Flows, hotspots, and open groups | [`docs/github-demo-walkthrough.md`](docs/github-demo-walkthrough.md) |
| **2 · Grouping** | Repeated failures become one fingerprint with impact context | [`scripts/e2e-flow-fault.apex`](scripts/e2e-flow-fault.apex) |
| **3 · Investigate** | Samples, redacted message, checklist, status, and history | [`docs/demo-runbook.md`](docs/demo-runbook.md) |
| **4 · Safety** | Invalid record is skipped before recovery Flow execution | [`scripts/e2e-invalid-record-execute.apex`](scripts/e2e-invalid-record-execute.apex) |
| **5 · Optional repair** | Approved recovery Flow updates one demo record and audits the result | [`scripts/e2e-actual-recovery.apex`](scripts/e2e-actual-recovery.apex) |

## Architecture

- **Salesforce package:** capture action, platform event, grouping, dashboard LWC, bounded DTO API, permission sets, and Apex tests.
- **MCP companion:** `flow-failure-monitor-mcp/` delegates to the package API without arbitrary SOQL/Apex or an embedded model.
- **Advanced recovery:** `Recovery_Action__c` registers a named repair procedure; execution remains explicit, allowlisted, and audited.

## Install and develop

Requires Salesforce CLI. A Dev Hub is required for future managed 2GP packaging; the source is intentionally namespace-free today.

```bash
sf org login web --alias sflens-dev
sf project deploy start --source-dir force-app --target-org sflens-dev
sf apex run test --target-org sflens-dev --test-level RunLocalTests --code-coverage
```

For the repeatable UI demo:

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-preview.apex
sf apex run --target-org <org-alias> --file scripts/e2e-flow-fault.apex
```

Then open the `Flow_Failure_Monitor1` tab and start with the dashboard summary.

### CI behavior

Every push and pull request checks the Salesforce source layout, builds the MCP companion, and runs its production dependency audit. If `SF_ACCESS_TOKEN` and `SF_INSTANCE_URL` Actions secrets are configured, CI also installs the Salesforce CLI, authenticates the org, and performs a dry-run deployment with local Apex tests. Without those secrets, org validation is skipped with a visible notice.

## Security posture

The API and dashboard use sharing/FLS-aware queries, permission gates, bounded windows and limits, redaction, fixed routes, and DTO responses. The package exposes no arbitrary SOQL or Apex execution. Recovery preview is the only non-read-only API path, and it never executes a recovery Flow.

See [`docs/architecture-and-security.md`](docs/architecture-and-security.md) for the threat model and [`docs/portfolio-readiness.md`](docs/portfolio-readiness.md) for production hardening requirements.

## Package contents

- `Flow_Error__c` — captured failure record.
- `Failure_Group__c` — fingerprinted recurring failure group.
- `FFM_LogFlowErrorAction` — invocable Flow fault-path logger.
- `FFM_FlowErrorService` — dashboard snapshot, grouping, samples, history, and status service.
- `FFM_FlowFailureApiV2` — bounded DTO-only REST API.
- `flow-failure-monitor-mcp/` — MCP companion server.
- `flowFailureMonitor` — dashboard-first Lightning Web Component.
- `FFM_DemoOrderFlow` and `FFM_DemoOrderRecovery` — end-to-end demo pair.
- `scripts/` — repeatable Apex fixtures and safety tests.

## Portfolio proof

```text
✅ 7/7 Apex regression tests passed in the Developer Edition org
✅ Dashboard snapshot tested for 7/30/90-day windows
✅ Distinct affected-record and grouped-fingerprint assertions passed
✅ MCP TypeScript build passed
✅ npm audit --omit=dev found 0 vulnerabilities
✅ Valid and invalid recovery paths remain covered
```

This is a focused portfolio implementation: a useful reliability dashboard with a deliberately bounded recovery demonstration. Production packaging still requires namespace/2GP setup, subscriber-org upgrade tests, retention controls, rate limiting, and deeper multi-user security validation.
