# Flow Failure Monitor: five-minute demo

Flow Failure Monitor turns a failed Salesforce Flow into a bounded, reviewable incident. This walkthrough is designed for a GitHub README, portfolio review, or live screen share.

## What the demo shows

```text
Real Flow fault
  → fault connector
  → redacted capture event
  → grouped failure fingerprint
  → investigation workspace
  → dry-run recovery preview
  → approved recovery Flow or safe simulation
```

The demo offers two explicit endings: a no-side-effect simulation, or one allowlisted recovery Flow that changes only the seeded demo Account. Neither path replays the original failed transaction.

## 1. Start with a clean demo dataset

From the project root:

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-preview.apex
```

This creates or reuses the demo failure group and the approved recovery action. The fixture is idempotent, so it can be run repeatedly.

## 2. Trigger a real Flow failure

Run the packaged autolaunched Flow through its real fault path:

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-flow-fault.apex
```

`FFM_DemoOrderFlow` invokes an intentionally failing Apex action. Its fault connector invokes the capture logger, which publishes the same platform event used by subscriber Flows.

Wait a few seconds for platform-event delivery, then open the Salesforce tab:

`/lightning/n/Flow_Failure_Monitor1`

## 3. Investigate the incident

Open the `FFM_DemoOrderFlow / ValidateOrder` group.

Point out:

- The grouped fingerprint and occurrence count
- The redacted fault message
- The source `demo-fault-connector`
- The captured record reference
- The resolution history
- The troubleshooting checklist

Click **Mark investigating**. This creates a status activity record; it does not alter the failed business transaction.

## 4. Preview the approved recovery

Choose `Demo order repair (approved Flow)` and click **Run dry-run**.

Explain the result:

- Eligible records can be handled by the configured action.
- Invalid or missing record IDs are skipped.
- A `Recovery_Job__c` audit record is created.
- No recovery Flow, email, callout, or business-record update executes.

## 5. Complete the safe portfolio demo

For a no-side-effect walkthrough, click **Simulate** with `(no business change)` underneath. For the actual demo path, click **Execute** with `(approved recovery)` underneath; that button is enabled only for the allowlisted demo action.

The valid demo result becomes `Success`, and the job becomes `Completed`. To demonstrate the safety guard, run `scripts/e2e-invalid-record.apex`, open its group, and execute the same action: the result should say `No matching Account exists; the recovery Flow was not executed.`

The equivalent CLI step is:

```bash
sf apex run --target-org <org-alias> --file scripts/e2e-actual-recovery.apex
sf apex run --target-org <org-alias> --file scripts/e2e-invalid-record.apex
```

## Suggested README media

For a public repository, capture three sanitized screenshots or a short GIF:

1. Dashboard summary showing grouped failures.
2. Investigation dialog showing samples and checklist.
3. Preview result showing eligible/skipped counts and simulated completion.

Do not include org URLs, usernames, record IDs, access tokens, or customer data in public media.

## Safety boundary

This project intentionally does not implement generic “replay the failed Flow.” Flows may have partially created records, sent emails, made callouts, or updated related records. Real recovery execution requires an org-specific approved recovery Flow, explicit administrator approval, idempotency guarantees, retry limits, and separate permission tests.
