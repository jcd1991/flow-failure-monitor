# flow-failure-monitor-mcp

Companion MCP server for Flow Failure Monitor. It calls the package's bounded REST API; it does not execute Apex, SOQL, recovery actions, or an embedded model.

Set `FFM_API_BASE_URL` to the Salesforce REST base ending in `/services/apexrest/ffm/v2` and provide a short-lived `FFM_API_TOKEN`. The tools include read-only listing/search/details, `create_resolution_plan`, and `preview_bulk_recovery`. The latter creates a Salesforce dry-run/audit record only; execution is intentionally disabled.
