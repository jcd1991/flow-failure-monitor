# Flow Reliability Dashboard: five-minute demo

Flow Failure Monitor turns captured Salesforce Flow failures into a reliability dashboard: counts, trends, grouped fingerprints, affected-record impact, and a focused investigation path. Recovery is intentionally secondary; the product does not blindly replay failed transactions.

## What the audience sees

```text
Open dashboard
  → choose 7/30/90-day window
  → read counts and failure trend
  → identify top failing Flow/element
  → inspect affected-record impact
  → investigate one group
  → optionally preview an approved recovery
```

The dashboard is based on `Flow_Error__c` and `Failure_Group__c` records captured by the package. It is not an automatic counter of every Flow execution in the org.

## 1. Seed the demo data

From the project root:

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-preview.apex
```

This creates or reuses the demo failure group and approved recovery action. The fixture is idempotent.

## 2. Trigger a real Flow fault

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-flow-fault.apex
```

`FFM_DemoOrderFlow` intentionally fails an Apex action. Its fault connector passes `$Flow.FaultMessage` to `FFM_DemoFaultLogger`, which publishes the normal `FFM_Failure_Capture__e` event. After platform-event delivery, open:

`/lightning/n/Flow_Failure_Monitor1`

## 3. Start on the dashboard

Point out:

- **Failure events:** captured fault records in the selected time window.
- **Failure groups:** recurring fingerprints, not raw Flow runs.
- **Affected records:** distinct captured record IDs.
- **Open groups:** groups still marked New, Acknowledged, or Investigating.
- **Failure trend:** daily captured-event volume.
- **Top failing Flows/elements:** where to investigate first.
- **Impact queue:** event count, record count, status, and representative message.

Change the time window from 30 days to 7 or 90 days to show that the dashboard is queryable over a bounded period.

## 4. Explain capture coverage

The coverage panel is intentionally visible. The dashboard only receives failures from:

1. An explicit Flow fault connector that calls `FFM_LogFlowErrorAction`.
2. A supported publisher of `FFM_Failure_Capture__e`.

If a Flow has neither, the dashboard cannot infer that it failed. An empty dashboard means “no captured events,” not necessarily “every Flow is healthy.”

## 5. Investigate one group

Click **Investigate** in the impact queue. Show:

- Captured samples and redacted messages.
- Record references and retry counts.
- The troubleshooting checklist.
- Resolution history.
- **Mark investigating** and **Mark resolved** status actions.

The checklist tells the admin to fix Flow metadata when the logic is wrong and to use recovery only for already-affected records.

## 6. Optional advanced recovery

Expand **Advanced recovery (optional)** only after the dashboard story is complete.

Choose `Demo order repair (approved Flow)` and click **Run dry-run**. Explain:

- Eligible and skipped records are counted.
- A `Recovery_Job__c` audit record is created.
- No recovery Flow or business record changes during preview.
- Simulation changes audit records only.
- Execute is restricted to the allowlisted demo recovery Flow.

For the valid path:

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-actual-recovery.apex
```

For the safety path:

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-invalid-record.apex
```

The invalid path must report `No matching Account exists; the recovery Flow was not executed.`

## Safety boundary

This project does not implement generic “replay the failed Flow.” A failed Flow may already have created records, sent email, made a callout, or updated related records. Real recovery requires an org-specific repair Flow, idempotency guarantees, explicit approval, retry limits, and separate permission tests.
