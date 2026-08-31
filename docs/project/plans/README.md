# Plans — the operator-session lifecycle, as routine

Plans are how working sessions organize multi-step work: authored as a
file, accepted by machine-checkable evidence, executed step by step,
kept as a record. The lifecycle is a Hngh routine — the barrier is
governance (certificates + green gates), not a person; human approval
is reserved for critical-class work.

## Contract

- File: `docs/project/plans/<date>-<slug>.plan.md`.
- Front-matter, first HTML comment in the file:

  ```
  <!-- plan: status=proposed|accepted|executing|executed|parked
       risk=normal|critical accepted=<UTC ts or -> -->
  ```

- `risk=critical` plans park automatically (never machine-executed):
  anything touching provider/credential configuration, systemd unit
  lifecycle beyond an already-installed unit, non-prune deletions, or
  the security posture.
- Steps live under `## Steps` as `- [ ]` / `- [x]` checkboxes; the
  cycle executes the next unchecked step of the oldest accepted plan
  through a bounded delegated session and ticks it. It runs
  continuously, 24/7 by intent — the script name
  (`hngh-automation/scripts/overnight-cycle.sh`) is a stable CLI name,
  not a doctrine that the cycle only runs overnight (same convention
  as `ceremony-drive`).
- Acceptance: a `proposed` normal-risk plan is auto-accepted when its
  Verification steps are runnable and both repos' gates are green;
  the accepted timestamp is written into the front-matter.

## omp plugin interface

An oh-my-pi plugin propose surface participates by writing
`<date>-<slug>.plan.md` with `status=proposed` into this directory
(plain file write through the same hngh-side path any doc uses — the
plan-mode `xd://propose` flow maps 1:1 onto this contract). Acceptance
and execution then happen automatically per the rules above; the
plugin reads status back from the front-matter or from
hngh-automation's `dashboard/plans.json`.
