---
category: configuration management
persona: The Scribe
status: seed
anchored: 2026-10-03
note: automation anchors predate the 2026-10-04 control-room cut (broadsheet/ghost/wire surfaces retired)
---

# Configuration Management — what hngh runs today

hngh's configuration surface is **TSV tables + plan front-matter + pinned third-party manifests**, all repo-tracked and read by convention, with no configuration daemon. The central tunable table is `automation/cadence-params.tsv`: one row per knob (key, value, consumer-with-location, semantics), e.g. `sessions-day-max 200` (automation/cadence-params.tsv:53), `dispatch-day-max 4` with an env override (`HNGH_DISPATCH_DAY_CAP`; :54), `xiaomi-model mimo-v2.6-pro` (:72), `ghost-cap-day 12` (:79). Consumers read rows through one shared convention — `lib/params.sh` in shell jobs and `param()` in `automation/lib/ghost-voices.py:166-178` ("first row whose key column matches; default when absent") — and the doctrine is "read row, never guess" (automation/handoff_briefs/2026-09-03-routed-agent-stall-omp-hngh-interim-sweep-817ee7.md:16). A dead-consumer row (`operator-away-windows`, zero readers repo-wide, pending a consumer that does not exist yet) is kept visible on purpose (automation/cadence-params.tsv:52) — the failure mode of config without lifecycle.

Research state is four more TSV ledgers (research-lines / research-dispositions / research-lessons / research-tree, e.g. automation/research-tree.tsv:13-17), gate-checked for schema drift by `tests/test-research-schema.py` (header drift, thin rows, over-wide rows all raise; automation/CHANGELOG.md:585-588).

The **plan front-matter lifecycle** is the second config plane. A plan file opens `<!-- plan: status=proposed risk=normal accepted=- -->` (written verbatim by `scripts/omp-bridge --propose`, which refuses duplicates and never overwrites; scripts/omp-bridge:207-215). `scripts/accept-plans.py` flips the front-matter to `status=accepted` with a timestamp after both gates run green; `risk=critical` plans park automatically and a preamble without a `principle:` line is blocked `missing-principle` (scripts/accept-plans.py:6-10). Parsers tolerate extension keys deliberately (`priority=`, `cause`, `routed-from`) with no invented defaults (scripts/jobs/plan-feed.py:27-30; scripts/router-tick.py:27-31) — proven by no-invented-defaults assertions (automation/tests/test-plan-feed-graph.py:85-93).

Third-party config adoption is **commit-pinned**: the omarchy stack is frozen at omacom/omarchy @ quattro `3faafba234e530b0986196b98dc2c38951e7dd6f` in `automation/config/omarchy-base.packages:1-13`, and an identity hardening pass refuses whole-path-derived tokens from leaking into public front-matter (scripts/router-tick.py:71-75,124-128). Privilege config is example-only in-repo (`config/*.sudoers.example`): nothing in the repo installs sudoers (config/hngh-automation.sudoers.example:1-10).

## Open questions for web research

1. Schema validation for append-only TSV ledgers consumed by many scripts — what fits between ad-hoc regex and a heavyweight schema stack (frictionless tables, pandera, Cue)?
2. Config lifecycle: how do others detect dead-consumer knobs (the `operator-away-windows` problem) — static consumption scans, contract tests, or TTL'd config?
3. Vendoring third-party config trees: commit-pin + overlay vs fork — precedents from Ansible/Nix community modules.
4. Machine-local vs repo config separation (`config.env`, `machine.env` never overwritten) — established split-config conventions.
5. Lightweight front-matter (HTML-comment plan metadata) vs YAML front-matter — compatibility and tooling tradeoffs.

## Candidate external systems to survey

- Etckeeper
- Augeas
- CUE / OPA (config validation)
- Dhall
- Jsonnet
