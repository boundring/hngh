<!-- plan: status=accepted risk=normal accepted=2026-09-09T15:01:13Z -->
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
- [x] 2. Register the server for omp: add an entry to this repo's
      `.omp/mcp.json` (`hngh` → `python automation/mcp/hngh_mcp_server.py`)
      and, after the operator confirms, mirror it in
      `~/.omp/agent/mcp.json`.
      Verification: an omp session in this repo observes
      `xd://mcp__hngh_*` tools via `/mcp`.
- [x] 3. Extend `scripts/omp-bridge` with the two subcommands the plugin and
      MCP server back onto (single adapter, dependency inward):
      `--propose <plan-slug>` (writes `docs/project/plans/<date>-<slug>.plan.md`
      with `status=proposed` front-matter, refuses non-ASCII slugs and
      duplicate filenames) and `--plan-status` (emits JSON of plan
      front-matter + `automation/dashboard/plans.json` status).
      Verification: script-suite test in `automation/` covering both
      subcommands including duplicate-slug refusal; `make test` green.
- [x] 4. omp plugin `hngh-bridge` (file: link plugin, modeled on the existing
      `~/.omp/plugins/lisp-paren-fix` package): exposes a `hngh_propose` tool
      that calls `omp-bridge --propose` and reads back `--plan-status` — the
      plan-file propose surface promised by `docs/project/plans/README.md`.
      Register in `~/.omp/plugins/package.json` as a `file:` dep.
      Verification: plugin loads in an omp session (`/pi-install`-style
      listing), one propose round-trip writes a plan file and reads status
      back; `automation/` link check passes.
- [x] 5. Project skill `.omp/skills/hngh/SKILL.md`: orients any omp session
      working in this repo — the ceremony loop (propose → issue-cert →
      mutation-check), the plan-file contract, the commit-per-green rule, the
      kernel side-effect boundary, and when to use `omp-bridge --orient`.
      Keep it terse; link `docs/README.md` and
      `docs/design/autonomous-development-control.md` instead of duplicating.
      Verification: skill appears in an omp session in this repo and its
      triggers fire on a ceremony question.
- [x] 6. Custom agent definitions formalizing the delegated sessions the
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

## Cost-controlled execution decomposition (2026-09-10)

Quota-leg context (docs/research/2026-09-10-lobehub-api-research.md):
OpenCode Go T2 GLM resets on 5-hour / 7-day / monthly buckets -- pace heavy
design work within the 5h bucket, never dumped at once; LobeHub and
OpenRouter legs are daily-reset; Kimi has multi-tier resets. Standing rule
(docs/records/2026-09-09-budget-governance-directive.md): caps are never
amended by machine sessions -- this decomposition routes work, it does not
raise any cap.

| Step | Dependency | Executing surface | Verification surface | Est. sessions |
|------|-----------|-------------------|----------------------|---------------|
| 1. MCP stdio server | none | local/cheap leg; mechanical adapter code, no design load | stdio client probe + automation test + `make test` | 1 |
| 2. MCP registration | 1 | local/cheap; config-only, no model spend | omp session `/mcp` tool visibility (omp native) | 0-1 |
| 3. omp-bridge subcommands | none (1 for surfaces) | local/cheap; pure scripting + tests | script-suite test + `make test` | 1 |
| 4. hngh-bridge plugin | 3 | local/cheap; plugin plumbing is mechanical | omp plugin listing + propose round-trip | 1 |
| 5. hngh skill | 1-3 (context) | local model for the draft; terse doc, no research sweep | omp skill trigger probe | 1 |
| 6. agent definitions | 3, 5 | T2 GLM within 5h bucket pacing (agent-front-matter design) | omp agent load + dry executor run | 1 |
| 7. TTSR/rulebook expansion | 5-6 | T2 GLM within 5h bucket (audit is judgment-heavy); OpenRouter leg only for the probe-session runs if T2 is exhausted | rule trigger probe + `22-ttsr-fit` | 1-2 |
| 8. Context-seeding | 4 | local/cheap; lifecycle hook is a small extension patch | fresh-session orient observation | 1 |
| 9. Research feed wiring | 1 | local/cheap; TSV wiring mechanical | research beat writes a line; tool reflects it | 1 |
| 10. Dashboard JSON endpoint | 3 | local/cheap; single script + page, no design sweep | endpoint vs queue.md/plans.json diff | 1 |
| 11. Records + changelog | all | local/cheap; write-up only | `make test` green | 1 |

Pacing rule: any step marked T2 rides the 5h bucket one step per bucket;
mechanical steps stack freely on local/cheap legs. Cap-block still files an
operator-item per the standing directive; it never self-raises.
