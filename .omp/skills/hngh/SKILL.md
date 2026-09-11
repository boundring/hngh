---
name: hngh
description: Governs any omp session working in the hngh repo — ceremony loop (propose, issue-cert, mutation-check), plan-file lifecycle, commit-per-green rule, kernel side-effect boundary, and omp-bridge --orient entry. Use whenever the task touches plans, certificates, commits, or src/ in hngh.
---

# hngh project orientation

You are working in the hngh repo (Common Lisp kernel + hngh-automation). Read `docs/README.md` for the canonical read-order; do not re-walk it.

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

- hngh-automation commits are free once automation `make test` exits 0.
- Kernel `src/`, `tests/`, `Makefile`, and `hngh.asd` are FORBIDDEN to machine sessions — park them with an operator alert instead.
- Autonomy reference: `docs/project/plans/README.md` ("Autonomy reference").

## Kernel side-effect boundary

The kernel never knows omp exists. All omp-facing code lives in `automation/` adapters (plus this repo's `.omp/` surface). Never add omp/automation imports or hooks inside `src/`.

## MCP + plugin surface

Read-only state tools: `mcp__hngh_present`, `mcp__hngh_status`, `mcp__hngh_queue_report`, `mcp__hngh_dashboard_readout`. Propose new plans via the `hngh_propose` plugin tool (wraps `--propose`).

## Language rule

Anything landing in this repo: English/ASCII only.
