---
name: hngh
description: Governs any omp session working in the hngh repo — ceremony loop (propose, issue-cert, mutation-check), plan-file lifecycle, commit-per-green rule, kernel side-effect boundary, and omp-bridge --orient entry. Use whenever the task touches plans, certificates, commits, or src/ in hngh.
---

# hngh project orientation

You are working in the hngh repo (Common Lisp kernel + the in-repo `automation/` tier). Read `docs/README.md` for the canonical read-order; do not re-walk it.

## Orientation entry

Run `python3 scripts/omp-bridge --orient` at session start and after queue rotation. It hands you a fresh project-state brief (roadmap Next, queue Next, dirty-tree check, last ceremony commit) so you do not re-walk files yourself.

## Ceremony loop

Kernel/doc changes land ONLY through the certificate ceremony: propose → issue-cert → mutation-check. Full contract and rationale: `docs/design/autonomous-development-control.md`. Do not restate or shortcut it; use `scripts/omp-bridge --ceremony` for the flock/timeout wrapper.

## Plan-file contract

- File: `docs/project/plans/<date>-<slug>.plan.md`.
- Front-matter is the first HTML comment: `<!-- plan: status=proposed|accepted|executing|executed|parked risk=normal|critical accepted=<UTC ts or -> -->`.
- Steps live under `## Steps` as `- [ ]` / `- [x]` checkboxes.
- Propose via `python3 scripts/omp-bridge --propose SLUG --title TEXT [--risk normal|critical]`; it refuses duplicates and non-ASCII slugs.
- Read status back via `python3 scripts/omp-bridge --plan-status SLUG` (accepts bare slug or date-prefixed stem).
- NEVER overwrite an existing plan file in place; full lifecycle: `docs/project/plans/README.md`.

## Commit-per-green rule

- `automation/` commits are free once automation `make test` exits 0.
- Kernel `src/`, `tests/`, `Makefile`, and `hngh.asd` are FORBIDDEN to machine sessions — park them with an operator alert instead.
- Autonomy reference: `docs/project/plans/README.md` ("Autonomy reference").

## Delegated opencode sessions (opencode-go / Kimi quota legs)

Subagent work can be delegated as a bounded opencode session on the operator's paid quota legs via the `hngh_opencode` tool (hngh-bridge plugin) or `bash automation/lib/ocgo-delegate.sh SLUG OBJECTIVE [MAX_MINUTES] [PROVIDER]`. PROVIDER selects the quota: `opencode-go` (default; 5h+7d+monthly windows gated, tightest wins) or `kimi` (Kimi Code K3; daily pacer vs kimi-daily-cap, runs the `executor-kimi` agent, attributes `source=kimi`) or `zai` (Z.AI subscription, runs `executor-zai`, attributes `source=zai`; 5h + fixed-Monday-week windows gated — the subscription replaces openrouter for z-ai-model calls). Pacing is enforced at the launch branch itself (tightest-window rule), so even direct launch_session callers cannot land an unpaced call. Exit 75 = refused fail-closed before any spend; missing credential/model row falls back to omp. Full contract: the `opencode-delegate` skill (`~/.omp/agent/managed-skills/opencode-delegate/SKILL.md`); config layer `automation/config/opencode/opencode.jsonc`; verified live 2026-09-13 on all three providers.

## Delegating to hngh-executor vs hngh-scout

Two omp agent definitions live in `.omp/agents/` (one source of truth — never duplicate them): `hngh-executor` (ONE verified plan step through the ceremony loop, commits only on a green gate) and `hngh-scout` (read-only research: research-lines.tsv surveys, docs/research/ evidence drafts; restricted toolset).

- **Scout** for orientation/research/expedition slices — the roadmap's bounded read-only rung. Default the scout to the cheapest leg: its restricted toolset runs on the session's own model; never route a scout through a paid quota leg unless the operator pins it.
- **Executor** for implementation slices under the gates. Executor legs MAY run on the quota legs (`hngh_opencode` tool, PROVIDER=opencode-go|kimi|zai) per the pacing contract above.

## Per-spawn preparation (anti-stutter rule)

Every hngh-executor / hngh-scout spawn starts oriented WITHOUT re-walking files: seed the first prompt with the `hngh_brief` tool's output (or `python3 scripts/omp-bridge --orient`), plus exactly the slice-relevant context (plan file path, step id, assigned files), plus this first-turn instruction: "The brief above is current project state — do not re-run orientation reads (omp-bridge --orient, queue/roadmap files) before acting." Spawn template: brief -> slice context -> first-turn instruction -> agent definition's own contract. The brief is per-spawn, never cached across spawns.

## Kernel side-effect boundary

The kernel never knows omp exists. All omp-facing code lives in `automation/` adapters (plus this repo's `.omp/` surface). Never add omp/automation imports or hooks inside `src/`.

## Userspace data home

Userspace data (newspaper copies, manga outputs, digest archives,
dispatch editions, databases, knowledge-base content) lives under
`~/.hngh/` — `newspaper/<date>/`, `manga/`, `wiki/`, `db/`, `archive/`,
`dispatch/`, append-only `catalog.tsv`. Machine sessions may write there
for userspace data; resolve paths via `automation/lib/hngh_home.py` or
`lib/common.sh` (`HNGH_HOME_DIR` overrides for tests). Never commit
anything under `~/.hngh/`. Secrets, credentials, and kernel run stores
stay in `~/.hngh-automation/`; kernel/gate/certificate state never moves
to `~/.hngh`, and `src/` knows nothing of either home.

## MCP + plugin surface

Read-only state tools: `mcp__hngh_present`, `mcp__hngh_status`, `mcp__hngh_queue_report`, `mcp__hngh_dashboard_readout`, `mcp__hngh_research_lines`. Propose new plans via the `hngh_propose` plugin tool (wraps `--propose`).

## 1Password

The 1Password service account is the ONLY auth path for agent `op` usage: `OP_SERVICE_ACCOUNT_TOKEN` (mapped from `ONEPASSWORD_SERVICE_KEY` by automation/lib/credentials.sh). Never trigger an interactive 1Password prompt (no `op signin`, no desktop-app unlock). If the token env is absent, fail soft — breadcrumb + report the gap — and never block on or attempt an interactive prompt.

## Language rule

Anything landing in this repo: English/ASCII only.
