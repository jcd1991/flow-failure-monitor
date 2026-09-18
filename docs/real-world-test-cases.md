# Real-world Flow failure test cases

These fixtures are sanitized reproductions of recurring public Salesforce Flow failure patterns. They preserve the operational shape of the failures without copying user-specific code or data.

| Case | Flow element | Failure shape | What Flow Failure Monitor should show |
| --- | --- | --- | --- |
| Duplicate-rule DML | CreateAccount | `DUPLICATES_DETECTED` / duplicate value | Grouped DML fingerprint, repeated occurrences, affected records |
| Validation-rule DML | UpdateOrder | `FIELD_CUSTOM_VALIDATION_EXCEPTION` | Redacted validation message and troubleshooting context |
| Callout after work | SendToERP | `System.CalloutException` / uncommitted work pending | Callout-specific fingerprint; do not recommend replaying the transaction |
| Bulk duplicate IDs | UpdateTasks | `System.ListException: Duplicate id in list` | Bulk/cohort grouping and per-record preview accounting |

## Public references

- [Handling trigger/DML errors from Flow](https://salesforce.stackexchange.com/questions/214642/how-to-handle-trigger-error-when-flow-creates-record)
- [Duplicate records and Flow validation](https://salesforce.stackexchange.com/questions/399807/can-record-trigger-flow-throw-error-message-like-validation-rule/399811)
- [Flow callout after uncommitted work](https://salesforce.stackexchange.com/questions/205933/help-with-flow-apex-error-system-calloutexception-you-have-uncommitted-work-pe)
- [Duplicate IDs in bulk Flow updates](https://salesforce.stackexchange.com/questions/380667/flow-maximum-number-of-duplicate-updates-in-one-batch-12-allowed)

## Run the cases

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-real-world-cases.apex
```

The script publishes eight events through `FFM_LogFlowErrorAction`. After platform-event delivery, open the dashboard and filter or investigate each `FFM_RealWorld_*` group. Select an approved action, run a dry-run, and verify eligible/skipped counts before using the simulation-only completion.

These are observability and safety cases, not instructions to retry the underlying transaction. In particular, the callout and bulk-update cases may have partially completed work or duplicate side effects.
