# Flow Failure Monitor package

Flow Failure Monitor is a Salesforce-native, package-ready observability layer for Flow failures. It stores structured fault details, groups recurring errors, tracks resolution state, and gives admins a dashboard to investigate and retry safe operations.

## Package contents

- `Flow_Error__c`: structured error and resolution record.
- `FFM_LogFlowErrorAction`: invocable Apex action for Flow fault paths.
- `FFM_FlowErrorService`: read-only dashboard queries and controlled status updates.
- `FFM_FlowFailureApi`: legacy v1 bounded API.
- `FFM_FlowFailureApiV2`: DTO-only, permission-gated REST API with strict limits and dry-run preview endpoint.
- `flow-failure-monitor-mcp/`: separate read-only MCP companion that delegates to the REST API.
- `flowFailureMonitor`: Lightning Web Component dashboard.
- `FFM_DemoOrderFlow`: packaged demo Flow with a real Apex fault connector into the capture pipeline.
- `docs/demo-runbook.md`: repeatable detection → investigation → preview → safe simulation or allowlisted demo execution walkthrough.
- `docs/github-demo-walkthrough.md`: public-portfolio walkthrough for a five-minute demo.
- `docs/real-world-test-cases.md`: sanitized fixtures based on public Salesforce failure patterns.
- `docs/portfolio-readiness.md`: explicit GitHub/package publication gate.
- `docs/github-demo-walkthrough.md`: the polished five-minute portfolio walkthrough.
- `docs/architecture-and-security.md`: runtime path, security controls, and deliberate non-goals.
- Permission set and Apex tests.

This package does not automatically intercept every Flow. Salesforce Flows must explicitly route a fault connector to `FFM_LogFlowErrorAction`, which keeps the behavior visible, testable, and safe for subscribers. A reusable fault-path subflow remains a packaging follow-up. The API uses a custom permission, sharing/FLS-aware queries, bounded limits, fixed routes, redaction, and no arbitrary SOQL or Apex execution. No generic replay or automatic recovery is implemented.

## Install/develop

Requires Salesforce CLI and a Dev Hub for managed 2GP creation. Set a namespace before creating the package. Example:

```bash
sf org login web --alias sflens-dev
sf project deploy start --source-dir force-app --target-org sflens-dev
sf apex run test --target-org sflens-dev --test-level RunLocalTests --code-coverage
```

Assign `Flow_Failure_Monitor_User` for native capture/status operations, `Flow_Failure_Monitor_API_V2` for DTO read access, and `Flow_Failure_Monitor_MCP` or the preview permission set only to integrations that may create non-executing dry-run records. The hardened API base is `/services/apexrest/ffm/v2`; smoke paths are `/capabilities`, `/summary`, `/groups`, `/trends?days=30`, and `/search?q=...`. The only POST route is `/recovery/preview`, which never executes recovery.

The package is intentionally namespace-free in source control until the publisher chooses and registers a namespace.

The portfolio demo includes a controlled `FFM_DemoOrderFlow` scenario with a real fault connector, redacted failure samples, troubleshooting checklists, resolution status, dry-run accounting, a safe simulation, and one allowlisted demo recovery Flow.

## Recovery actions in plain English

The monitor does not automatically rerun a failed Flow. A failed Flow may already have created records, sent an email, made a callout, or updated related records. Rerunning it blindly could duplicate those side effects.

Instead, an administrator creates a `Recovery_Action__c` record for a safe, purpose-built repair. Think of it as a named button with guardrails:

1. Give it a label people understand, such as `Repair missing order address`.
2. Point it at a dedicated recovery Flow, such as `FFM_OrderRecovery`.
3. Set a maximum batch size and leave the action inactive until it has been reviewed.
4. The dashboard lists only active actions. The user selects one failure group, reviews the affected records, and runs a dry-run first.
5. After reviewing the eligible and skipped records, the user clicks the explicit approval/execution button.

The demo includes one real allowlisted recovery Flow: `FFM_DemoOrderRecovery`. It updates only the selected demo Account with a recovery marker. It does not replay `FFM_DemoOrderFlow`, send email, make a callout, or touch unrelated records. The demo path was tested end to end: one record previewed as eligible, job `RJ-00024` completed, and the Account description changed through the recovery Flow.

Before execution, the executor also verifies that the captured record still exists as an Account. Placeholder or deleted IDs are recorded as failed/skipped without invoking the recovery Flow, so a stale demo fixture cannot produce an opaque Flow fault.

For a sellable package, each customer action should have its own recovery Flow or Apex executor with explicit input mapping, idempotency checks, retry limits, permission checks, per-record audit results, and pause/cancel support. Generic replay remains disabled.
