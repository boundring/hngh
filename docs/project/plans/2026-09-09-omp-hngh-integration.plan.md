<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-09 — omp↔hngh full integration: plugin, MCP, skills, TTSR, context-seeding

Operator-directed. Goal: make oh-my-pi (omp) and hngh a fully integrated pair —
hngh exposes itself to omp through every viable surface, and omp becomes the
operator's UI/UX for hngh (orientation, context-seeding, research feed, work
requests). This plan was authored in an operator omp session on 2026-09-09 and
handed off; execution belongs to the 24/7 cycle, step by step.

Authorization: operator-directed 2026-09-09. The operator instructed this
session to prioritize this plan for "the smoothest and fastest and
least-troubled progress" (verbatim) after reviewing the queue state
(62 accepted plans ahead, fail-first parallel slots, 45-77 commits/day
recent throughput). The executing session folds this directive into
docs/records/ with its first commit so the audit trail lands with the
plan file.

## Execution priority directive

The selector runs accepted plans in filename order with parallel slots.
This plan is operator-prioritized: it proceeds ahead of discretionary
and research-filler work wherever the executor has scheduling latitude.
Steps are dependency-ordered (1-3 foundation; 4-8 depend on 3; 9
depends on 1; 10-11 last), so each beat makes safe progress regardless
of scheduling. Executor sessions do not wait on human approval;
governance (certificates + green gates) is the only barrier. Each step
verifies on its own surface; omp-side verification runs through the
delegated omp session itself (`omp -p`), which is native to this cycle.

Evidence base for the omp side: omp internal docs (`omp://extensions.md`,
`omp://mcp-config.md`, `omp://plugin-manager-installer-plumbing.md`,
`omp://skills.md`, `omp://ttsr-injection-lifecycle.md`, `omp://custom-tools.md`;
public mirror `github.com/can1357/oh-my-pi/docs`). hngh side: this repo's
`docs/core/component-map.md`, `docs/records/2026-08-26-omp-bridge.md`,
`docs/project/plans/README.md` (which explicitly reserves the omp plugin
propose surface — this plan is the first use of it from an operator session).

## Architecture constraint (applies to every step)

The hngh kernel stays side-effect-free. All omp-facing code lives in two
places, never in `src/`:

- hngh side: `automation/` (Python/bash adapters wrapping read-only kernel CLI)
- omp side: an omp plugin + rules + skills + agent definitions (markdown/TS)

Dependency direction: automation adapters call the hngh CLI inward; the kernel
never knows omp exists. No step touches provider/credential configuration
(those are `risk=critical` and out of scope).

## Steps

- [ ] 1. Read-only MCP stdio server `automation/mcp/hngh_mcp_server.py`,
      wrapping existing hngh CLI read-only commands as MCP tools:
      `hngh present`, `hngh status`, `scripts/report-queue`,
      `scripts/dashboard-readout` (JSON mode if available). stdio transport,
      no daemon — spawned per connection by omp. Model the server on the
      existing misakanet stdio server (`~/.local/share/misakanet/scripts/mcp_server.py`).
      Verification: server answers one tool call over stdio from a
      throwaway client script; a pytest in `automation/` covers tool dispatch.
- [ ] 2. Register the server for omp: add an entry to this repo's
      `.omp/mcp.json` (`hngh` → `python automation/mcp/hngh_mcp_server.py`)
      and, after the operator confirms, mirror it in
      `~/.omp/agent/mcp.json`.
      Verification: an omp session in this repo observes
      `xd://mcp__hngh_*` tools via `/mcp`.
- [ ] 3. Extend `scripts/omp-bridge` with the two subcommands the plugin and
      MCP server back onto (single adapter, dependency inward):
      `--propose <plan-slug>` (writes `docs/project/plans/<date>-<slug>.plan.md`
      with `status=proposed` front-matter, refuses non-ASCII slugs and
      duplicate filenames) and `--plan-status` (emits JSON of plan
      front-matter + `automation/dashboard/plans.json` status).
      Verification: script-suite test in `automation/` covering both
      subcommands including duplicate-slug refusal; `make test` green.
- [ ] 4. omp plugin `hngh-bridge` (file: link plugin, modeled on the existing
      `~/.omp/plugins/lisp-paren-fix` package): exposes a `hngh_propose` tool
      that calls `omp-bridge --propose` and reads back `--plan-status` — the
      plan-file propose surface promised by `docs/project/plans/README.md`.
      Register in `~/.omp/plugins/package.json` as a `file:` dep.
      Verification: plugin loads in an omp session (`/pi-install`-style
      listing), one propose round-trip writes a plan file and reads status
      back; `automation/` link check passes.
- [ ] 5. Project skill `.omp/skills/hngh/SKILL.md`: orients any omp session
      working in this repo — the ceremony loop (propose → issue-cert →
      mutation-check), the plan-file contract, the commit-per-green rule, the
      kernel side-effect boundary, and when to use `omp-bridge --orient`.
      Keep it terse; link `docs/README.md` and
      `docs/design/autonomous-development-control.md` instead of duplicating.
      Verification: skill appears in an omp session in this repo and its
      triggers fire on a ceremony question.
- [ ] 6. Custom agent definitions formalizing the delegated sessions the
      cycle already spawns: `.omp/agents/hngh-executor.md` (one verified
      step, certificate ceremony, commits only on green gate) and
      `.omp/agents/hngh-scout.md` (read-only research into
      `automation/research-lines.tsv` conventions). Align their front-matter
      with what `automation/scripts/overnight-cycle.sh` passes through today.
      Verification: definitions load as agents in an omp session; a dry
      executor run on a parked plan produces a proposal, not a mutation.
- [ ] 7. TTSR/rulebook expansion from ceremony lessons: audit
      `.omp/rules/` (2 live rules) and `~/.omp/agent/rules/` (16 live) against
      the lessons in `docs/design/autonomous-development-control.md` and
      `docs/records/2026-09-04-transcript-stall-no-replace.md`; add only rules
      that close a real observed failure mode (candidates: ceremony-session
      scope guard, plan-file front-matter guard for `hngh_propose` writes).
      Deduplicate with the existing `22-ttsr-fit` cadence screen.
      Verification: each new rule fires on its stated trigger in a probe
      session and stays silent on normal traffic; `22-ttsr-fit` reports no drift.
- [ ] 8. Context-seeding: make `omp-bridge --orient` run automatically for
      every omp session entering this repo (extension session-lifecycle event
      in the `hngh-bridge` plugin, or a rulebook `condition` rule if events
      cannot inject). Orientation output stays read-only and small.
      Verification: a fresh omp session in this repo receives the brief
      without operator action; logs show one orient call per session start.
- [ ] 9. Research feed: wire hngh-scout / research-beat outputs into the
      existing research pipeline — `automation/research-lines.tsv` and
      `automation/research-dispositions.tsv` — and surface current research
      lines through the MCP server (extends step 1 with a `research_lines`
      tool).
      Verification: tool returns the live TSV contents; a research
      beat writes a line and the tool reflects it.
- [ ] 10. Dashboard as operator UI: add a read-only JSON endpoint (or extend
      `dashboard/plans.json`) covering queue + accepted plans + last ceremony
      commit, and a dashboard page rendering it, so the operator can view
      hngh state from omp (browser relay) or `scripts/dashboard-tui`.
      Verification: endpoint returns live data matching `queue.md` and
      `plans.json`; page renders in the running dashboard.
- [ ] 11. Records: `CHANGELOG.md` entry + `docs/records/2026-09-XX-omp-integration.md`
      describing the integrated surface set, and update
      `docs/project/plans/README.md` only if the propose surface gained
      behavior.
      Verification: `make test` green; record cross-linked from
      CHANGELOG.

## Execution notes

- Steps 1–3 are the foundation; 4–8 depend on 3; 9 depends on 1; 10 and 11
  are last. The cycle's oldest-accepted-first rule handles ordering.
- omp-side steps (4–8) should be developed with the plugin loaded live in an
  omp session; hngh-side steps follow the normal failing-test-first rule.
- No step starts daemons, writes `~/.hngh`, or touches the kernel.
