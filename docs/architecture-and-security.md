# Architecture and security boundary

## Runtime path

```text
Flow fault connector
  → FFM_LogFlowErrorAction
  → platform event
  → capture handler/service
  → Flow_Error__c + Failure_Group__c
  → LWC dashboard / bounded DTO API
  → dry-run Recovery_Job__c
  → administrator approval
  → allowlisted recovery Flow
  → per-record Recovery_Result__c + audit history
```

The package does not intercept every Flow automatically. A subscriber Flow must explicitly connect its fault path to the packaged invocable action.

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
