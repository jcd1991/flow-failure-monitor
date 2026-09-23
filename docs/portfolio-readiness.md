# Portfolio and GitHub readiness check-in

## Current result

The project is a credible Salesforce/API portfolio prototype, but it is not yet GitHub-ready as a standalone repository.

### Implemented and verified

- Managed-package-shaped Salesforce source with bounded v2 DTO API.
- Separate MCP companion with read-only tools, resolution planning, and preview-only recovery.
- Repeatable real-data seed fixture and simulated recovery fixture.
- Flow Reliability Dashboard with counts, bounded trends, grouped fingerprints, affected-record impact, samples, history, status updates, dry-run preview, and safe simulation.
- Apex tests: 7/7 passing in the Developer Edition org.
- Valid recovery demo: allowlisted recovery Flow updated the seeded Account through job `RJ-00024`.
- Invalid-record safety demo: stale Account IDs are rejected before Flow execution.
- MCP TypeScript build passing; production dependency audit reported zero vulnerabilities.
- Public walkthrough, architecture/security boundary, and production roadmap are documented.

### Blocking GitHub publication items

1. A dedicated local Git repository is now initialized here and the complete source tree is staged. Add the intended GitHub remote and create the first commit only after choosing the author identity; do not silently mix it into the unrelated `sflens` repository.
2. Register a Salesforce namespace and create a managed 2GP package. `sfdx-project.json` is intentionally namespace-free today.
3. Add a package lockfile and commit the generated `flow-failure-monitor-mcp/package-lock.json` so the existing CI `npm ci` step is reproducible.
4. Add a sanitized README screenshot or short demo capture; do not publish org URLs, user names, access tokens, or record identifiers.
5. Add CI secrets and a real scratch-org/package validation job before claiming CI is green.
6. Add negative permission tests with a separate restricted user and install/upgrade tests in a subscriber-style org.

## Portfolio finish line

The portfolio version is complete when the README starts with the dashboard story, the reviewer can see counts/trends/grouping/impact, and the walkthrough includes one valid recovery plus one invalid-record guard. This repository meets that bar. It is a focused prototype, not a claim of AppExchange production readiness.

## Production roadmap

1. Register a namespace and create a managed 2GP.
2. Add subscriber-org install/upgrade tests and separate-user negative permission tests.
3. Move recovery execution to asynchronous, pauseable jobs with stronger idempotency and retry controls.
4. Add customer-configured action registration and object/input validation.
5. Add retention controls, operational rate limiting, support runbooks, and AppExchange security review evidence.
6. Add Agentforce/MCP resolver planning only behind the same allowlists and approval gates.

## Recommended publication gate

Publish the portfolio repository after adding sanitized screenshots or a short recording. Do not publish org URLs, usernames, record IDs, access tokens, or customer data.
