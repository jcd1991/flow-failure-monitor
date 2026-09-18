# Portfolio demo runbook

This is a controlled, repeatable demo. It demonstrates a real Flow fault connector, detection, investigation, dry-run recovery, and a safe simulated completion without replaying the original Flow transaction. It also includes an optional allowlisted recovery Flow that changes one demo Account only.

## Trigger the real Flow fault path

The packaged `FFM_DemoOrderFlow` invokes `FFM_DemoFailureAction`, whose intentional exception is routed through the Flow's fault connector to `FFM_DemoFaultLogger`, then through the normal platform-event capture pipeline.

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-flow-fault.apex
```

After a short platform-event delivery delay, the dashboard shows a new `FFM_DemoOrderFlow / ValidateOrder` group.

## Seed and preview

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-preview.apex
```

Open the Flow Failure Monitor tab. Select the `FFM_DemoOrderFlow / RepairOrder` group, review the captured eligible and invalid records, mark the group Investigating, select `Demo order repair (dry-run only)`, and run the preview.

## Simulate the approved recovery

After reviewing the preview, click **Simulate approved recovery**. This updates only the recovery audit records: eligible results become `Success`, skipped records remain `Skipped`, and the job becomes `Completed`. No business record, Flow, email, or callout is changed.

The equivalent CLI step is:

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-simulate.apex
```

## What this proves

- A captured Flow failure can be grouped and investigated.
- Redacted failure samples and resolution history are visible.
- An approved recovery action can be previewed with eligible/skipped accounting.
- A completion path is auditable without pretending to replay a partially completed transaction.

## Execute the actual demo recovery

Run `sf apex run --target-org <org-alias> --file scripts/e2e-actual-recovery.apex`, refresh the dashboard, and open the `Demo failure before approved recovery` group. Select `Demo order repair (approved Flow)`, run the dry-run, then click **Execute approved demo recovery**. The expected result is `Eligible: 1`, `Success`, and a completed recovery job. Verify the Account named `FFM Actual Recovery Demo`; its Description will say that the approved recovery Flow executed.

This is deliberately limited to the allowlisted demo Flow. Real customer recovery still requires an org-specific Flow, idempotency contract, retry policy, and separate-user permission tests.
