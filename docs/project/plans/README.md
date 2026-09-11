# Plans — the operator-session lifecycle, as routine

NOTE 2026-09-10: the "Autonomy rule (standing)" paragraph below is now
the plans/README.md "Autonomy reference" section; future plans cite it
instead of copying this text. Body kept as-is (append-only edit).

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
- New plans cite the reference sections below (verification contract,
  autonomy reference, ceremony runbook) instead of repeating that
  content inline.

## omp plugin interface

An oh-my-pi plugin propose surface participates by writing
`<date>-<slug>.plan.md` with `status=proposed` into this directory
(plain file write through the same hngh-side path any doc uses — the
plan-mode `xd://propose` flow maps 1:1 onto this contract). Acceptance
and execution then happen automatically per the rules above; the
plugin reads status back from the front-matter or from
hngh-automation's `dashboard/plans.json`.

`omp-bridge --plan-status` (the plugin's readback) accepts a bare slug
or the full date-prefixed stem (`<date>-<slug>`).

## Verification contract

Standard per-step verification, cited in one line instead of repeated:

- Kernel (hngh docs) changes: kernel `make test` green in the same beat,
  landed via certificate ceremony.
- hngh-automation changes: automation `make test` green, plain commit.
- Anything isolated or credential-sensitive: `env -i` hermetic run green.

Steps write e.g. `Verification: see plans/README verification contract;
kernel \`make test\` green.` Only steps with a non-standard check need
full verification text.

## Autonomy reference

The standing autonomy rule all normal-risk plans inherit (cite this
instead of repeating it): hngh docs land via certificate ceremony with
a green `make test`; kernel `src/`, `tests/`, `Makefile`, and `hngh.asd`
are FORBIDDEN to machine sessions — park them with an alert row.
Never touch provider or credential configuration, systemd unit state
beyond an already-installed unit, tracked deletions outside the 48h
prune, or secrets. hngh-automation commits are free once automation
`make test` exits 0. Critical-class work parks automatically with
operator-facing alerts.

## Ceremony runbook

The operator-facing contract for a ceremony-drive invocation: ONE
`scripts/ceremony-drive` call per batched docs landing, against a fresh
`/tmp` store; pre-flight candidates against the public-content gate
first; no `src/` files as ceremony candidates (machine-owned dirty
paths — journals, reports, untracked routed plans — are landed by the
machine's own steps, never ceremony candidates). Plans reference this
runbook by name instead of restating the invocation details.
