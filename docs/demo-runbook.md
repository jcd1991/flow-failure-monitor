# Portfolio demo runbook

This is a controlled reliability-dashboard demo. It demonstrates captured Flow faults, counts, trends, grouping, impact analysis, investigation, and an optional safe recovery path.

## Trigger the real Flow fault path

The packaged `FFM_DemoOrderFlow` invokes `FFM_DemoFailureAction`. Its fault connector routes the exception to `FFM_DemoFaultLogger`, which publishes the normal `FFM_Failure_Capture__e` event.

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-flow-fault.apex
```

After platform-event delivery, open the Flow Failure Monitor tab. The dashboard should show the captured event in its cards, trend, top-Flow list, and impact queue.

## Seed the optional recovery fixture

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-preview.apex
```

This creates or reuses the demo failure group and `Demo order repair (approved Flow)` action.

## Dashboard validation

Verify:

- The default window is **Last 30 days**.
- Failure events and failure groups are visible.
- Repeated failures appear as one grouped fingerprint.
- Affected-record count is distinct rather than raw event count.
- The top Flow and failing element appear in the hotspot panels.
- The coverage panel explains fault connectors and supported capture events.
- Changing to 7 or 90 days reloads the snapshot.

## Investigation validation

Click **Investigate** for a group and verify:

- Captured samples and redacted messages are visible.
- The checklist distinguishes Flow fixes from data repair.
- Status actions update the group and add resolution history.
- Recovery is collapsed under **Advanced recovery (optional)**.

## Optional simulation

Expand advanced recovery, choose the approved demo action, and click **Run dry-run**. Then click **Simulate**. Eligible results become successful audit results, but no business record, Flow, email, or callout changes.

The equivalent CLI step is:

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-simulate.apex
```

## Optional valid recovery

Run:

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-actual-recovery.apex
```

Refresh the dashboard, open the seeded group, run the dry-run, then execute the approved demo recovery. Verify that only the `FFM Actual Recovery Demo` Account receives the recovery marker.

## Invalid-record safety path

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-invalid-record.apex
```

The expected result is:

```text
No matching Account exists; the recovery Flow was not executed.
```

## Capture boundary

The dashboard only reports failures that reach the package through an explicit fault connector calling `FFM_LogFlowErrorAction` or a supported `FFM_Failure_Capture__e` publisher. It is not an automatic org-wide Flow execution counter.
