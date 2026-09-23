# Architecture and security boundary

## Runtime path

```text
Flow fault connector
  → FFM_LogFlowErrorAction
  → platform event
  → capture handler/service
  → Flow_Error__c + Failure_Group__c
  → bounded dashboard snapshot / LWC dashboard / DTO API
  → dry-run Recovery_Job__c
  → administrator approval
  → allowlisted recovery Flow
  → per-record Recovery_Result__c + audit history
```

The package does not intercept every Flow automatically. A subscriber Flow must explicitly connect its fault path to the packaged invocable action, or publish a supported `FFM_Failure_Capture__e` event. Dashboard counts, trends, grouping, and impact are calculated only from captured `Flow_Error__c` records; they are not a claim about every Flow execution in the org. Native Salesforce Flow monitoring remains a separate source of information.

The dashboard snapshot accepts only a bounded 1–90 day window (7, 30, or 90 days in the UI) and returns DTOs for event counts, distinct groups, distinct captured records, open groups, daily trends, top Flows/elements, and the top 50 impact groups. Overview responses do not expose raw long-text fault context.

## Security controls

- Apex services use sharing-aware access and user-mode queries where supported.
- API responses are DTOs, not raw SObjects.
- API routes, page sizes, trend windows, fields, and search inputs are bounded.
- Fault messages are redacted before they appear in external responses.
- Recovery requires an active, configured action and a dry-run job.
- The demo executor is hard-coded to one allowlisted action and one recovery Flow.
- Captured IDs are validated for format and existence before the Flow runs.
- Invalid or deleted records receive a per-record failure result; the Flow is not invoked.
- Simulation changes audit state only; it never changes business data.
- MCP delegates to the Salesforce API and cannot execute arbitrary Apex or SOQL.

## What is intentionally not implemented

- Generic replay of a failed Flow transaction
- AI-generated Apex execution
- Arbitrary metadata mutation in production
- Automatic recovery without administrator approval
- Unbounded bulk execution

Production hardening would add asynchronous pauseable jobs, customer-configured action registration, stronger idempotency and retry policy, subscriber-org permission tests, retention controls, and managed 2GP packaging.
