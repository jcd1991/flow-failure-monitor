# Packaging and security release gates

The source project is intentionally namespace-free until the publisher registers the namespace. A namespaced 2GP cannot be truthfully created from this repository until that namespace exists. After registration, set `namespace` in `sfdx-project.json`, run `sf package create --name "Flow Failure Monitor" --package-type Managed --path force-app --target-dev-hub <dev-hub-alias>`, and add the resulting package ID to `packageAliases`. This is the one remaining publisher-account setup step.

Use `config/project-scratch-def.json` for CI and scratch-org validation. The release pipeline must run Apex tests, metadata validation, API contract tests, permission-negative tests, install/upgrade tests, and an explicit subscriber-org smoke test.

The `/ffm/v2` API returns DTOs rather than SObjects, enforces 1–200 page limits, caps trends at 90 days, redacts by default, uses USER_MODE queries, sends `Cache-Control: no-store`, and exposes a rate-limit ceiling header. Enforcement should be applied at the connected-app/API gateway layer because Salesforce REST requests are stateless; the package does not pretend that a response header alone is a limiter. Integrations should use short-lived OAuth access tokens or a connected app with rotation and revocation procedures; never commit tokens or use a permanent token in CI.

Retention is an operational policy: keep detailed samples for the configured incident window, retain grouped fingerprints and audit records longer, and schedule deletion through a reviewed, bounded admin job. Do not purge evidence automatically as part of recovery.
