# fixed: the orchestrator blocker row blk-20261012-2026-09-16-routed-slow-unit-dropin-59-unsloth-observe.sh (bad-execution: rc=127 launch deaths at env-all-demoted, attempts=1 active) cleared via lib/beat-blockers.sh blocker_clear after the underlying slow-unit fix landed (a7e62ae8) — the 2026-10-12-routed-beat-parked plan's fix-or-remove blocker step is done and the 2026-09-16 plan is re-admitted

Status: crystallized 2026-10-14 from research line `fail-20261012-beat-parked-2026-09-16-routed-slow-unit-dropin-59-unsloth-observe.sh`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261012-beat-parked-2026-09-16-routed-slow-unit-dropin-59-unsloth-observe.sh.md.

# research line — final structured summary (contracting)

_line: fixed: blk-20261012-2026-09-16-routed-slow-unit-dropin-59-unsloth-observe.sh cleared via lib/beat-blockers.sh blocker_clear after slow-unit fix a7e62ae8; 2026-09-16 plan re-admitted | state: contracting | scope: lasting record of findings, recommendations, open threads_

## Grounding note (read first)

This summary is produced without filesystem access in this transition, as were the prior expansions on this line. Every claim below is therefore grounded **only in identifiers that appear verbatim in the line state and prior material**: the blocker row id `blk-20261012-2026-09-16-routed-slow-unit-dropin-59-unsloth-observe.sh`, `lib/beat-blockers.sh` (function `blocker_clear`), commit `a7e62ae8`, the drop-in `dropin-59-unsloth-observe.sh`, the failure tags `bad-execution`, `rc=127`, `env-all-demoted`, `attempts=1 active`, the plans `2026-10-12-routed-beat-parked` and the `2026-09-16` plan, and `research-lines.tsv`. No claim is made about file contents of the hngh kernel checkout (`[redacted path] — its existence as a path on disk is part of the standing instruction, but its contents are **unverified from here**. Where a recommendation depends on a repo fact, a verification command is given instead of an assertion.

## Findings

**F1 — The incident chain is fully resolved and the causal story is coherent.**
A slow unit (`dropin-59-unsloth-observe.sh`) generated blocker row `blk-20261012-2026-09-16-routed-slow-unit-dropin-59-unsloth-observe.sh` classified `bad-execution: rc=127 launch deaths at env-all-demoted, attempts=1 active`. The underlying defect was fixed in commit `a7e62ae8`; the row was then cleared via `lib/beat-blockers.sh blocker_clear`; the fix-or-remove blocker step of plan `2026-10-12-routed-beat-parked` is complete; the `2026-09-16` plan is re-admitted. No dangling dependency remains on this line. *(Source: line state and prior material, verbatim.)*

**F2 — The failure signature (rc=127 under env-demotion) indicates a launch-resolution failure, not a logic failure.**
rc=127 is the conventional shell exit status for "command not found" (POSIX-adjacent convention; external to the repo, stated here as convention, not as repo fact). Combined with the `env-all-demoted` tag, the parsimonious reading is that the demoted environment stripped what the drop-in needed to *start* (interpreter resolution or PATH), so the unit died before its own code ran. This reading is an inference from the identifiers, not a verified repo observation.

**F3 — First-encounter blocking (`attempts=1 active`) means this class of failure parks plans immediately.**
The plan was parked on the first attempt. That makes the failure class high-leverage: any recurrence instantly stalls routed-beat throughput, so prevention and correct classification matter more than retry logic.

**F4 — The clear path worked, but its auditability is unknown.**
`blocker_clear` was invoked and succeeded. Whether the clear event records *why* (clearing commit `a7e62ae8`, clearing plan `2026-10-12-routed-beat-parked`) is unverified — `lib/beat-blockers.sh` contents were never readable in this line's transitions.

## Recommendations (carried and finalized from the expansion)

**R1 — Classify rc=127 as its own failure class.** Add a `launch-resolution` reason (or rc-aware subclassification) where blocker rows are written, so a missing interpreter is never lumped under generic `bad-execution` and misrouted to retry remediation. Verify current behavior: `grep -n 'bad-execution\|127' lib/beat-blockers.sh`.

**R2 — Guard the demotion path with a pre-launch probe.** Before exec'ing a drop-in under a demoted env, resolve the shebang interpreter (e.g. `command -v` on its target) and fail fast with the R1 classification rather than a bare 127. Locate the demotion path via `grep -rn 'env-all-demoted' .` in the automation repo.

**R3 — Make clears self-auditing.** `blocker_clear` (or its call sites) should record the clearing commit and clearing plan for every clear. Verify: `grep -n 'blocker_clear' lib/beat-blockers.sh` and inspect its arguments/logging. A row that disappears without a recorded cause reads as data loss in any later audit.

**R4 — Gate re-admission on a regression pass.** Re-run the routed-beat path that parks plans once under the same env-demotion conditions and confirm the `2026-09-16` plan advances past the point that produced rc=127 — before treating re-admission as proven rather than nominal.

**R5 (new, closing recommendation) — Encode this incident as the reference case for the failure taxonomy.** The row id, commit, and plan chain in this summary are a complete worked example of launch-resolution-under-demotion; if a failure-class taxonomy doc exists or is created, this incident should be its seed entry.

## Open threads

- **T1 — Verification debt.** R1–R4 each carry a `grep` that no transition on this line could execute. The next host with filesystem access should run all four and annotate `research-lines.tsv` or the relevant plan with results.
- **T2 — Recurrence surface.** Whether other drop-ins share the `unsloth-observe` pattern and would hit the same demotion failure is unknown; `ls`/`grep` over the drop-in directory is the check.
- **T3 — Plan lineage.** The `2026-09-16` plan's post-re-admission progress is out of scope for this line; if it stalls again, that is a new line, not a continuation of this one.
- **T4 — External-convention caveat.** The rc=127 interpretation (F2) rests on general shell convention plus the `env-all-demoted` tag. If R2's probe is implemented and the unit still dies at 127, the inference is wrong and the line should be reopened.

## References

Identifiers cited verbatim from line state and prior material (existence in the repository asserted only for these, at the confidence of the line record; contents unverified):

- `research-lines.tsv` — line state file
- `lib/beat-blockers.sh` — function `blocker_clear`
- `dropin-59-unsloth-observe.sh` — the failing slow unit
- Commit `a7e62ae8` — the underlying slow-unit fix
- Blocker row `blk-20261012-2026-09-16-routed-slow-unit-dropin-59-unsloth-observe.sh` — the cleared row
- Plans `2026-10-12-routed-beat-parked` and `2026-09-16` — clearing plan and re-admitted plan
- `[redacted path] — hngh kernel checkout, named in the standing instruction; contents not verifiable from this line's transitions

External and unverifiable-from-here: the POSIX/shell rc=127 "command not found" convention (F2) — stated as general convention, not asserted from any repository source.
