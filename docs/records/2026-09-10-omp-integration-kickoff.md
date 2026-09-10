# 2026-09-10 -- omp↔hngh integration kickoff: operator priority directive

Operator-directed 2026-09-10: the session was instructed to advance
docs/project/plans/2026-09-09-omp-hngh-integration.plan.md as the priority
work ("smoothest and fastest and least-troubled progress", 2026-09-09
verbatim, reaffirmed in the kickoff). This record lands with the plan's
first commit per the plan's authorization clause.

## Beat 1 (this record)

- Appended "## Cost-controlled execution decomposition (2026-09-10)" to the
  plan file: steps 1-11 routed across quota legs (T2 GLM 5h/7d/monthly
  buckets for judgment-heavy steps; local/cheap legs for mechanical steps),
  with per-step verification surfaces and estimated session counts. Caps
  are never amended by machine sessions (standing directive
  docs/records/2026-09-09-budget-governance-directive.md); decomposition
  routes work only.
-- Implements plan step 1 in the follow-up commit: read-only MCP stdio server
  `automation/mcp/hngh_mcp_server.py` (tools hngh_present, hngh_status,
  queue_report, dashboard_readout) with
  `automation/tests/test-mcp-server.py`; full `automation make test` green
  including under `env -i`. Not registered in `.omp/mcp.json` or
  `~/.omp/agent/mcp.json` -- that is plan step 2 and waits on operator
  confirmation.
