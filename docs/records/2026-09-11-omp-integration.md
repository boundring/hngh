# omp-hngh integration: the integrated surface set

Date: 2026-09-11. Scope: plan 2026-09-09-omp-hngh-integration, steps
1-11 (ce7e072, f9b1360, a2f4d0e + 31768d2, 7ed5971, e82b808, 67af769,
f19015f, ec00ab9; closed by this record's commit).

## What landed

1. **Read-only MCP stdio server** (automation/mcp/hngh_mcp_server.py,
   ce7e072; extended f19015f): five tools, each one subprocess call to
   an existing read-only CLI — `hngh_present`, `hngh_status`,
   `queue_report` (scripts/report-queue --json), `dashboard_readout`
   (scripts/dashboard-readout --json), `research_lines` (live
   research-lines.tsv + research-dispositions.tsv, 200-row cap with a
   truncated flag). Spawned per stdio connection by omp; no daemon.
   Tested by automation/tests/test-mcp-server.py.
2. **MCP registration** (.omp/mcp.json + ~/.omp/agent/mcp.json,
   f9b1360): server name `hngh`, so every omp session in this repo
   observes the tools as `mcp__hngh_*`.
3. **omp-bridge propose surface** (scripts/omp-bridge, a2f4d0e; slug
   fix 31768d2): `--propose SLUG --title TEXT [--risk]` writes a NEW
   docs/project/plans/<date>-<slug>.plan.md with status=proposed
   front-matter (refuses non-ASCII slugs and duplicate filenames,
   never overwrites); `--plan-status [SLUG]` emits front-matter + step
   checkboxes as JSON cross-checked with the dashboard's plans.json
   (dashboard rows win, source-flagged) and accepts a bare slug or the
   full date-prefixed stem (31768d2). Tested by
   automation/tests/test-omp-bridge.py.
4. **hngh-bridge plugin** (~/.omp/plugins/hngh-bridge, 7ed5971; outside
   the repo, registered as a `file:` dep in
   ~/.omp/plugins/package.json): the `hngh_propose` custom tool wraps
   --propose and reads back --plan-status; fail-closed — omp-bridge's
   0/1/2/3 exit protocol surfaces as tool errors carrying the CLI
   stderr. (Deploy note below.)
5. **Project skill** (.omp/skills/hngh/SKILL.md, e82b808): orients any
   omp session working in this repo — ceremony loop, plan-file
   contract, commit-per-green rule, kernel side-effect boundary,
   --orient entry; links docs instead of duplicating.
6. **Agent definitions** (.omp/agents/hngh-executor.md, hngh-scout.md,
   7ed5971): executor = one verified step, certificate ceremony,
   commits only on a green gate; scout = read-only research into the
   research-lines.tsv conventions.
7. **Quota TTSR rules** (five files in ~/.omp/agent/rules/, outside the
   repo, landed 2026-09-10): quota-leg-in-pipeline-readiness,
   quota-leg-attribution, quota-tightest-window-pacing,
   quota-empty-work-skip, quota-leg-edge-timeout-budget — candidates
   R1-R5 of docs/research/2026-09-10-passthrough-and-quota-interleaving.md
   section 4 (each cites the observed failure that motivates it;
   quiet-hours pinning was evaluated and rejected there).
8. **Context-seeding** (67af769): a plugin session_start extension
   (src/orient.ts) runs `python3 scripts/omp-bridge --orient` when the
   session cwd is this repo and injects the brief via sendMessage —
   print-mode-safe (sendUserMessage throws AgentBusyError while the -p
   prompt is streaming), 5 s bound, fail-open, deduped per session via
   a com.hngh.orient custom entry.
9. **Research feed tool** (f19015f): `research_lines` returns the live
   TSV rows, so a research beat's write is visible to the next tool
   call — no dashboard round-trip.
10. **Dashboard as operator UI** (ec00ab9): automation/jobs/plan-feed.py
    adds additive `queue_next` and `last_ceremony_commit` fields to
    automation/dashboard/plans.json, and the dashboard renders a Plans
    tab (automation/dashboard/plans-view.js) — the operator reads hngh
    state from omp (browser relay) or scripts/dashboard-tui.
11. **Records** (this commit): CHANGELOG entry + this record + one line
    in docs/project/plans/README.md (the propose surface's readback
    gained bare-slug behavior, so the interface section documents it).

## The surface set as an omp session now sees it

- Session start (cwd in this repo): the orient brief arrives without
  operator action — roadmap Next, queue Next, dirty-tree check, last
  ceremony commit.
- Read-only state on demand: the five MCP tools under the `hngh`
  server.
- The write path into the plan queue: `hngh_propose` (the propose
  surface docs/project/plans/README.md reserves) with status readback;
  status reads also available via `omp-bridge --plan-status`.
- Personas and guardrails: the `hngh` skill fires on ceremony/plan/
  commit questions; hngh-executor and hngh-scout load as
  delegated-session agents; the five quota-* TTSR rules police quota
  pacing and attribution.
- Operator view: the dashboard Plans tab (queue + accepted plans + last
  ceremony commit) via browser relay or scripts/dashboard-tui.

## Governance boundaries preserved

- The kernel never knows omp exists: no omp/MCP code in src/ — every
  omp-facing surface is a subprocess call to an existing read-only CLI,
  dependency direction inward only.
- All omp-facing code lives in automation/ (MCP server, bridge, plan
  feed + their tests), .omp/ (repo-side skill, agents, mcp.json) and
  ~/.omp/ (plugin, rules, registration) — nowhere else.
- No daemons: the MCP server is spawned per connection; omp-bridge and
  the plugin tool are one explicit command per invocation; the orient
  extension runs once per session start.
- The propose surface only ever creates new plan files; acceptance
  stays with the existing normal-risk auto-accept rules. Provider/
  credential configuration was never touched (risk=critical, out of
  scope).

## Deploy note: plugin file: deps are copied, not linked

~/.omp/plugins/package.json installs `hngh-bridge` as a `file:` dep,
and the installer COPIES the plugin sources into node_modules at
install time. Editing ~/.omp/plugins/hngh-bridge/src in place does not
change what a running omp session loads — future plugin edits need a
re-copy / re-install (bun install in ~/.omp/plugins) first. This
footgun cost one probe cycle during step 8 (orient edits looked inert
because the loaded copy was stale).
